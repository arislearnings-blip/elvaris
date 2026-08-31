-- ============================================================
-- ELVARIS ERP
-- Migration 020
-- General Ledger and Account Balance Engine
-- ============================================================
--
-- Financial source of truth:
--
--   journal_entries
--        +
--   journal_entry_lines
--        ↓
--   general_ledger
--        ↓
--   account balances
--        ↓
--   Chart of Accounts roll-up
--        ↓
--   Trial Balance / P&L / Balance Sheet
--
-- IMPORTANT
--
--   No balances are stored in chart_of_accounts.
--
--   Posted journal lines remain the accounting source of truth.
--
--   Header balances are calculated from descendant posting
--   accounts.
--
-- ============================================================


-- ============================================================
-- 1. GENERAL LEDGER VIEW
-- ============================================================
--
-- Only posted journal entries participate in the GL.
--
-- Signed balance is based on the account's normal balance:
--
--   Debit-normal:
--       debit - credit
--
--   Credit-normal:
--       credit - debit
--
-- This gives a natural positive balance for each account type.
-- ============================================================

create or replace view public.general_ledger
as
select
    je.id as journal_entry_id,

    jel.id as journal_line_id,

    je.company_id,

    coalesce(
        jel.branch_id,
        je.branch_id
    ) as branch_id,

    je.journal_number,

    je.entry_date,

    je.source_type,

    je.source_document_type,

    je.source_document_id,

    je.source_document_number,

    je.description as journal_description,

    jel.line_number,

    jel.account_id,

    coa.account_code,

    coa.account_name,

    coa.account_role,

    coa.node_type,

    at.code as account_type_code,

    at.name as account_type_name,

    at.normal_balance,

    at.statement_section,

    jel.description as line_description,

    jel.debit,

    jel.credit,

    case
        when at.normal_balance = 'debit'
            then jel.debit - jel.credit
        else
            jel.credit - jel.debit
    end as signed_amount,

    je.currency_id as journal_currency_id,

    jel.currency_id as line_currency_id,

    je.exchange_rate as journal_exchange_rate,

    jel.exchange_rate as line_exchange_rate,

    je.fiscal_year_id,

    je.accounting_period_id,

    jel.department_id,

    je.posted_at,

    je.posted_by,

    jel.created_at as line_created_at,

    jel.created_by as line_created_by

from public.journal_entries je

join public.journal_entry_lines jel
    on jel.journal_entry_id = je.id

join public.chart_of_accounts coa
    on coa.id = jel.account_id

join public.account_types at
    on at.id = coa.account_type_id

where je.status = 'posted'::public.journal_entry_status;


-- ============================================================
-- 2. POSTING ACCOUNT BALANCES
-- ============================================================
--
-- This view provides balances for actual posting/control
-- accounts.
--
-- It intentionally does NOT return report-group/header rows.
-- ============================================================

create or replace view public.account_balances
as
select

    gl.company_id,

    gl.account_id,

    gl.account_code,

    gl.account_name,

    gl.account_role,

    gl.account_type_code,

    gl.account_type_name,

    gl.normal_balance,

    gl.statement_section,

    sum(gl.debit) as total_debits,

    sum(gl.credit) as total_credits,

    sum(gl.signed_amount) as balance

from public.general_ledger gl

where gl.account_role in (
    'posting',
    'control'
)

group by

    gl.company_id,

    gl.account_id,

    gl.account_code,

    gl.account_name,

    gl.account_role,

    gl.account_type_code,

    gl.account_type_name,

    gl.normal_balance,

    gl.statement_section;


-- ============================================================
-- 3. ACCOUNT BALANCE BY DATE
-- ============================================================
--
-- Used by financial reports and the future CoA screen.
-- ============================================================

create or replace function public.get_account_balance(
    p_account_id uuid,
    p_as_of_date date default null
)
returns numeric
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_balance numeric;
begin

    if p_as_of_date is null then

        select
            coalesce(sum(
                case
                    when at.normal_balance = 'debit'
                        then jel.debit - jel.credit
                    else
                        jel.credit - jel.debit
                end
            ), 0)

        into v_balance

        from public.journal_entry_lines jel

        join public.journal_entries je
            on je.id = jel.journal_entry_id

        join public.chart_of_accounts coa
            on coa.id = jel.account_id

        join public.account_types at
            on at.id = coa.account_type_id

        where jel.account_id = p_account_id
          and je.status =
              'posted'::public.journal_entry_status;

    else

        select
            coalesce(sum(
                case
                    when at.normal_balance = 'debit'
                        then jel.debit - jel.credit
                    else
                        jel.credit - jel.debit
                end
            ), 0)

        into v_balance

        from public.journal_entry_lines jel

        join public.journal_entries je
            on je.id = jel.journal_entry_id

        join public.chart_of_accounts coa
            on coa.id = jel.account_id

        join public.account_types at
            on at.id = coa.account_type_id

        where jel.account_id = p_account_id

          and je.status =
              'posted'::public.journal_entry_status

          and je.entry_date <= p_as_of_date;

    end if;


    return coalesce(v_balance, 0);

end;
$function$;


-- ============================================================
-- 4. COA TREE WITH BALANCES
-- ============================================================
--
-- Header balances are calculated recursively:
--
--   own posting balance
--       +
--   descendant balances
--
-- No balance is physically stored on the header.
-- ============================================================

create or replace view public.chart_of_accounts_balances
as

with recursive account_tree as (

    -- --------------------------------------------------------
    -- Root nodes
    -- --------------------------------------------------------

    select

        coa.id,

        coa.company_id,

        coa.parent_account_id,

        coa.account_code,

        coa.account_name,

        coa.account_role,

        coa.node_type,

        coa.account_depth,

        coa.account_path,

        coa.is_header,

        coa.is_posting,

        coa.is_control_account,

        coa.system_account_code,

        coa.is_system_account,

        coa.is_locked,

        coa.display_order,

        array[coa.id] as ancestry

    from public.chart_of_accounts coa

    where coa.parent_account_id is null


    union all


    -- --------------------------------------------------------
    -- Children
    -- --------------------------------------------------------

    select

        child.id,

        child.company_id,

        child.parent_account_id,

        child.account_code,

        child.account_name,

        child.account_role,

        child.node_type,

        child.account_depth,

        child.account_path,

        child.is_header,

        child.is_posting,

        child.is_control_account,

        child.system_account_code,

        child.is_system_account,

        child.is_locked,

        child.display_order,

        parent.ancestry || child.id

    from public.chart_of_accounts child

    join account_tree parent
        on parent.id = child.parent_account_id

    where not child.id = any(parent.ancestry)

),

posting_balances as (

    select

        coa.id as account_id,

        coa.company_id,

        coalesce(
            sum(
                case
                    when at.normal_balance = 'debit'
                        then jel.debit - jel.credit
                    else
                        jel.credit - jel.debit
                end
            ),
            0
        ) as balance,

        coalesce(
            sum(jel.debit),
            0
        ) as total_debits,

        coalesce(
            sum(jel.credit),
            0
        ) as total_credits

    from public.chart_of_accounts coa

    join public.account_types at
        on at.id = coa.account_type_id

    left join public.journal_entry_lines jel
        on jel.account_id = coa.id

    left join public.journal_entries je
        on je.id = jel.journal_entry_id
       and je.status =
           'posted'::public.journal_entry_status

    where coa.is_posting = true

    group by

        coa.id,

        coa.company_id

),

descendant_totals as (

    select

        tree.id as node_id,

        tree.company_id,

        coalesce(
            sum(
                pb.balance
            ),
            0
        ) as balance,

        coalesce(
            sum(
                pb.total_debits
            ),
            0
        ) as total_debits,

        coalesce(
            sum(
                pb.total_credits
            ),
            0
        ) as total_credits

    from account_tree tree

    left join account_tree descendant
        on descendant.company_id = tree.company_id

    left join posting_balances pb
        on pb.account_id = descendant.id

    group by

        tree.id,

        tree.company_id

)

select

    tree.id,

    tree.company_id,

    tree.parent_account_id,

    tree.account_code,

    tree.account_name,

    tree.account_role,

    tree.node_type,

    tree.account_depth,

    tree.account_path,

    tree.is_header,

    tree.is_posting,

    tree.is_control_account,

    tree.system_account_code,

    tree.is_system_account,

    tree.is_locked,

    tree.display_order,

    coalesce(
        totals.balance,
        0
    ) as balance,

    coalesce(
        totals.total_debits,
        0
    ) as total_debits,

    coalesce(
        totals.total_credits,
        0
    ) as total_credits

from account_tree tree

left join descendant_totals totals
    on totals.node_id = tree.id

order by
    tree.company_id,
    tree.account_path;


-- ============================================================
-- 5. TRIAL BALANCE VIEW
-- ============================================================
--
-- One row per posting/control account.
--
-- Both debit and credit columns are preserved for formal
-- accounting reports.
-- ============================================================

create or replace view public.trial_balance
as

select

    coa.company_id,

    coa.id as account_id,

    coa.account_code,

    coa.account_name,

    coa.account_role,

    at.code as account_type_code,

    at.name as account_type_name,

    at.normal_balance,

    at.statement_section,

    coalesce(
        sum(jel.debit),
        0
    ) as total_debits,

    coalesce(
        sum(jel.credit),
        0
    ) as total_credits

from public.chart_of_accounts coa

join public.account_types at
    on at.id = coa.account_type_id

left join public.journal_entry_lines jel
    on jel.account_id = coa.id

left join public.journal_entries je
    on je.id = jel.journal_entry_id
   and je.status =
       'posted'::public.journal_entry_status

where coa.is_posting = true

group by

    coa.company_id,

    coa.id,

    coa.account_code,

    coa.account_name,

    coa.account_role,

    at.code,

    at.name,

    at.normal_balance,

    at.statement_section;


-- ============================================================
-- 6. GENERAL LEDGER INDEXES
-- ============================================================

create index if not exists
idx_journal_entries_company_date_status
on public.journal_entries (
    company_id,
    entry_date,
    status
);


create index if not exists
idx_journal_lines_account_entry
on public.journal_entry_lines (
    account_id,
    journal_entry_id
);


create index if not exists
idx_journal_lines_account
on public.journal_entry_lines (
    account_id
);


-- ============================================================
-- 7. COMMENTS
-- ============================================================

comment on view public.general_ledger
is
    'Posted double-entry accounting ledger derived from journal entries and journal lines.';


comment on view public.account_balances
is
    'Current balances for posting and control accounts derived from posted journal lines.';


comment on view public.chart_of_accounts_balances
is
    'Hierarchical Chart of Accounts with calculated descendant balances; header balances are not stored.';


comment on view public.trial_balance
is
    'Trial Balance derived from posted journal entries for posting and control accounts.';


comment on function public.get_account_balance(
    uuid,
    date
)
is
    'Returns the posted signed balance for a single account, optionally as of a specified date.';


-- ============================================================
-- 8. VALIDATION
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_class
        where relname = 'general_ledger'
    ) then

        raise exception
            'general_ledger view was not created.';

    end if;


    if not exists (
        select 1
        from pg_class
        where relname = 'account_balances'
    ) then

        raise exception
            'account_balances view was not created.';

    end if;


    if not exists (
        select 1
        from pg_class
        where relname = 'chart_of_accounts_balances'
    ) then

        raise exception
            'chart_of_accounts_balances view was not created.';

    end if;


    if not exists (
        select 1
        from pg_class
        where relname = 'trial_balance'
    ) then

        raise exception
            'trial_balance view was not created.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 020
-- ============================================================
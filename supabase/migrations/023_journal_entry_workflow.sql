-- ============================================================
-- ELVARIS ERP
-- Migration 023
-- Journal Entry Workflow
-- ============================================================

-- ============================================================
-- 1. CREATE DRAFT JOURNAL ENTRY
-- ============================================================

create or replace function public.create_journal_entry(
    p_company_id uuid,
    p_entry_date date,
    p_description text default null,
    p_branch_id uuid default null,
    p_source_type public.journal_source_type default 'general_journal',
    p_currency_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_journal_id uuid;
    v_journal_number varchar(40);
    v_fiscal_year_id uuid;
    v_period_id uuid;

begin

    if not exists (
        select 1
        from public.companies c
        where c.id = p_company_id
          and c.is_active = true
    ) then

        raise exception
            'Active company does not exist.';

    end if;


    if p_entry_date is null then

        raise exception
            'Entry date is required.';

    end if;


    if p_branch_id is not null then

        if not exists (
            select 1
            from public.branches b
            where b.id = p_branch_id
              and b.company_id = p_company_id
              and b.is_active = true
        ) then

            raise exception
                'Branch does not belong to the company or is inactive.';

        end if;

    end if;


    select
        r.fiscal_year_id,
        r.accounting_period_id
    into
        v_fiscal_year_id,
        v_period_id
    from public.resolve_accounting_period(
        p_company_id,
        p_entry_date
    ) r
    limit 1;


    if v_fiscal_year_id is null
       or v_period_id is null
    then

        raise exception
            'No open fiscal year/accounting period exists for date %.',
            p_entry_date;

    end if;


    v_journal_number :=
        public.next_journal_number(
            p_company_id
        );


    insert into public.journal_entries (
        company_id,
        branch_id,
        journal_number,
        entry_date,
        source_type,
        description,
        status,
        currency_id,
        exchange_rate,
        fiscal_year_id,
        accounting_period_id,
        is_reversal,
        created_at,
        created_by,
        updated_at,
        updated_by
    )
    values (
        p_company_id,
        p_branch_id,
        v_journal_number,
        p_entry_date,
        p_source_type,
        p_description,
        'draft'::public.journal_entry_status,
        p_currency_id,
        1,
        v_fiscal_year_id,
        v_period_id,
        false,
        now(),
        auth.uid(),
        now(),
        auth.uid()
    )
    returning id
    into v_journal_id;


    return v_journal_id;

end;
$function$;


-- ============================================================
-- 2. ADD JOURNAL LINE
-- ============================================================

create or replace function public.add_journal_entry_line(
    p_journal_entry_id uuid,
    p_account_id uuid,
    p_debit numeric default 0,
    p_credit numeric default 0,
    p_description text default null,
    p_branch_id uuid default null,
    p_department_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_line_id uuid;
    v_company_id uuid;
    v_next_line integer;

begin

    if not exists (
        select 1
        from public.journal_entries je
        where je.id = p_journal_entry_id
          and je.status = 'draft'::public.journal_entry_status
    ) then

        raise exception
            'Journal entry does not exist or is not a draft.';

    end if;


    select company_id
    into v_company_id
    from public.journal_entries
    where id = p_journal_entry_id;


    perform public.validate_journal_account(
        p_account_id
    );


    if not exists (
        select 1
        from public.chart_of_accounts coa
        where coa.id = p_account_id
          and coa.company_id = v_company_id
    ) then

        raise exception
            'Account does not belong to the journal company.';

    end if;


    if p_debit < 0
       or p_credit < 0
    then

        raise exception
            'Debit and credit cannot be negative.';

    end if;


    if p_debit > 0
       and p_credit > 0
    then

        raise exception
            'A journal line cannot contain both debit and credit.';

    end if;


    if p_debit = 0
       and p_credit = 0
    then

        raise exception
            'A journal line must contain a debit or credit amount.';

    end if;


    if p_branch_id is not null then

        if not exists (
            select 1
            from public.branches b
            where b.id = p_branch_id
              and b.company_id = v_company_id
              and b.is_active = true
        ) then

            raise exception
                'Line branch does not belong to the journal company or is inactive.';

        end if;

    end if;


    if p_department_id is not null then

        if not exists (
            select 1
            from public.departments d
            where d.id = p_department_id
              and d.company_id = v_company_id
              and d.is_active = true
        ) then

            raise exception
                'Department does not belong to the journal company or is inactive.';

        end if;

    end if;


    select coalesce(
        max(line_number),
        0
    ) + 1
    into v_next_line
    from public.journal_entry_lines
    where journal_entry_id = p_journal_entry_id;


    insert into public.journal_entry_lines (
        journal_entry_id,
        line_number,
        account_id,
        branch_id,
        description,
        debit,
        credit,
        currency_id,
        exchange_rate,
        foreign_debit,
        foreign_credit,
        department_id,
        created_at,
        created_by
    )
    values (
        p_journal_entry_id,
        v_next_line,
        p_account_id,
        p_branch_id,
        p_description,
        p_debit,
        p_credit,
        null,
        1,
        0,
        0,
        p_department_id,
        now(),
        auth.uid()
    )
    returning id
    into v_line_id;


    return v_line_id;

end;
$function$;


-- ============================================================
-- 3. DELETE DRAFT JOURNAL LINE
-- ============================================================

create or replace function public.delete_draft_journal_line(
    p_line_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_entry_id uuid;
begin

    select journal_entry_id
    into v_entry_id
    from public.journal_entry_lines
    where id = p_line_id;


    if v_entry_id is null then

        raise exception
            'Journal line does not exist.';

    end if;


    if not exists (
        select 1
        from public.journal_entries
        where id = v_entry_id
          and status = 'draft'::public.journal_entry_status
    ) then

        raise exception
            'Only lines belonging to draft journal entries may be deleted.';

    end if;


    delete from public.journal_entry_lines
    where id = p_line_id;


    return true;

end;
$function$;


-- ============================================================
-- 4. DELETE DRAFT JOURNAL
-- ============================================================

create or replace function public.delete_draft_journal_entry(
    p_journal_entry_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_status public.journal_entry_status;
begin

    select status
    into v_status
    from public.journal_entries
    where id = p_journal_entry_id
    for update;


    if v_status is null then

        raise exception
            'Journal entry does not exist.';

    end if;


    if v_status <> 'draft'::public.journal_entry_status then

        raise exception
            'Only draft journal entries can be deleted.';

    end if;


    delete from public.journal_entries
    where id = p_journal_entry_id;


    return true;

end;
$function$;


-- ============================================================
-- 5. JOURNAL SUMMARY
-- ============================================================

create or replace view public.journal_entry_summary
as

select
    je.id,
    je.company_id,
    je.branch_id,
    je.journal_number,
    je.entry_date,
    je.source_type,
    je.description,
    je.status,
    je.fiscal_year_id,
    je.accounting_period_id,

    count(jel.id) as line_count,

    coalesce(
        sum(jel.debit),
        0
    ) as total_debit,

    coalesce(
        sum(jel.credit),
        0
    ) as total_credit,

    coalesce(
        sum(jel.debit),
        0
    )
    -
    coalesce(
        sum(jel.credit),
        0
    ) as difference

from public.journal_entries je

left join public.journal_entry_lines jel
    on jel.journal_entry_id = je.id

group by
    je.id,
    je.company_id,
    je.branch_id,
    je.journal_number,
    je.entry_date,
    je.source_type,
    je.description,
    je.status,
    je.fiscal_year_id,
    je.accounting_period_id;


-- ============================================================
-- 6. COMMENTS
-- ============================================================

comment on function public.create_journal_entry(
    uuid,
    date,
    text,
    uuid,
    public.journal_source_type,
    uuid
)
is
    'Creates a draft journal entry and automatically resolves its open fiscal year and accounting period.';


comment on function public.add_journal_entry_line(
    uuid,
    uuid,
    numeric,
    numeric,
    text,
    uuid,
    uuid
)
is
    'Adds a debit or credit line to a draft journal entry after validating the account and company.';


comment on function public.delete_draft_journal_line(
    uuid
)
is
    'Deletes a line only while its journal entry remains in draft status.';


comment on function public.delete_draft_journal_entry(
    uuid
)
is
    'Deletes an entire journal entry only while it remains in draft status.';


-- ============================================================
-- 7. VALIDATION
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'create_journal_entry'
    ) then

        raise exception
            'create_journal_entry was not created.';

    end if;


    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'add_journal_entry_line'
    ) then

        raise exception
            'add_journal_entry_line was not created.';

    end if;


    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'delete_draft_journal_entry'
    ) then

        raise exception
            'delete_draft_journal_entry was not created.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 023
-- ============================================================
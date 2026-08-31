-- ============================================================
-- ELVARIS ERP
-- Migration 018
-- Accounting Journal / General Ledger Foundation
-- ============================================================
--
-- Purpose:
--   Establish the immutable double-entry accounting engine
--   used by the Chart of Accounts, Trial Balance, P&L and
--   Balance Sheet.
--
-- Flow:
--
--   Source Document
--        ↓
--   Journal Entry
--        ↓
--   Journal Lines
--        ↓
--   General Ledger
--        ↓
--   Account Balance
--        ↓
--   Financial Reports
--
-- Rules:
--   * Total debits must equal total credits.
--   * Only posting/control accounts may receive lines.
--   * Header accounts cannot receive lines.
--   * Posted entries cannot be edited or deleted.
--   * Corrections are made using reversals.
--   * Company and branch are captured on the entry.
--   * Fiscal period must be open when posting.
-- ============================================================


-- ============================================================
-- 1. JOURNAL ENTRY STATUS
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_type
        where typname = 'journal_entry_status'
          and typnamespace = 'public'::regnamespace
    ) then

        create type public.journal_entry_status as enum (
            'draft',
            'posted',
            'reversed',
            'void'
        );

    end if;

end
$$;


-- ============================================================
-- 2. JOURNAL SOURCE
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_type
        where typname = 'journal_source_type'
          and typnamespace = 'public'::regnamespace
    ) then

        create type public.journal_source_type as enum (
            'general_journal',
            'sales',
            'purchase',
            'receipt',
            'payment',
            'inventory',
            'manufacturing',
            'payroll',
            'fixed_asset',
            'bank',
            'opening_balance',
            'adjustment',
            'system'
        );

    end if;

end
$$;


-- ============================================================
-- 3. JOURNAL ENTRIES
-- ============================================================

create table if not exists public.journal_entries (

    id uuid primary key
        default gen_random_uuid(),

    company_id uuid not null
        references public.companies(id)
        on delete restrict,

    branch_id uuid
        references public.branches(id)
        on delete restrict,

    journal_number varchar(40) not null,

    entry_date date not null,

    source_type public.journal_source_type not null
        default 'general_journal',

    source_document_type varchar(80),

    source_document_id uuid,

    source_document_number varchar(80),

    description text,

    status public.journal_entry_status not null
        default 'draft',

    currency_id uuid,

    exchange_rate numeric(20,10) not null
        default 1,

    fiscal_year_id uuid,

    accounting_period_id uuid,

    is_reversal boolean not null
        default false,

    reverses_entry_id uuid
        references public.journal_entries(id)
        on delete restrict,

    reversed_by_entry_id uuid
        references public.journal_entries(id)
        on delete restrict,

    posted_at timestamptz,

    posted_by uuid,

    created_at timestamptz not null
        default now(),

    created_by uuid,

    updated_at timestamptz not null
        default now(),

    updated_by uuid

);


-- ============================================================
-- 4. JOURNAL ENTRY UNIQUE NUMBER
-- ============================================================

create unique index if not exists
ux_journal_entries_company_number
on public.journal_entries (
    company_id,
    journal_number
);


-- ============================================================
-- 5. JOURNAL ENTRY INDEXES
-- ============================================================

create index if not exists
idx_journal_entries_company_date
on public.journal_entries (
    company_id,
    entry_date
);


create index if not exists
idx_journal_entries_company_status
on public.journal_entries (
    company_id,
    status
);


create index if not exists
idx_journal_entries_company_source
on public.journal_entries (
    company_id,
    source_type
);


create index if not exists
idx_journal_entries_period
on public.journal_entries (
    accounting_period_id
);


create index if not exists
idx_journal_entries_reversal
on public.journal_entries (
    reverses_entry_id
);


-- ============================================================
-- 6. JOURNAL ENTRY LINES
-- ============================================================

create table if not exists public.journal_entry_lines (

    id uuid primary key
        default gen_random_uuid(),

    journal_entry_id uuid not null
        references public.journal_entries(id)
        on delete restrict,

    line_number integer not null,

    account_id uuid not null
        references public.chart_of_accounts(id)
        on delete restrict,

    branch_id uuid
        references public.branches(id)
        on delete restrict,

    description text,

    debit numeric(20,6) not null
        default 0,

    credit numeric(20,6) not null
        default 0,

    currency_id uuid,

    exchange_rate numeric(20,10) not null
        default 1,

    foreign_debit numeric(20,6)
        default 0,

    foreign_credit numeric(20,6)
        default 0,

    customer_id uuid,

    vendor_id uuid,

    item_id uuid,

    department_id uuid,

    created_at timestamptz not null
        default now(),

    created_by uuid,

    constraint journal_entry_lines_number_check
        check (line_number > 0),

    constraint journal_entry_lines_amount_check
        check (
            debit >= 0
            and credit >= 0
        ),

    constraint journal_entry_lines_one_side_check
        check (
            not (
                debit > 0
                and credit > 0
            )
        ),

    constraint journal_entry_lines_nonzero_check
        check (
            debit > 0
            or credit > 0
        ),

    constraint journal_entry_lines_exchange_rate_check
        check (
            exchange_rate > 0
        ),

    constraint journal_entry_lines_foreign_amount_check
        check (
            foreign_debit >= 0
            and foreign_credit >= 0
        )

);


-- ============================================================
-- 7. JOURNAL LINE UNIQUE ORDER
-- ============================================================

create unique index if not exists
ux_journal_entry_lines_entry_number
on public.journal_entry_lines (
    journal_entry_id,
    line_number
);


-- ============================================================
-- 8. JOURNAL LINE INDEXES
-- ============================================================

create index if not exists
idx_journal_lines_account
on public.journal_entry_lines (
    account_id
);


create index if not exists
idx_journal_lines_entry
on public.journal_entry_lines (
    journal_entry_id
);


create index if not exists
idx_journal_lines_account_entry
on public.journal_entry_lines (
    account_id,
    journal_entry_id
);


create index if not exists
idx_journal_lines_customer
on public.journal_entry_lines (
    customer_id
);


create index if not exists
idx_journal_lines_vendor
on public.journal_entry_lines (
    vendor_id
);


create index if not exists
idx_journal_lines_item
on public.journal_entry_lines (
    item_id
);


-- ============================================================
-- 9. JOURNAL ENTRY TOTAL VIEW
-- ============================================================

create or replace view public.journal_entry_totals
as
select
    je.id as journal_entry_id,

    je.company_id,

    je.journal_number,

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
    je.journal_number;


-- ============================================================
-- 10. VALIDATE ACCOUNT FOR JOURNAL POSTING
-- ============================================================

create or replace function public.validate_journal_account(
    p_account_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_account record;

begin

    select
        is_active,
        is_header,
        is_posting,
        allow_manual_posting
    into v_account
    from public.chart_of_accounts
    where id = p_account_id;


    if not found then

        raise exception
            'Journal account does not exist.';

    end if;


    if v_account.is_active = false then

        raise exception
            'Journal account is inactive.';

    end if;


    if v_account.is_header = true then

        raise exception
            'Header account cannot receive journal postings.';

    end if;


    if v_account.is_posting = false then

        raise exception
            'Selected account is not a posting account.';

    end if;


    if v_account.allow_manual_posting = false then

        raise exception
            'Manual posting is not allowed to this account.';

    end if;


    return true;

end;
$function$;


-- ============================================================
-- 11. VALIDATE JOURNAL BALANCE
-- ============================================================

create or replace function public.validate_journal_entry_balance(
    p_journal_entry_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_debit numeric(20,6);
    v_credit numeric(20,6);
begin

    select
        coalesce(sum(debit), 0),
        coalesce(sum(credit), 0)
    into
        v_debit,
        v_credit
    from public.journal_entry_lines
    where journal_entry_id = p_journal_entry_id;


    if v_debit = 0
       and v_credit = 0 then

        raise exception
            'Journal entry must contain at least one non-zero line.';

    end if;


    if abs(v_debit - v_credit) > 0.000001 then

        raise exception
            'Journal entry is not balanced. Debits: %, Credits: %, Difference: %.',
            v_debit,
            v_credit,
            v_debit - v_credit;

    end if;


    return true;

end;
$function$;


-- ============================================================
-- 12. PREVENT POSTED ENTRY MODIFICATION
-- ============================================================

create or replace function public.prevent_posted_journal_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$

begin

    if old.status in (
        'posted',
        'reversed',
        'void'
    ) then

        raise exception
            'Posted, reversed, or void journal entries are immutable. Use a reversal or adjustment.';

    end if;


    return new;

end;
$function$;


drop trigger if exists
trg_prevent_posted_journal_update
on public.journal_entries;


create trigger
trg_prevent_posted_journal_update
before update
on public.journal_entries
for each row
execute function public.prevent_posted_journal_change();


-- ============================================================
-- 13. PREVENT POSTED JOURNAL DELETE
-- ============================================================

create or replace function public.prevent_posted_journal_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$

begin

    if old.status in (
        'posted',
        'reversed',
        'void'
    ) then

        raise exception
            'Posted, reversed, or void journal entries cannot be deleted.';

    end if;


    return old;

end;
$function$;


drop trigger if exists
trg_prevent_posted_journal_delete
on public.journal_entries;


create trigger
trg_prevent_posted_journal_delete
before delete
on public.journal_entries
for each row
execute function public.prevent_posted_journal_delete();


-- ============================================================
-- 14. PREVENT POSTED LINE UPDATE
-- ============================================================

create or replace function public.prevent_posted_journal_line_change()
returns trigger
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
    where id = coalesce(
        new.journal_entry_id,
        old.journal_entry_id
    );


    if v_status in (
        'posted',
        'reversed',
        'void'
    ) then

        raise exception
            'Lines belonging to posted, reversed, or void journal entries are immutable.';

    end if;


    return coalesce(new, old);

end;
$function$;


drop trigger if exists
trg_prevent_posted_line_update
on public.journal_entry_lines;


create trigger
trg_prevent_posted_line_update
before update
on public.journal_entry_lines
for each row
execute function public.prevent_posted_journal_line_change();


-- ============================================================
-- 15. PREVENT POSTED LINE DELETE
-- ============================================================

create or replace function public.prevent_posted_journal_line_delete()
returns trigger
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
    where id = old.journal_entry_id;


    if v_status in (
        'posted',
        'reversed',
        'void'
    ) then

        raise exception
            'Lines belonging to posted, reversed, or void journal entries cannot be deleted.';

    end if;


    return old;

end;
$function$;


drop trigger if exists
trg_prevent_posted_line_delete
on public.journal_entry_lines;


create trigger
trg_prevent_posted_line_delete
before delete
on public.journal_entry_lines
for each row
execute function public.prevent_posted_journal_line_delete();


-- ============================================================
-- 16. JOURNAL LINE ACCOUNT VALIDATION
-- ============================================================

create or replace function public.validate_journal_line_account()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$

begin

    perform public.validate_journal_account(
        new.account_id
    );


    -- --------------------------------------------------------
    -- Ensure account belongs to the same company as entry.
    -- --------------------------------------------------------

    if not exists (
        select 1
        from public.chart_of_accounts coa
        join public.journal_entries je
            on je.company_id = coa.company_id
        where coa.id = new.account_id
          and je.id = new.journal_entry_id
    ) then

        raise exception
            'Journal line account does not belong to the journal entry company.';

    end if;


    return new;

end;
$function$;


drop trigger if exists
trg_validate_journal_line_account
on public.journal_entry_lines;


create trigger
trg_validate_journal_line_account
before insert or update
on public.journal_entry_lines
for each row
execute function public.validate_journal_line_account();


-- ============================================================
-- 17. JOURNAL ENTRY LINE COMPANY CONSISTENCY
-- ============================================================

create or replace function public.validate_journal_entry_line_company()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_entry_company_id uuid;
    v_account_company_id uuid;
begin

    select company_id
    into v_entry_company_id
    from public.journal_entries
    where id = new.journal_entry_id;


    select company_id
    into v_account_company_id
    from public.chart_of_accounts
    where id = new.account_id;


    if v_entry_company_id is null then

        raise exception
            'Journal entry does not exist.';

    end if;


    if v_account_company_id is null then

        raise exception
            'Journal account does not exist.';

    end if;


    if v_entry_company_id <> v_account_company_id then

        raise exception
            'Journal account and journal entry belong to different companies.';

    end if;


    return new;

end;
$function$;


drop trigger if exists
trg_validate_journal_company
on public.journal_entry_lines;


create trigger
trg_validate_journal_company
before insert or update
on public.journal_entry_lines
for each row
execute function public.validate_journal_entry_line_company();


-- ============================================================
-- 18. JOURNAL ENTRY STATUS VALIDATION
-- ============================================================

create or replace function public.validate_journal_entry_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$

begin

    if new.status = 'posted' then

        if new.posted_at is null then
            new.posted_at := now();
        end if;


        if new.posted_by is null then
            new.posted_by := auth.uid();
        end if;


        perform public.validate_journal_entry_balance(
            new.id
        );

    end if;


    return new;

end;
$function$;


drop trigger if exists
trg_validate_journal_entry_status
on public.journal_entries;


create trigger
trg_validate_journal_entry_status
after update
on public.journal_entries
for each row
when (
    new.status = 'posted'
    and old.status <> 'posted'
)
execute function public.validate_journal_entry_status();


-- ============================================================
-- 19. JOURNAL ENTRY DESCRIPTION
-- ============================================================

comment on table public.journal_entries
is
    'Elvaris immutable double-entry journal entry header.';


comment on table public.journal_entry_lines
is
    'Elvaris journal entry debit and credit lines.';


comment on column public.journal_entries.status
is
    'Draft, posted, reversed or void. Posted entries are immutable.';


comment on column public.journal_entries.source_type
is
    'Source module that generated the accounting entry.';


comment on column public.journal_entries.reverses_entry_id
is
    'Original journal entry reversed by this entry.';


comment on column public.journal_entries.reversed_by_entry_id
is
    'Reversal journal entry associated with this entry.';


comment on column public.journal_entry_lines.account_id
is
    'Chart of Accounts account receiving the debit or credit.';


comment on column public.journal_entry_lines.debit
is
    'Debit amount in company currency.';


comment on column public.journal_entry_lines.credit
is
    'Credit amount in company currency.';


-- ============================================================
-- 20. VALIDATION
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'journal_entries'
    ) then

        raise exception
            'journal_entries table was not created.';

    end if;


    if not exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'journal_entry_lines'
    ) then

        raise exception
            'journal_entry_lines table was not created.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 018
-- ============================================================
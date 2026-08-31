-- ============================================================
-- ELVARIS ERP
-- Migration 019
-- Accounting Posting Engine
-- ============================================================
--
-- Purpose:
--   Provide the controlled journal-entry posting workflow.
--
-- Posting sequence:
--
--   Draft
--      ↓
--   Validate company
--      ↓
--   Resolve fiscal year
--      ↓
--   Resolve accounting period
--      ↓
--   Confirm period is OPEN
--      ↓
--   Validate every account
--      ↓
--   Validate company / branch
--      ↓
--   Validate debit = credit
--      ↓
--   POST
--      ↓
--   Immutable accounting record
--
-- Existing enums discovered from the database:
--
--   fiscal_year_status:
--       open
--       closed
--
--   accounting_period_status:
--       open
--       locked
--       closed
--
--   journal_entry_status:
--       draft
--       posted
--       reversed
--       void
--
-- IMPORTANT:
--   This migration does not create Customers, Vendors or Items
--   because those master tables are not yet present.
--
-- ============================================================


-- ============================================================
-- 1. JOURNAL NUMBER GENERATOR
-- ============================================================

create or replace function public.next_journal_number(
    p_company_id uuid
)
returns varchar(40)
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_year text;
    v_max_number bigint;
    v_next_number bigint;

begin

    v_year :=
        to_char(current_date, 'YYYY');


    select
        coalesce(
            max(
                nullif(
                    regexp_replace(
                        je.journal_number,
                        '[^0-9]',
                        '',
                        'g'
                    ),
                    ''
                )::bigint
            ),
            0
        )
    into v_max_number
    from public.journal_entries je
    where je.company_id = p_company_id;


    v_next_number :=
        greatest(
            v_max_number + 1,
            1
        );


    return
        'GJ-'
        || v_year
        || '-'
        || lpad(
            v_next_number::text,
            6,
            '0'
        );

end;
$function$;


-- ============================================================
-- 2. RESOLVE ACCOUNTING PERIOD
-- ============================================================

create or replace function public.resolve_accounting_period(
    p_company_id uuid,
    p_entry_date date
)
returns table (
    fiscal_year_id uuid,
    accounting_period_id uuid
)
language plpgsql
security definer
stable
set search_path = public
as $function$

begin

    return query

    select
        fy.id,
        ap.id

    from public.fiscal_years fy

    join public.accounting_periods ap
      on ap.fiscal_year_id = fy.id

    where fy.company_id = p_company_id

      and p_entry_date between
          fy.start_date
          and fy.end_date

      and p_entry_date between
          ap.start_date
          and ap.end_date

      and fy.status = 'open'::public.fiscal_year_status

      and ap.status = 'open'::public.accounting_period_status

    order by
        ap.period_number

    limit 1;

end;
$function$;


-- ============================================================
-- 3. VALIDATE JOURNAL ENTRY HEADER
-- ============================================================

create or replace function public.validate_journal_entry_header(
    p_journal_entry_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_entry public.journal_entries%rowtype;
    v_resolved_fiscal_year uuid;
    v_resolved_period uuid;

begin

    select *
    into v_entry
    from public.journal_entries
    where id = p_journal_entry_id
    for update;


    if not found then

        raise exception
            'Journal entry does not exist.';

    end if;


    if v_entry.status <> 'draft' then

        raise exception
            'Only draft journal entries can be posted. Current status: %.',
            v_entry.status;

    end if;


    if v_entry.company_id is null then

        raise exception
            'Journal entry company is required.';

    end if;


    if v_entry.entry_date is null then

        raise exception
            'Journal entry date is required.';

    end if;


    if v_entry.branch_id is not null then

        if not exists (
            select 1
            from public.branches b
            where b.id = v_entry.branch_id
              and b.company_id = v_entry.company_id
              and b.is_active = true
        ) then

            raise exception
                'Journal entry branch does not belong to the company or is inactive.';

        end if;

    end if;


    -- --------------------------------------------------------
    -- Resolve fiscal year and period if not supplied.
    -- --------------------------------------------------------

    if v_entry.fiscal_year_id is null
       or v_entry.accounting_period_id is null
    then

        select
            r.fiscal_year_id,
            r.accounting_period_id
        into
            v_resolved_fiscal_year,
            v_resolved_period
        from public.resolve_accounting_period(
            v_entry.company_id,
            v_entry.entry_date
        ) r
        limit 1;


        if v_resolved_fiscal_year is null
           or v_resolved_period is null
        then

            raise exception
                'No open fiscal year and accounting period were found for journal date %.',
                v_entry.entry_date;

        end if;


        update public.journal_entries
        set
            fiscal_year_id = v_resolved_fiscal_year,
            accounting_period_id = v_resolved_period,
            updated_at = now()
        where id = p_journal_entry_id;


    else

        -- ----------------------------------------------------
        -- Verify explicitly supplied fiscal year
        -- ----------------------------------------------------

        if not exists (
            select 1
            from public.fiscal_years fy
            where fy.id = v_entry.fiscal_year_id
              and fy.company_id = v_entry.company_id
              and fy.status = 'open'::public.fiscal_year_status
              and v_entry.entry_date between
                  fy.start_date
                  and fy.end_date
        ) then

            raise exception
                'The selected fiscal year is invalid, closed, or does not contain the journal date.';

        end if;


        -- ----------------------------------------------------
        -- Verify explicitly supplied accounting period
        -- ----------------------------------------------------

        if not exists (
            select 1
            from public.accounting_periods ap
            join public.fiscal_years fy
              on fy.id = ap.fiscal_year_id
            where ap.id = v_entry.accounting_period_id
              and ap.fiscal_year_id = v_entry.fiscal_year_id
              and fy.company_id = v_entry.company_id
              and ap.status = 'open'::public.accounting_period_status
              and v_entry.entry_date between
                  ap.start_date
                  and ap.end_date
        ) then

            raise exception
                'The selected accounting period is invalid, locked, closed, or does not contain the journal date.';

        end if;

    end if;


    -- --------------------------------------------------------
    -- Journal number
    -- --------------------------------------------------------

    if nullif(trim(v_entry.journal_number), '') is null then

        update public.journal_entries
        set
            journal_number =
                public.next_journal_number(
                    v_entry.company_id
                ),
            updated_at = now()
        where id = p_journal_entry_id;

    end if;


    return true;

end;
$function$;


-- ============================================================
-- 4. VALIDATE ALL JOURNAL LINES
-- ============================================================

create or replace function public.validate_journal_entry_lines(
    p_journal_entry_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_entry_company_id uuid;
    v_line_count integer;

    v_line record;

begin

    select company_id
    into v_entry_company_id
    from public.journal_entries
    where id = p_journal_entry_id;


    if v_entry_company_id is null then

        raise exception
            'Journal entry does not exist.';

    end if;


    select count(*)
    into v_line_count
    from public.journal_entry_lines
    where journal_entry_id = p_journal_entry_id;


    if v_line_count < 2 then

        raise exception
            'A journal entry must contain at least two lines.';

    end if;


    for v_line in
        select
            jel.id,
            jel.line_number,
            jel.account_id,
            jel.branch_id,
            jel.debit,
            jel.credit
        from public.journal_entry_lines jel
        where jel.journal_entry_id = p_journal_entry_id
        order by jel.line_number
    loop

        -- ----------------------------------------------------
        -- Validate account itself
        -- ----------------------------------------------------

        perform public.validate_journal_account(
            v_line.account_id
        );


        -- ----------------------------------------------------
        -- Ensure account belongs to entry company
        -- ----------------------------------------------------

        if not exists (
            select 1
            from public.chart_of_accounts coa
            where coa.id = v_line.account_id
              and coa.company_id = v_entry_company_id
        ) then

            raise exception
                'Line % account does not belong to the journal company.',
                v_line.line_number;

        end if;


        -- ----------------------------------------------------
        -- Validate line branch
        -- ----------------------------------------------------

        if v_line.branch_id is not null then

            if not exists (
                select 1
                from public.branches b
                where b.id = v_line.branch_id
                  and b.company_id = v_entry_company_id
                  and b.is_active = true
            ) then

                raise exception
                    'Line % branch does not belong to the journal company or is inactive.',
                    v_line.line_number;

            end if;

        end if;


        -- ----------------------------------------------------
        -- A line cannot contain both debit and credit
        -- ----------------------------------------------------

        if v_line.debit > 0
           and v_line.credit > 0
        then

            raise exception
                'Journal line % cannot contain both debit and credit.',
                v_line.line_number;

        end if;


        -- ----------------------------------------------------
        -- A line must contain an amount
        -- ----------------------------------------------------

        if v_line.debit = 0
           and v_line.credit = 0
        then

            raise exception
                'Journal line % must contain a debit or credit amount.',
                v_line.line_number;

        end if;


    end loop;


    return true;

end;
$function$;


-- ============================================================
-- 5. POST JOURNAL ENTRY
-- ============================================================

create or replace function public.post_journal_entry(
    p_journal_entry_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_entry public.journal_entries%rowtype;
    v_total_debit numeric(20,6);
    v_total_credit numeric(20,6);
    v_status public.journal_entry_status;

begin

    -- --------------------------------------------------------
    -- Lock entry
    -- --------------------------------------------------------

    select *
    into v_entry
    from public.journal_entries
    where id = p_journal_entry_id
    for update;


    if not found then

        raise exception
            'Journal entry does not exist.';

    end if;


    -- --------------------------------------------------------
    -- Header validation
    -- --------------------------------------------------------

    perform public.validate_journal_entry_header(
        p_journal_entry_id
    );


    -- --------------------------------------------------------
    -- Lines validation
    -- --------------------------------------------------------

    perform public.validate_journal_entry_lines(
        p_journal_entry_id
    );


    -- --------------------------------------------------------
    -- Calculate totals
    -- --------------------------------------------------------

    select
        coalesce(sum(debit), 0),
        coalesce(sum(credit), 0)
    into
        v_total_debit,
        v_total_credit
    from public.journal_entry_lines
    where journal_entry_id = p_journal_entry_id;


    -- --------------------------------------------------------
    -- Balance
    -- --------------------------------------------------------

    if abs(
        v_total_debit
        -
        v_total_credit
    ) > 0.000001
    then

        raise exception
            'Journal entry is not balanced. Debits: %, Credits: %, Difference: %.',
            v_total_debit,
            v_total_credit,
            v_total_debit - v_total_credit;

    end if;


    if v_total_debit = 0 then

        raise exception
            'Journal entry total cannot be zero.';

    end if;


    -- --------------------------------------------------------
    -- Post atomically
    -- --------------------------------------------------------

    update public.journal_entries
    set
        status = 'posted'::public.journal_entry_status,
        posted_at = now(),
        posted_by = coalesce(
            auth.uid(),
            posted_by
        ),
        updated_at = now(),
        updated_by = coalesce(
            auth.uid(),
            updated_by
        )
    where id = p_journal_entry_id
      and status = 'draft'::public.journal_entry_status
    returning status
    into v_status;


    if v_status is null then

        raise exception
            'Journal entry could not be posted because its status changed.';

    end if;


    return p_journal_entry_id;

end;
$function$;


-- ============================================================
-- 6. UNPOSTING IS EXPLICITLY FORBIDDEN
-- ============================================================

create or replace function public.prevent_journal_unpost()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$

begin

    if old.status = 'posted'
       and new.status <> 'posted'
    then

        raise exception
            'A posted journal entry cannot be unposted. Create a reversal instead.';

    end if;


    if old.status = 'reversed'
       and new.status <> 'reversed'
    then

        raise exception
            'A reversed journal entry cannot be reopened.';

    end if;


    if old.status = 'void'
       and new.status <> 'void'
    then

        raise exception
            'A void journal entry cannot be reopened.';

    end if;


    return new;

end;
$function$;


drop trigger if exists
trg_prevent_journal_unpost
on public.journal_entries;


create trigger
trg_prevent_journal_unpost
before update
on public.journal_entries
for each row
execute function public.prevent_journal_unpost();


-- ============================================================
-- 7. JOURNAL POSTING AUDIT METADATA
-- ============================================================

comment on function public.next_journal_number(
    uuid
)
is
    'Generates the next journal number for a company.';


comment on function public.resolve_accounting_period(
    uuid,
    date
)
is
    'Resolves the open fiscal year and accounting period containing a journal date.';


comment on function public.validate_journal_entry_header(
    uuid
)
is
    'Validates company, branch, fiscal year, accounting period and journal header data before posting.';


comment on function public.validate_journal_entry_lines(
    uuid
)
is
    'Validates all journal lines before posting.';


comment on function public.post_journal_entry(
    uuid
)
is
    'Posts a balanced draft journal entry into the immutable posted state.';


-- ============================================================
-- 8. VALIDATION
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'post_journal_entry'
    ) then

        raise exception
            'post_journal_entry function was not created.';

    end if;


    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'validate_journal_entry_header'
    ) then

        raise exception
            'validate_journal_entry_header function was not created.';

    end if;


    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'validate_journal_entry_lines'
    ) then

        raise exception
            'validate_journal_entry_lines function was not created.';

    end if;

end
$$;
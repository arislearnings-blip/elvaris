-- ============================================================
-- ELVARIS ERP
-- Migration 021
-- Journal Reversal and Fiscal-Period Controls
-- ============================================================

-- ============================================================
-- 1. VALIDATE A JOURNAL'S FISCAL YEAR AND PERIOD
-- ============================================================

create or replace function public.validate_journal_period(
    p_journal_entry_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_entry public.journal_entries%rowtype;
    v_fiscal_year public.fiscal_years%rowtype;
    v_period public.accounting_periods%rowtype;

begin

    select *
    into v_entry
    from public.journal_entries
    where id = p_journal_entry_id;

    if not found then
        raise exception
            'Journal entry does not exist.';
    end if;


    if v_entry.fiscal_year_id is null then
        raise exception
            'Journal entry does not have a fiscal year.';
    end if;


    if v_entry.accounting_period_id is null then
        raise exception
            'Journal entry does not have an accounting period.';
    end if;


    select *
    into v_fiscal_year
    from public.fiscal_years
    where id = v_entry.fiscal_year_id
      and company_id = v_entry.company_id;

    if not found then
        raise exception
            'Fiscal year does not belong to the journal entry company.';
    end if;


    if v_fiscal_year.status <> 'open'::public.fiscal_year_status then
        raise exception
            'Fiscal year "%" is not open.',
            v_fiscal_year.name;
    end if;


    if v_entry.entry_date < v_fiscal_year.start_date
       or v_entry.entry_date > v_fiscal_year.end_date
    then
        raise exception
            'Journal date % is outside fiscal year "%".',
            v_entry.entry_date,
            v_fiscal_year.name;
    end if;


    select *
    into v_period
    from public.accounting_periods
    where id = v_entry.accounting_period_id
      and fiscal_year_id = v_entry.fiscal_year_id;

    if not found then
        raise exception
            'Accounting period does not belong to the selected fiscal year.';
    end if;


    if v_period.status <> 'open'::public.accounting_period_status then
        raise exception
            'Accounting period "%" is not open. Current status: %.',
            v_period.name,
            v_period.status;
    end if;


    if v_entry.entry_date < v_period.start_date
       or v_entry.entry_date > v_period.end_date
    then
        raise exception
            'Journal date % is outside accounting period "%".',
            v_entry.entry_date,
            v_period.name;
    end if;


    return true;

end;
$function$;


-- ============================================================
-- 2. UPDATE POSTING ENGINE TO CHECK PERIOD AGAIN
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

    v_posted_status public.journal_entry_status;

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


    if v_entry.status <> 'draft'::public.journal_entry_status then
        raise exception
            'Only draft journal entries can be posted. Current status: %.',
            v_entry.status;
    end if;


    perform public.validate_journal_entry_header(
        p_journal_entry_id
    );


    perform public.validate_journal_period(
        p_journal_entry_id
    );


    perform public.validate_journal_entry_lines(
        p_journal_entry_id
    );


    select
        coalesce(sum(debit), 0),
        coalesce(sum(credit), 0)
    into
        v_total_debit,
        v_total_credit
    from public.journal_entry_lines
    where journal_entry_id = p_journal_entry_id;


    if v_total_debit = 0 then
        raise exception
            'Journal entry total cannot be zero.';
    end if;


    if abs(v_total_debit - v_total_credit) > 0.000001 then
        raise exception
            'Journal entry is not balanced. Debits: %, Credits: %, Difference: %.',
            v_total_debit,
            v_total_credit,
            v_total_debit - v_total_credit;
    end if;


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
    into v_posted_status;


    if v_posted_status is null then
        raise exception
            'Journal entry could not be posted because its status changed.';
    end if;


    return p_journal_entry_id;

end;
$function$;


-- ============================================================
-- 3. CREATE JOURNAL REVERSAL
-- ============================================================

create or replace function public.reverse_journal_entry(
    p_journal_entry_id uuid,
    p_reversal_date date default current_date,
    p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_original public.journal_entries%rowtype;

    v_reversal_id uuid;

    v_reversal_number varchar(40);

    v_line record;

    v_line_number integer;

begin

    -- ========================================================
    -- LOCK ORIGINAL
    -- ========================================================

    select *
    into v_original
    from public.journal_entries
    where id = p_journal_entry_id
    for update;


    if not found then
        raise exception
            'Journal entry does not exist.';
    end if;


    -- ========================================================
    -- ONLY POSTED ENTRIES MAY BE REVERSED
    -- ========================================================

    if v_original.status <> 'posted'::public.journal_entry_status then

        raise exception
            'Only posted journal entries can be reversed. Current status: %.',
            v_original.status;

    end if;


    -- ========================================================
    -- PREVENT DOUBLE REVERSAL
    -- ========================================================

    if v_original.is_reversal then

        raise exception
            'A reversal journal entry cannot itself be reversed.';

    end if;


    if v_original.reversed_by_entry_id is not null then

        raise exception
            'Journal entry "%" has already been reversed.',
            v_original.journal_number;

    end if;


    -- ========================================================
    -- REVERSAL DATE
    -- ========================================================

    if p_reversal_date is null then

        raise exception
            'Reversal date is required.';

    end if;


    -- ========================================================
    -- GENERATE REVERSAL NUMBER
    -- ========================================================

    v_reversal_number :=
        public.next_journal_number(
            v_original.company_id
        );


    -- ========================================================
    -- CREATE REVERSAL HEADER
    -- ========================================================

    insert into public.journal_entries (
        company_id,
        branch_id,
        journal_number,
        entry_date,
        source_type,
        source_document_type,
        source_document_id,
        source_document_number,
        description,
        status,
        currency_id,
        exchange_rate,
        fiscal_year_id,
        accounting_period_id,
        is_reversal,
        reverses_entry_id,
        created_at,
        created_by,
        updated_at,
        updated_by
    )
    values (
        v_original.company_id,
        v_original.branch_id,
        v_reversal_number,
        p_reversal_date,
        'adjustment'::public.journal_source_type,
        'journal_reversal',
        v_original.id,
        v_original.journal_number,
        coalesce(
            p_description,
            'Reversal of journal entry '
            || v_original.journal_number
        ),
        'draft'::public.journal_entry_status,
        v_original.currency_id,
        v_original.exchange_rate,
        null,
        null,
        true,
        v_original.id,
        now(),
        auth.uid(),
        now(),
        auth.uid()
    )
    returning id
    into v_reversal_id;


    -- ========================================================
    -- COPY LINES WITH DEBIT / CREDIT REVERSED
    -- ========================================================

    v_line_number := 0;


    for v_line in
        select *
        from public.journal_entry_lines
        where journal_entry_id = v_original.id
        order by line_number
    loop

        v_line_number :=
            v_line_number + 1;


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
            v_reversal_id,
            v_line_number,
            v_line.account_id,
            v_line.branch_id,
            coalesce(
                v_line.description,
                v_original.description
            ),
            v_line.credit,
            v_line.debit,
            v_line.currency_id,
            v_line.exchange_rate,
            coalesce(v_line.foreign_credit, 0),
            coalesce(v_line.foreign_debit, 0),
            v_line.department_id,
            now(),
            auth.uid()
        );

    end loop;


    -- ========================================================
    -- RECORD RELATIONSHIP
    -- ========================================================

    update public.journal_entries
    set
        reversed_by_entry_id = v_reversal_id,
        status = 'reversed'::public.journal_entry_status,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_original.id;


    -- ========================================================
    -- POST REVERSAL
    -- ========================================================
    --
    -- This validates the reversal date against its own open
    -- fiscal year/accounting period.
    -- ========================================================

    perform public.post_journal_entry(
        v_reversal_id
    );


    return v_reversal_id;

end;
$function$;


-- ============================================================
-- 4. VERIFY REVERSAL RELATIONSHIP
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'journal_entries'
          and column_name = 'reverses_entry_id'
    ) then

        raise exception
            'reverses_entry_id column is missing.';

    end if;


    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'journal_entries'
          and column_name = 'reversed_by_entry_id'
    ) then

        raise exception
            'reversed_by_entry_id column is missing.';

    end if;

end
$$;


-- ============================================================
-- 5. COMMENTS
-- ============================================================

comment on function public.validate_journal_period(
    uuid
)
is
    'Ensures a journal entry belongs to an open fiscal year and open accounting period.';


comment on function public.reverse_journal_entry(
    uuid,
    date,
    text
)
is
    'Creates and posts a balanced reversal for an eligible posted journal entry.';


-- ============================================================
-- END MIGRATION 021
-- ============================================================
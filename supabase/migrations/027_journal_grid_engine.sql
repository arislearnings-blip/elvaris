-- ============================================================
-- ELVARIS ERP
-- Migration 027
-- Journal Grid / Bulk Line Engine
-- ============================================================
--
-- Purpose:
--   Provide the database layer for the professional journal
--   entry grid.
--
-- Supports:
--
--   * Multiple journal lines
--   * Account + Name + Description + Debit + Credit
--   * Optional Name
--   * Required Name based on account configuration
--   * Branch
--   * Department
--   * Atomic bulk line replacement
--   * Draft-only grid editing
--   * Partial-search views/functions
--   * Excel-style paste support at application level
--   * Universal JV numbering
--
-- IMPORTANT:
--   Excel copy/paste itself belongs to React.
--   This migration provides the atomic database operation needed
--   to save an entire pasted grid safely.
--
-- ============================================================


-- ============================================================
-- 1. REGENERATE JOURNAL NUMBERING
-- ============================================================
--
-- Journal numbers now use the universal numbering engine:
--
--     JV-0001
--     JV-0002
--     ...
--
-- The universal numbering profile created in migration 026
-- remains the source of truth.
-- ============================================================

create or replace function public.next_journal_number(
    p_company_id uuid
)
returns varchar(40)
language plpgsql
security definer
set search_path = public
as $function$

begin

    return public.next_reference_number(
        p_company_id,
        'JV',
        current_date
    );

end;
$function$;


-- ============================================================
-- 2. UPDATE CREATE JOURNAL ENTRY
-- ============================================================

create or replace function public.create_journal_entry(
    p_company_id uuid,
    p_entry_date date,
    p_description text default null,
    p_branch_id uuid default null,
    p_source_type public.journal_source_type default 'general_journal',
    p_currency_id uuid default null,
    p_reference_type varchar(50) default null,
    p_reference_number varchar(80) default null
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

    -- --------------------------------------------------------
    -- Company
    -- --------------------------------------------------------

    if not exists (
        select 1
        from public.companies c
        where c.id = p_company_id
          and c.is_active = true
    ) then

        raise exception
            'Active company does not exist.';

    end if;


    -- --------------------------------------------------------
    -- Date
    -- --------------------------------------------------------

    if p_entry_date is null then

        raise exception
            'Entry date is required.';

    end if;


    -- --------------------------------------------------------
    -- Branch
    -- --------------------------------------------------------

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


    -- --------------------------------------------------------
    -- Resolve fiscal year / period
    -- --------------------------------------------------------

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


    -- --------------------------------------------------------
    -- Universal journal number
    -- --------------------------------------------------------

    v_journal_number :=
        public.next_reference_number(
            p_company_id,
            'JV',
            p_entry_date
        );


    -- --------------------------------------------------------
    -- Create draft
    -- --------------------------------------------------------

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
        reference_type,
        reference_number,
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
        p_reference_type,
        p_reference_number,
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
-- 3. BULK REPLACE DRAFT JOURNAL LINES
-- ============================================================
--
-- p_lines format:
--
-- [
--   {
--     "account_id": "...",
--     "name_id": "...",
--     "description": "...",
--     "debit": 1000,
--     "credit": 0,
--     "branch_id": "...",
--     "department_id": "..."
--   },
--   ...
-- ]
--
-- This is ideal for an Excel-paste grid because the entire grid
-- can be validated and saved in one transaction.
-- ============================================================

create or replace function public.replace_draft_journal_lines(
    p_journal_entry_id uuid,
    p_lines jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_entry public.journal_entries%rowtype;

    v_line jsonb;

    v_line_number integer := 0;

    v_account_id uuid;

    v_name_id uuid;

    v_branch_id uuid;

    v_department_id uuid;

    v_description text;

    v_debit numeric(20,6);

    v_credit numeric(20,6);

begin

    -- --------------------------------------------------------
    -- Validate entry
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


    if v_entry.status <> 'draft'::public.journal_entry_status then

        raise exception
            'Only draft journal entries can have their grid lines replaced.';

    end if;


    if p_lines is null
       or jsonb_typeof(p_lines) <> 'array'
    then

        raise exception
            'Journal grid lines must be supplied as a JSON array.';

    end if;


    -- --------------------------------------------------------
    -- Delete current draft lines
    -- --------------------------------------------------------

    delete from public.journal_entry_lines
    where journal_entry_id = p_journal_entry_id;


    -- --------------------------------------------------------
    -- Process incoming grid
    -- --------------------------------------------------------

    for v_line in
        select value
        from jsonb_array_elements(p_lines)
    loop

        v_line_number :=
            v_line_number + 1;


        -- ----------------------------------------------------
        -- Account
        -- ----------------------------------------------------

        if nullif(
            v_line->>'account_id',
            ''
        ) is null then

            raise exception
                'Journal grid line % has no Account.',
                v_line_number;

        end if;


        v_account_id :=
            (v_line->>'account_id')::uuid;


        -- ----------------------------------------------------
        -- Validate account
        -- ----------------------------------------------------

        perform public.validate_journal_account(
            v_account_id
        );


        if not exists (
            select 1
            from public.chart_of_accounts coa
            where coa.id = v_account_id
              and coa.company_id = v_entry.company_id
        ) then

            raise exception
                'Journal grid line % uses an account from another company.',
                v_line_number;

        end if;


        -- ----------------------------------------------------
        -- Name
        -- ----------------------------------------------------

        if nullif(
            v_line->>'name_id',
            ''
        ) is null then

            v_name_id := null;

        else

            v_name_id :=
                (v_line->>'name_id')::uuid;

        end if;


        -- ----------------------------------------------------
        -- Required Name rule
        -- ----------------------------------------------------

        if public.journal_account_name_required(
            v_account_id
        ) then

            if v_name_id is null then

                raise exception
                    'Journal grid line % requires a Name for the selected account.',
                    v_line_number;

            end if;

        end if;


        -- ----------------------------------------------------
        -- Validate Name
        -- ----------------------------------------------------

        if v_name_id is not null then

            if not exists (
                select 1
                from public.accounting_names an
                where an.id = v_name_id
                  and an.company_id = v_entry.company_id
                  and an.is_active = true
            ) then

                raise exception
                    'Journal grid line % contains an invalid or inactive Name.',
                    v_line_number;

            end if;

        end if;


        -- ----------------------------------------------------
        -- Description
        -- ----------------------------------------------------

        v_description :=
            nullif(
                v_line->>'description',
                ''
            );


        -- ----------------------------------------------------
        -- Debit / Credit
        -- ----------------------------------------------------

        v_debit :=
            coalesce(
                nullif(
                    v_line->>'debit',
                    ''
                )::numeric,
                0
            );


        v_credit :=
            coalesce(
                nullif(
                    v_line->>'credit',
                    ''
                )::numeric,
                0
            );


        if v_debit < 0
           or v_credit < 0
        then

            raise exception
                'Journal grid line % has a negative amount.',
                v_line_number;

        end if;


        if v_debit > 0
           and v_credit > 0
        then

            raise exception
                'Journal grid line % cannot contain both Debit and Credit.',
                v_line_number;

        end if;


        if v_debit = 0
           and v_credit = 0
        then

            raise exception
                'Journal grid line % must contain Debit or Credit.',
                v_line_number;

        end if;


        -- ----------------------------------------------------
        -- Branch
        -- ----------------------------------------------------

        if nullif(
            v_line->>'branch_id',
            ''
        ) is null then

            v_branch_id := v_entry.branch_id;

        else

            v_branch_id :=
                (v_line->>'branch_id')::uuid;

        end if;


        if v_branch_id is not null then

            if not exists (
                select 1
                from public.branches b
                where b.id = v_branch_id
                  and b.company_id = v_entry.company_id
                  and b.is_active = true
            ) then

                raise exception
                    'Journal grid line % contains an invalid branch.',
                    v_line_number;

            end if;

        end if;


        -- ----------------------------------------------------
        -- Department
        -- ----------------------------------------------------

        if nullif(
            v_line->>'department_id',
            ''
        ) is null then

            v_department_id := null;

        else

            v_department_id :=
                (v_line->>'department_id')::uuid;

        end if;


        if v_department_id is not null then

            if not exists (
                select 1
                from public.departments d
                where d.id = v_department_id
                  and d.company_id = v_entry.company_id
                  and d.is_active = true
            ) then

                raise exception
                    'Journal grid line % contains an invalid department.',
                    v_line_number;

            end if;

        end if;


        -- ----------------------------------------------------
        -- Insert
        -- ----------------------------------------------------

        insert into public.journal_entry_lines (
            journal_entry_id,
            line_number,
            account_id,
            branch_id,
            name_id,
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
            v_line_number,
            v_account_id,
            v_branch_id,
            v_name_id,
            v_description,
            v_debit,
            v_credit,
            v_entry.currency_id,
            v_entry.exchange_rate,
            0,
            0,
            v_department_id,
            now(),
            auth.uid()
        );

    end loop;


    return v_line_number;

end;
$function$;


-- ============================================================
-- 4. UPDATE DRAFT HEADER
-- ============================================================

create or replace function public.update_draft_journal_header(
    p_journal_entry_id uuid,
    p_entry_date date,
    p_description text default null,
    p_branch_id uuid default null,
    p_reference_type varchar(50) default null,
    p_reference_number varchar(80) default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_entry public.journal_entries%rowtype;

    v_fiscal_year_id uuid;

    v_period_id uuid;

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
            'Only draft journal entries can be edited.';

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
              and b.company_id = v_entry.company_id
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
        v_entry.company_id,
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


    update public.journal_entries
    set
        entry_date = p_entry_date,
        description = p_description,
        branch_id = p_branch_id,
        fiscal_year_id = v_fiscal_year_id,
        accounting_period_id = v_period_id,
        reference_type = p_reference_type,
        reference_number = p_reference_number,
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_journal_entry_id;


    return p_journal_entry_id;

end;
$function$;


-- ============================================================
-- 5. GET COMPLETE JOURNAL FOR GRID EDITING / DISPLAY
-- ============================================================

create or replace function public.get_journal_entry_grid(
    p_journal_entry_id uuid
)
returns table (
    journal_entry_id uuid,
    journal_number varchar(40),
    entry_date date,
    company_id uuid,
    branch_id uuid,
    source_type public.journal_source_type,
    reference_type varchar(50),
    reference_number varchar(80),
    description text,
    status public.journal_entry_status,
    fiscal_year_id uuid,
    accounting_period_id uuid,
    line_id uuid,
    line_number integer,
    account_id uuid,
    account_code varchar(30),
    account_name varchar(150),
    account_role public.account_role,
    name_id uuid,
    name_code varchar(50),
    name_type public.accounting_name_type,
    name_display varchar(200),
    line_description text,
    debit numeric,
    credit numeric,
    department_id uuid,
    line_branch_id uuid
)
language sql
security definer
stable
set search_path = public
as $function$

    select

        je.id,
        je.journal_number,
        je.entry_date,
        je.company_id,
        je.branch_id,
        je.source_type,
        je.reference_type,
        je.reference_number,
        je.description,
        je.status,
        je.fiscal_year_id,
        je.accounting_period_id,

        jel.id,
        jel.line_number,

        coa.id,
        coa.account_code,
        coa.account_name,
        coa.account_role,

        jel.name_id,

        an.name_code,
        an.name_type,
        an.display_name,

        jel.description,

        jel.debit,
        jel.credit,

        jel.department_id,
        jel.branch_id

    from public.journal_entries je

    left join public.journal_entry_lines jel
        on jel.journal_entry_id = je.id

    left join public.chart_of_accounts coa
        on coa.id = jel.account_id

    left join public.accounting_names an
        on an.id = jel.name_id

    where je.id = p_journal_entry_id

    order by
        jel.line_number;

$function$;


-- ============================================================
-- 6. JOURNAL SEARCH
-- ============================================================

create or replace function public.search_journal_entries(
    p_company_id uuid,
    p_search text default null,
    p_status public.journal_entry_status default null,
    p_limit integer default 100
)
returns table (
    id uuid,
    journal_number varchar(40),
    entry_date date,
    reference_type varchar(50),
    reference_number varchar(80),
    description text,
    status public.journal_entry_status,
    line_count bigint,
    total_debit numeric,
    total_credit numeric
)
language sql
security definer
stable
set search_path = public
as $function$

    select

        je.id,

        je.journal_number,

        je.entry_date,

        je.reference_type,

        je.reference_number,

        je.description,

        je.status,

        count(jel.id),

        coalesce(
            sum(jel.debit),
            0
        ),

        coalesce(
            sum(jel.credit),
            0
        )

    from public.journal_entries je

    left join public.journal_entry_lines jel
        on jel.journal_entry_id = je.id

    where je.company_id = p_company_id

      and (
          p_status is null
          or je.status = p_status
      )

      and (
          nullif(trim(p_search), '') is null

          or je.journal_number ilike
              '%' || trim(p_search) || '%'

          or coalesce(
                je.reference_number,
                ''
             ) ilike
              '%' || trim(p_search) || '%'

          or coalesce(
                je.reference_type,
                ''
             ) ilike
              '%' || trim(p_search) || '%'

          or coalesce(
                je.description,
                ''
             ) ilike
              '%' || trim(p_search) || '%'
      )

    group by
        je.id,
        je.journal_number,
        je.entry_date,
        je.reference_type,
        je.reference_number,
        je.description,
        je.status

    order by
        je.entry_date desc,
        je.journal_number desc

    limit greatest(
        least(
            coalesce(p_limit, 100),
            500
        ),
        1
    );

$function$;


-- ============================================================
-- 7. COMMENTS
-- ============================================================

comment on function public.replace_draft_journal_lines(
    uuid,
    jsonb
)
is
    'Atomically replaces all lines of a draft journal entry. Designed for multi-line grid and Excel-paste workflows.';


comment on function public.update_draft_journal_header(
    uuid,
    date,
    text,
    uuid,
    varchar,
    varchar
)
is
    'Updates the editable header fields of a draft journal entry.';


comment on function public.get_journal_entry_grid(
    uuid
)
is
    'Returns a journal entry and its lines in grid-ready form.';


comment on function public.search_journal_entries(
    uuid,
    text,
    public.journal_entry_status,
    integer
)
is
    'Searches journal entries using partial journal number, reference number, reference type and description matching.';


-- ============================================================
-- 8. VALIDATION
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from public.chart_of_accounts
        where system_account_code = 'accounts_receivable'
          and name_requirement =
              'required'::public.account_name_requirement
    ) then

        raise exception
            'Accounts Receivable Name requirement is not configured.';

    end if;


    if not exists (
        select 1
        from public.chart_of_accounts
        where system_account_code = 'accounts_payable'
          and name_requirement =
              'required'::public.account_name_requirement
    ) then

        raise exception
            'Accounts Payable Name requirement is not configured.';

    end if;


    if not exists (
        select 1
        from public.numbering_profiles
        where document_type = 'JV'
          and prefix = 'JV'
          and active = true
    ) then

        raise exception
            'Active JV numbering profile is missing.';

    end if;


    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'journal_entry_lines'
          and column_name = 'name_id'
    ) then

        raise exception
            'journal_entry_lines.name_id is missing.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 027
-- ============================================================
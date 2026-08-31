-- ============================================================
-- ELVARIS ERP
-- Migration 031
-- Journal Transaction Service Layer
-- ============================================================
--
-- Purpose:
--   Provide a stable RPC/service contract for the Journal Voucher
--   application.
--
-- The React application should call these service functions
-- rather than manipulating accounting tables directly.
--
-- Main operations:
--
--   create
--   load
--   save header + grid
--   post
--   delete draft
--   reverse
--   search
--
-- ============================================================


-- ============================================================
-- 1. CREATE JOURNAL TRANSACTION
-- ============================================================

create or replace function public.create_journal_transaction(
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

begin

    v_journal_id :=
        public.create_journal_entry(
            p_company_id,
            p_entry_date,
            p_description,
            p_branch_id,
            p_source_type,
            p_currency_id,
            p_reference_type,
            p_reference_number
        );


    return v_journal_id;

end;
$function$;


-- ============================================================
-- 2. LOAD JOURNAL TRANSACTION
-- ============================================================

create or replace function public.load_journal_transaction(
    p_journal_entry_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_header jsonb;
    v_lines jsonb;
    v_result jsonb;

begin

    select
        jsonb_build_object(
            'id', je.id,
            'company_id', je.company_id,
            'branch_id', je.branch_id,
            'journal_number', je.journal_number,
            'entry_date', je.entry_date,
            'source_type', je.source_type,
            'reference_type', je.reference_type,
            'reference_number', je.reference_number,
            'description', je.description,
            'status', je.status,
            'currency_id', je.currency_id,
            'exchange_rate', je.exchange_rate,
            'fiscal_year_id', je.fiscal_year_id,
            'accounting_period_id', je.accounting_period_id,
            'is_reversal', je.is_reversal,
            'reverses_entry_id', je.reverses_entry_id,
            'reversed_by_entry_id', je.reversed_by_entry_id,
            'posted_at', je.posted_at,
            'posted_by', je.posted_by,
            'created_at', je.created_at,
            'created_by', je.created_by,
            'updated_at', je.updated_at,
            'updated_by', je.updated_by
        )
    into v_header
    from public.journal_entries je
    where je.id = p_journal_entry_id;


    if v_header is null then

        raise exception
            'Journal entry does not exist.';

    end if;


    select
        coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'id', jel.id,
                    'line_number', jel.line_number,
                    'account_id', jel.account_id,
                    'account_code', coa.account_code,
                    'account_name', coa.account_name,
                    'account_role', coa.account_role,
                    'name_id', jel.name_id,
                    'name_code', an.name_code,
                    'name_type', an.name_type,
                    'name_display', an.display_name,
                    'description', jel.description,
                    'debit', jel.debit,
                    'credit', jel.credit,
                    'branch_id', jel.branch_id,
                    'department_id', jel.department_id
                )
                order by jel.line_number
            ),
            '[]'::jsonb
        )
    into v_lines
    from public.journal_entry_lines jel

    join public.chart_of_accounts coa
        on coa.id = jel.account_id

    left join public.accounting_names an
        on an.id = jel.name_id

    where jel.journal_entry_id = p_journal_entry_id;


    v_result :=
        jsonb_build_object(
            'header', v_header,
            'lines', v_lines
        );


    return v_result;

end;
$function$;


-- ============================================================
-- 3. SAVE JOURNAL TRANSACTION
-- ============================================================
--
-- Saves the header and complete grid atomically.
--
-- If any line fails validation, the entire operation fails.
-- ============================================================

create or replace function public.save_journal_transaction(
    p_journal_entry_id uuid,
    p_entry_date date,
    p_description text default null,
    p_branch_id uuid default null,
    p_reference_type varchar(50) default null,
    p_reference_number varchar(80) default null,
    p_lines jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_entry public.journal_entries%rowtype;
    v_line_count integer;
    v_result jsonb;

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


    if v_entry.status <>
       'draft'::public.journal_entry_status
    then

        raise exception
            'Only draft journal entries can be saved.';

    end if;


    perform public.update_draft_journal_header(
        p_journal_entry_id,
        p_entry_date,
        p_description,
        p_branch_id,
        p_reference_type,
        p_reference_number
    );


    v_line_count :=
        public.replace_draft_journal_lines(
            p_journal_entry_id,
            p_lines
        );


    v_result :=
        public.load_journal_transaction(
            p_journal_entry_id
        );


    return
        jsonb_set(
            v_result,
            '{line_count}',
            to_jsonb(v_line_count),
            true
        );

end;
$function$;


-- ============================================================
-- 4. POST JOURNAL TRANSACTION
-- ============================================================

create or replace function public.post_journal_transaction(
    p_journal_entry_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_id uuid;
    v_result jsonb;

begin

    v_id :=
        public.post_journal_entry(
            p_journal_entry_id
        );


    v_result :=
        public.load_journal_transaction(
            v_id
        );


    return v_result;

end;
$function$;


-- ============================================================
-- 5. DELETE DRAFT TRANSACTION
-- ============================================================

create or replace function public.delete_journal_transaction(
    p_journal_entry_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$

begin

    return public.delete_draft_journal_entry(
        p_journal_entry_id
    );

end;
$function$;


-- ============================================================
-- 6. REVERSE POSTED TRANSACTION
-- ============================================================

create or replace function public.reverse_journal_transaction(
    p_journal_entry_id uuid,
    p_reversal_date date default current_date,
    p_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_reversal_id uuid;
    v_result jsonb;

begin

    v_reversal_id :=
        public.reverse_journal_entry(
            p_journal_entry_id,
            p_reversal_date,
            p_description
        );


    v_result :=
        public.load_journal_transaction(
            v_reversal_id
        );


    return v_result;

end;
$function$;


-- ============================================================
-- 7. SEARCH JOURNAL TRANSACTIONS
-- ============================================================

create or replace function public.search_journal_transactions(
    p_company_id uuid,
    p_search text default null,
    p_status public.journal_entry_status default null,
    p_reference_type varchar(50) default null,
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
          p_reference_type is null
          or je.reference_type = p_reference_type
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
-- 8. JOURNAL GRID TOTALS
-- ============================================================

create or replace function public.get_journal_grid_totals(
    p_journal_entry_id uuid
)
returns table (
    line_count bigint,
    total_debit numeric,
    total_credit numeric,
    difference numeric,
    is_balanced boolean
)
language sql
security definer
stable
set search_path = public
as $function$

    select

        count(*) as line_count,

        coalesce(
            sum(debit),
            0
        ) as total_debit,

        coalesce(
            sum(credit),
            0
        ) as total_credit,

        coalesce(
            sum(debit),
            0
        )
        -
        coalesce(
            sum(credit),
            0
        ) as difference,

        abs(
            coalesce(
                sum(debit),
                0
            )
            -
            coalesce(
                sum(credit),
                0
            )
        ) <= 0.000001 as is_balanced

    from public.journal_entry_lines

    where journal_entry_id = p_journal_entry_id;

$function$;


-- ============================================================
-- 9. COMMENTS
-- ============================================================

comment on function public.create_journal_transaction(
    uuid,
    date,
    text,
    uuid,
    public.journal_source_type,
    uuid,
    varchar,
    varchar
)
is
    'Creates a draft journal transaction through the application service layer.';


comment on function public.load_journal_transaction(
    uuid
)
is
    'Loads a complete journal transaction, including header and grid lines, as JSON.';


comment on function public.save_journal_transaction(
    uuid,
    date,
    text,
    uuid,
    varchar,
    varchar,
    jsonb
)
is
    'Atomically saves a draft journal header and its complete multi-line grid.';


comment on function public.post_journal_transaction(
    uuid
)
is
    'Posts a validated journal transaction through the controlled posting engine.';


comment on function public.delete_journal_transaction(
    uuid
)
is
    'Deletes a journal transaction only while it remains a draft.';


comment on function public.reverse_journal_transaction(
    uuid,
    date,
    text
)
is
    'Creates and posts a balanced reversal of a posted journal transaction.';


comment on function public.search_journal_transactions(
    uuid,
    text,
    public.journal_entry_status,
    varchar,
    integer
)
is
    'Searches journal transactions using partial journal, reference and description matching.';


comment on function public.get_journal_grid_totals(
    uuid
)
is
    'Returns live debit, credit, difference and balance status for a journal grid.';


-- ============================================================
-- 10. VALIDATION
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'create_journal_transaction'
    ) then

        raise exception
            'create_journal_transaction was not created.';

    end if;


    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'load_journal_transaction'
    ) then

        raise exception
            'load_journal_transaction was not created.';

    end if;


    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'save_journal_transaction'
    ) then

        raise exception
            'save_journal_transaction was not created.';

    end if;


    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'post_journal_transaction'
    ) then

        raise exception
            'post_journal_transaction was not created.';

    end if;


    if not exists (
        select 1
        from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname = 'get_journal_grid_totals'
    ) then

        raise exception
            'get_journal_grid_totals was not created.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 031
-- ============================================================
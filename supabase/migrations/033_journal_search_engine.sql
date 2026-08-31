-- ============================================================
-- ELVARIS ERP
-- Migration 033
-- Professional Journal Transaction Search
-- ============================================================
--
-- Purpose:
--   Universal Journal Voucher search.
--
-- Global search covers:
--
--   Journal Number
--   Reference Type
--   Reference Number
--   Description / Memo
--   Account Code
--   Account Name
--   Name Code
--   Name
--   Name Type
--   Branch
--   Department
--   Debit
--   Credit
--   Entry Date
--
-- Explicit filters:
--
--   Date From / To
--   Reference From / To
--   Amount From / To
--   Reference Type
--   Account
--   Name
--   Branch
--   Department
--   Status
--
-- ============================================================


-- ============================================================
-- 1. SEARCH INDEXES
-- ============================================================

create index if not exists
idx_journal_entries_company_date_search
on public.journal_entries (
    company_id,
    entry_date desc
);


create index if not exists
idx_journal_entries_company_reference_search
on public.journal_entries (
    company_id,
    reference_type,
    reference_number
);


create index if not exists
idx_journal_entries_company_journal_search
on public.journal_entries (
    company_id,
    journal_number
);


create index if not exists
idx_journal_lines_account_search
on public.journal_entry_lines (
    account_id,
    journal_entry_id
);


create index if not exists
idx_journal_lines_name_search
on public.journal_entry_lines (
    name_id,
    journal_entry_id
);


create index if not exists
idx_journal_lines_branch_search
on public.journal_entry_lines (
    branch_id,
    journal_entry_id
);


create index if not exists
idx_journal_lines_department_search
on public.journal_entry_lines (
    department_id,
    journal_entry_id
);


-- ============================================================
-- 2. PROFESSIONAL JOURNAL FINDER
-- ============================================================

create or replace function public.find_journal_transactions(
    p_company_id uuid,

    p_search text default null,

    p_date_from date default null,
    p_date_to date default null,

    p_reference_from varchar(80) default null,
    p_reference_to varchar(80) default null,

    p_amount_from numeric default null,
    p_amount_to numeric default null,

    p_reference_type varchar(50) default null,

    p_account_id uuid default null,
    p_name_id uuid default null,

    p_branch_id uuid default null,
    p_department_id uuid default null,

    p_status public.journal_entry_status default null,

    p_limit integer default 100
)
returns table (
    id uuid,
    journal_number varchar(40),
    entry_date date,

    reference_type varchar(50),
    reference_type_name varchar(100),
    reference_number varchar(80),

    description text,

    status public.journal_entry_status,

    line_count bigint,

    total_debit numeric,
    total_credit numeric,

    matched_accounts text,
    matched_names text,

    amount_min numeric,
    amount_max numeric
)
language sql
security definer
stable
set search_path = public
as $function$

with candidate_entries as (

    select distinct
        je.id

    from public.journal_entries je

    left join public.journal_entry_lines jel
        on jel.journal_entry_id = je.id

    left join public.chart_of_accounts coa
        on coa.id = jel.account_id

    left join public.accounting_names an
        on an.id = jel.name_id

    left join public.branches b
        on b.id = jel.branch_id

    left join public.departments d
        on d.id = jel.department_id

    where je.company_id = p_company_id

      -- ------------------------------------------------------
      -- DATE
      -- ------------------------------------------------------

      and (
          p_date_from is null
          or je.entry_date >= p_date_from
      )

      and (
          p_date_to is null
          or je.entry_date <= p_date_to
      )

      -- ------------------------------------------------------
      -- REFERENCE
      -- ------------------------------------------------------

      and (
          p_reference_from is null
          or coalesce(
                je.reference_number,
                ''
             ) >= p_reference_from
      )

      and (
          p_reference_to is null
          or coalesce(
                je.reference_number,
                ''
             ) <= p_reference_to
      )

      -- ------------------------------------------------------
      -- REFERENCE TYPE
      -- ------------------------------------------------------

      and (
          p_reference_type is null
          or je.reference_type =
              p_reference_type
      )

      -- ------------------------------------------------------
      -- ACCOUNT
      -- ------------------------------------------------------

      and (
          p_account_id is null
          or exists (
              select 1
              from public.journal_entry_lines x
              where x.journal_entry_id = je.id
                and x.account_id = p_account_id
          )
      )

      -- ------------------------------------------------------
      -- NAME
      -- ------------------------------------------------------

      and (
          p_name_id is null
          or exists (
              select 1
              from public.journal_entry_lines x
              where x.journal_entry_id = je.id
                and x.name_id = p_name_id
          )
      )

      -- ------------------------------------------------------
      -- BRANCH
      -- ------------------------------------------------------

      and (
          p_branch_id is null
          or je.branch_id = p_branch_id
          or exists (
              select 1
              from public.journal_entry_lines x
              where x.journal_entry_id = je.id
                and x.branch_id = p_branch_id
          )
      )

      -- ------------------------------------------------------
      -- DEPARTMENT
      -- ------------------------------------------------------

      and (
          p_department_id is null
          or exists (
              select 1
              from public.journal_entry_lines x
              where x.journal_entry_id = je.id
                and x.department_id = p_department_id
          )
      )

      -- ------------------------------------------------------
      -- STATUS
      -- ------------------------------------------------------

      and (
          p_status is null
          or je.status = p_status
      )

      -- ------------------------------------------------------
      -- AMOUNT RANGE
      --
      -- The transaction qualifies when any debit/credit line
      -- falls inside the requested amount range.
      -- ------------------------------------------------------

      and (
          (
              p_amount_from is null
              and p_amount_to is null
          )

          or exists (
              select 1
              from public.journal_entry_lines x
              where x.journal_entry_id = je.id
                and (
                    (
                        x.debit > 0
                        and (
                            p_amount_from is null
                            or x.debit >= p_amount_from
                        )
                        and (
                            p_amount_to is null
                            or x.debit <= p_amount_to
                        )
                    )

                    or

                    (
                        x.credit > 0
                        and (
                            p_amount_from is null
                            or x.credit >= p_amount_from
                        )
                        and (
                            p_amount_to is null
                            or x.credit <= p_amount_to
                        )
                    )
                )
          )
      )

      -- ------------------------------------------------------
      -- GLOBAL PARTIAL SEARCH
      -- ------------------------------------------------------

      and (
          nullif(
              trim(p_search),
              ''
          ) is null

          or

          je.journal_number ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          coalesce(
              je.reference_type,
              ''
          ) ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          coalesce(
              je.reference_number,
              ''
          ) ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          coalesce(
              je.description,
              ''
          ) ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          to_char(
              je.entry_date,
              'YYYY-MM-DD'
          ) ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          to_char(
              je.entry_date,
              'DD/MM/YYYY'
          ) ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          coa.account_code ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          coa.account_name ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          an.name_code ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          an.display_name ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          an.name_type::text ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          b.branch_code ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          b.name ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          d.code ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          d.name ilike
              '%' ||
              trim(p_search) ||
              '%'

          or

          cast(
              abs(jel.debit)
              as text
          ) ilike
              '%' ||
              replace(
                  trim(p_search),
                  ',',
                  ''
              ) ||
              '%'

          or

          cast(
              abs(jel.credit)
              as text
          ) ilike
              '%' ||
              replace(
                  trim(p_search),
                  ',',
                  ''
              ) ||
              '%'
      )
)

select

    je.id,

    je.journal_number,

    je.entry_date,

    je.reference_type,

    dt.name,

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
    ),

    string_agg(
        distinct
        coa.account_code ||
        ' — ' ||
        coa.account_name,
        ', '
    ),

    string_agg(
        distinct
        an.name_code ||
        ' — ' ||
        an.display_name,
        ', '
    ),

    min(
        greatest(
            coalesce(jel.debit, 0),
            coalesce(jel.credit, 0)
        )
    ),

    max(
        greatest(
            coalesce(jel.debit, 0),
            coalesce(jel.credit, 0)
        )
    )

from public.journal_entries je

join public.journal_entry_lines jel
    on jel.journal_entry_id = je.id

join public.chart_of_accounts coa
    on coa.id = jel.account_id

left join public.accounting_names an
    on an.id = jel.name_id

left join public.document_types dt
    on dt.code = je.reference_type

where je.company_id = p_company_id

  and exists (
      select 1
      from candidate_entries ce
      where ce.id = je.id
  )

group by
    je.id,
    je.journal_number,
    je.entry_date,
    je.reference_type,
    dt.name,
    je.reference_number,
    je.description,
    je.status

order by
    je.entry_date desc,
    je.journal_number desc

limit greatest(
    least(
        coalesce(
            p_limit,
            100
        ),
        500
    ),
    1
);

$function$;


-- ============================================================
-- 3. SIMPLE GLOBAL SEARCH
-- ============================================================

create or replace function public.find_journal_global(
    p_company_id uuid,
    p_search text,
    p_limit integer default 100
)
returns table (
    id uuid,
    journal_number varchar(40),
    entry_date date,
    reference_type varchar(50),
    reference_type_name varchar(100),
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
        f.id,
        f.journal_number,
        f.entry_date,
        f.reference_type,
        f.reference_type_name,
        f.reference_number,
        f.description,
        f.status,
        f.line_count,
        f.total_debit,
        f.total_credit

    from public.find_journal_transactions(
        p_company_id,
        p_search,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        p_limit
    ) f

    order by
        f.entry_date desc,
        f.journal_number desc;

$function$;


-- ============================================================
-- 4. DOCUMENTATION
-- ============================================================

comment on function public.find_journal_transactions(
    uuid,
    text,
    date,
    date,
    varchar,
    varchar,
    numeric,
    numeric,
    varchar,
    uuid,
    uuid,
    uuid,
    uuid,
    public.journal_entry_status,
    integer
)
is
    'Professional Journal Voucher finder with global partial search and Date/Reference/Amount From-To filters plus Account, Name, Branch, Department, Reference Type and Status filters.';


comment on function public.find_journal_global(
    uuid,
    text,
    integer
)
is
    'Global partial search across Journal Voucher date, number, reference, account, Name, amount, description, branch and department.';


-- ============================================================
-- 5. VALIDATION
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_proc
        where pronamespace =
            'public'::regnamespace
          and proname =
            'find_journal_transactions'
    ) then

        raise exception
            'find_journal_transactions was not created.';

    end if;


    if not exists (
        select 1
        from pg_proc
        where pronamespace =
            'public'::regnamespace
          and proname =
            'find_journal_global'
    ) then

        raise exception
            'find_journal_global was not created.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 033
-- ============================================================
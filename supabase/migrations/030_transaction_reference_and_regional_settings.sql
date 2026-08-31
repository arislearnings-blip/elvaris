-- ============================================================
-- ELVARIS ERP
-- Migration 030
-- Universal Transaction References and Regional Settings
-- ============================================================
--
-- Purpose:
--   1. Normalize journal reference types against the universal
--      document type catalogue.
--   2. Provide universal date/time/number-format preferences.
--   3. Keep document numbering and transaction references
--      consistent across the ERP.
--
-- Examples:
--
--   Journal Number:    JV-0001
--   Reference Type:    INV
--   Reference Number:  INV-0001
--
--   Journal Number:    JV-0002
--   Reference Type:    B
--   Reference Number:  B-0001
--
-- The journal number identifies the accounting entry.
-- The reference identifies the related business document.
-- ============================================================


-- ============================================================
-- 1. NORMALIZE JOURNAL REFERENCE TYPE
-- ============================================================
--
-- reference_type contains the universal document type CODE:
--
--   JV
--   INV
--   PO
--   B
--   OR
--   PV
--   GRN
--   MO
--   etc.
--
-- The human-readable name comes from document_types.
-- ============================================================

create index if not exists
idx_journal_entries_reference_type
on public.journal_entries (
    company_id,
    reference_type
);


create index if not exists
idx_journal_entries_reference_number
on public.journal_entries (
    company_id,
    reference_number
);


-- ============================================================
-- 2. CLEAN EXISTING REFERENCE TYPES
-- ============================================================
--
-- Current database has no journal data, but this normalization
-- safely converts common full names to the universal codes if
-- any records exist later through earlier development.
-- ============================================================

update public.journal_entries
set reference_type = 'JV'
where upper(trim(reference_type)) in (
    'JOURNAL',
    'JOURNAL VOUCHER',
    'GENERAL JOURNAL',
    'JV'
);


update public.journal_entries
set reference_type = 'INV'
where upper(trim(reference_type)) in (
    'INVOICE',
    'SALES INVOICE',
    'INV'
);


update public.journal_entries
set reference_type = 'PO'
where upper(trim(reference_type)) in (
    'PURCHASE ORDER',
    'PO'
);


update public.journal_entries
set reference_type = 'B'
where upper(trim(reference_type)) in (
    'BILL',
    'VENDOR BILL',
    'PURCHASE BILL',
    'B'
);


update public.journal_entries
set reference_type = 'OR'
where upper(trim(reference_type)) in (
    'RECEIPT',
    'CUSTOMER RECEIPT',
    'OR'
);


update public.journal_entries
set reference_type = 'PV'
where upper(trim(reference_type)) in (
    'PAYMENT',
    'PAYMENT VOUCHER',
    'PV'
);


update public.journal_entries
set reference_type = 'GRN'
where upper(trim(reference_type)) in (
    'GRN',
    'GOODS RECEIPT',
    'GOODS RECEIPT NOTE'
);


update public.journal_entries
set reference_type = 'MO'
where upper(trim(reference_type)) in (
    'MO',
    'MANUFACTURING ORDER',
    'MANUFACTURING'
);


-- ============================================================
-- 3. REMOVE INVALID REFERENCE TYPES
-- ============================================================
--
-- Only registered universal document types are allowed.
--
-- Since no real journal entries currently exist, any unexpected
-- value would be development residue and is cleared rather than
-- incorrectly mapped.
-- ============================================================

update public.journal_entries je
set
    reference_type = null,
    reference_number = null
where je.reference_type is not null
  and not exists (
      select 1
      from public.document_types dt
      where dt.code = je.reference_type
  );


-- ============================================================
-- 4. FOREIGN KEY FOR REFERENCE TYPE
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_constraint
        where conname =
            'journal_entries_reference_type_fkey'
          and conrelid =
            'public.journal_entries'::regclass
    ) then

        alter table public.journal_entries
        add constraint journal_entries_reference_type_fkey
        foreign key (reference_type)
        references public.document_types(code)
        on delete restrict;

    end if;

end
$$;


-- ============================================================
-- 5. REFERENCE NUMBER VALIDATION
-- ============================================================

alter table public.journal_entries
drop constraint if exists
    journal_entries_reference_number_check;


alter table public.journal_entries
add constraint
    journal_entries_reference_number_check
check (
    reference_number is null
    or length(trim(reference_number)) > 0
);


-- ============================================================
-- 6. REFERENCE TYPE / NUMBER CONSISTENCY
-- ============================================================
--
-- A reference number cannot exist without a reference type.
-- A reference type may exist without a reference number while
-- a draft is being prepared.
-- ============================================================

alter table public.journal_entries
drop constraint if exists
    journal_entries_reference_pair_check;


alter table public.journal_entries
add constraint
    journal_entries_reference_pair_check
check (
    reference_number is null
    or reference_type is not null
);


-- ============================================================
-- 7. UNIVERSAL REGIONAL SETTINGS
-- ============================================================
--
-- companies already contains:
--
--   date_format
--   decimal_places
--
-- We add universal preferences that can be used by every
-- module instead of duplicating formatting rules.
-- ============================================================

alter table public.companies
add column if not exists
    time_format varchar(10) not null default '12h';


alter table public.companies
add column if not exists
    first_day_of_week smallint not null default 1;


alter table public.companies
add column if not exists
    number_format varchar(30) not null default '1,234.56';


alter table public.companies
add column if not exists
    negative_number_format varchar(30) not null default '-1,234.56';


alter table public.companies
drop constraint if exists
    companies_time_format_check;


alter table public.companies
add constraint
    companies_time_format_check
check (
    time_format in (
        '12h',
        '24h'
    )
);


alter table public.companies
drop constraint if exists
    companies_first_day_of_week_check;


alter table public.companies
add constraint
    companies_first_day_of_week_check
check (
    first_day_of_week between 0 and 6
);


alter table public.companies
drop constraint if exists
    companies_number_format_check;


alter table public.companies
add constraint
    companies_number_format_check
check (
    number_format in (
        '1,234.56',
        '1.234,56',
        '1 234.56',
        '1 234,56',
        '1234.56'
    )
);


alter table public.companies
drop constraint if exists
    companies_negative_number_format_check;


alter table public.companies
add constraint
    companies_negative_number_format_check
check (
    negative_number_format in (
        '-1,234.56',
        '(1,234.56)',
        '-1.234,56',
        '(1.234,56)',
        '-1 234.56',
        '(1 234,56)'
    )
);


-- ============================================================
-- 8. DEFAULT REGIONAL SETTINGS
-- ============================================================

update public.companies
set
    date_format =
        case
            when date_format is null
              or trim(date_format) = ''
            then 'DD/MM/YYYY'
            else date_format
        end,

    time_format =
        coalesce(
            nullif(trim(time_format), ''),
            '12h'
        ),

    first_day_of_week =
        coalesce(
            first_day_of_week,
            1
        ),

    number_format =
        coalesce(
            nullif(trim(number_format), ''),
            '1,234.56'
        ),

    negative_number_format =
        coalesce(
            nullif(trim(negative_number_format), ''),
            '-1,234.56'
        ),

    updated_at = now();


-- ============================================================
-- 9. UNIVERSAL FORMATTING PROFILE VIEW
-- ============================================================

create or replace view public.company_format_settings
as
select
    c.id as company_id,
    c.company_code,
    c.date_format,
    c.time_format,
    c.first_day_of_week,
    c.number_format,
    c.negative_number_format,
    c.decimal_places
from public.companies c;


-- ============================================================
-- 10. DOCUMENT REFERENCE LOOKUP VIEW
-- ============================================================
--
-- Gives the UI a single source for:
--
--   Code
--   Display name
--   Module
--   Description
--   Active status
--
-- ============================================================

create or replace view public.document_reference_catalog
as
select
    dt.code,
    dt.name,
    dt.module,
    dt.description,
    dt.is_active,
    dt.display_order
from public.document_types dt
where dt.is_active = true;


-- ============================================================
-- 11. UNIVERSAL REFERENCE SEARCH
-- ============================================================
--
-- Supports partial:
--
--   JV
--   0001
--   INV
--   ABC
--   invoice
--
-- ============================================================

create or replace function public.search_transaction_references(
    p_company_id uuid,
    p_search text default null,
    p_reference_type varchar(50) default null,
    p_limit integer default 100
)
returns table (
    journal_entry_id uuid,
    journal_number varchar(40),
    reference_type varchar(50),
    reference_type_name varchar(100),
    reference_number varchar(80),
    entry_date date,
    status public.journal_entry_status,
    description text
)
language sql
security definer
stable
set search_path = public
as $function$

    select

        je.id,

        je.journal_number,

        je.reference_type,

        dt.name,

        je.reference_number,

        je.entry_date,

        je.status,

        je.description

    from public.journal_entries je

    left join public.document_types dt
        on dt.code = je.reference_type

    where je.company_id = p_company_id

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
                dt.name,
                ''
             ) ilike
              '%' || trim(p_search) || '%'

          or coalesce(
                je.description,
                ''
             ) ilike
              '%' || trim(p_search) || '%'
      )

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
-- 12. COMMENTS
-- ============================================================

comment on column public.journal_entries.reference_type
is
    'Universal document type code from document_types, such as INV, PO, B, JV or GRN.';


comment on column public.journal_entries.reference_number
is
    'Human-readable number of the related source document.';


comment on column public.companies.date_format
is
    'Universal date display/entry format used throughout the company workspace.';


comment on column public.companies.time_format
is
    'Universal 12-hour or 24-hour time format.';


comment on column public.companies.number_format
is
    'Universal numeric display format used throughout the company workspace.';


comment on column public.companies.negative_number_format
is
    'Universal negative-number presentation format.';


comment on function public.search_transaction_references(
    uuid,
    text,
    varchar,
    integer
)
is
    'Performs partial search across journal numbers, reference numbers, reference types, document names and descriptions.';


-- ============================================================
-- 13. VALIDATION
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from public.document_types
        where code = 'JV'
          and is_active = true
    ) then

        raise exception
            'JV document type is missing.';

    end if;


    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'companies'
          and column_name = 'time_format'
    ) then

        raise exception
            'Company time_format setting was not created.';

    end if;


    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'companies'
          and column_name = 'number_format'
    ) then

        raise exception
            'Company number_format setting was not created.';

    end if;


    if not exists (
        select 1
        from pg_constraint
        where conname =
            'journal_entries_reference_type_fkey'
          and conrelid =
            'public.journal_entries'::regclass
    ) then

        raise exception
            'Journal reference type foreign key was not created.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 030
-- ============================================================
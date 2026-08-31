-- ============================================================
-- ELVARIS ERP
-- Migration 026
-- Universal Numbering and Reference Settings
-- ============================================================
--
-- Purpose:
--   Establish one universal numbering engine for all document
--   types across Elvaris.
--
-- Examples:
--
--   JV-0001
--   JV-2026-0001
--   PO-0001
--   PO-2026-0001
--   B-0001
--   INV-0001
--   INV-2026-0001
--   OR-0001
--   PV-0001
--   GRN-0001
--   MO-0001
--
-- The format is configurable per company and document type.
--
-- The accounting system will use the same engine as inventory,
-- sales, purchasing, manufacturing and other modules.
--
-- ============================================================


-- ============================================================
-- 1. NUMBERING PROFILE TABLE
-- ============================================================

create table if not exists public.numbering_profiles (

    id uuid primary key
        default gen_random_uuid(),

    company_id uuid not null
        references public.companies(id)
        on delete restrict,

    document_type varchar(50) not null,

    document_name varchar(100) not null,

    prefix varchar(20) not null,

    separator varchar(5) not null default '-',

    include_year boolean not null default false,

    year_format varchar(20) not null default 'YYYY',

    number_padding smallint not null default 4,

    next_number bigint not null default 1,

    branch_specific boolean not null default false,

    fiscal_year_specific boolean not null default false,

    active boolean not null default true,

    created_at timestamptz not null default now(),

    created_by uuid,

    updated_at timestamptz not null default now(),

    updated_by uuid,

    constraint numbering_profiles_padding_check
        check (
            number_padding between 1 and 12
        ),

    constraint numbering_profiles_next_number_check
        check (
            next_number >= 1
        ),

    constraint numbering_profiles_prefix_check
        check (
            length(trim(prefix)) > 0
        ),

    constraint numbering_profiles_year_format_check
        check (
            year_format in (
                'YY',
                'YYYY'
            )
        )

);


-- ============================================================
-- 2. UNIQUE PROFILE
-- ============================================================

create unique index if not exists
ux_numbering_profiles_company_document
on public.numbering_profiles (
    company_id,
    document_type
);


-- ============================================================
-- 3. SEARCH / FILTER INDEXES
-- ============================================================

create index if not exists
idx_numbering_profiles_company_active
on public.numbering_profiles (
    company_id,
    active
);


create index if not exists
idx_numbering_profiles_document_type
on public.numbering_profiles (
    document_type
);


-- ============================================================
-- 4. REFERENCE NUMBER ON JOURNAL ENTRY
-- ============================================================
--
-- journal_number remains the accounting entry identifier.
--
-- reference_type / reference_number identify the originating
-- or related business document.
--
-- Example:
--
-- journal_number    = JV-0001
-- reference_type    = invoice
-- reference_number  = INV-0001
--
-- ============================================================

alter table public.journal_entries
add column if not exists
    reference_type varchar(50);

alter table public.journal_entries
add column if not exists
    reference_number varchar(80);


create index if not exists
idx_journal_entries_reference
on public.journal_entries (
    company_id,
    reference_type,
    reference_number
);


-- ============================================================
-- 5. DOCUMENT TYPE CATALOGUE
-- ============================================================
--
-- One common vocabulary for the entire ERP.
-- ============================================================

create table if not exists public.document_types (

    code varchar(50) primary key,

    name varchar(100) not null,

    module varchar(50) not null,

    description text,

    is_active boolean not null default true,

    display_order integer not null default 0

);


insert into public.document_types (
    code,
    name,
    module,
    description,
    display_order
)
values

(
    'JV',
    'Journal Voucher',
    'finance',
    'General journal voucher.',
    10
),

(
    'INV',
    'Sales Invoice',
    'sales',
    'Customer sales invoice.',
    20
),

(
    'SO',
    'Sales Order',
    'sales',
    'Customer sales order.',
    30
),

(
    'OR',
    'Customer Receipt',
    'finance',
    'Receipt from customer or other party.',
    40
),

(
    'PO',
    'Purchase Order',
    'purchasing',
    'Purchase order issued to vendor.',
    50
),

(
    'B',
    'Vendor Bill',
    'purchasing',
    'Vendor bill / purchase invoice.',
    60
),

(
    'PV',
    'Payment Voucher',
    'finance',
    'Payment made to vendor or other party.',
    70
),

(
    'GRN',
    'Goods Receipt Note',
    'inventory',
    'Receipt of goods into inventory.',
    80
),

(
    'ISS',
    'Stock Issue',
    'inventory',
    'Issue of inventory.',
    90
),

(
    'RET',
    'Stock Return',
    'inventory',
    'Return of inventory.',
    100
),

(
    'ADJ',
    'Stock Adjustment',
    'inventory',
    'Inventory adjustment transaction.',
    110
),

(
    'MO',
    'Manufacturing Order',
    'manufacturing',
    'Manufacturing / production order.',
    120
),

(
    'WO',
    'Work Order',
    'manufacturing',
    'Manufacturing work order.',
    130
),

(
    'PAY',
    'Payroll',
    'hr',
    'Payroll transaction.',
    140
),

(
    'FA',
    'Fixed Asset',
    'assets',
    'Fixed asset transaction.',
    150
),

(
    'BR',
    'Bank Reconciliation',
    'finance',
    'Bank reconciliation reference.',
    160
)

on conflict (code)
do update
set
    name = excluded.name,
    module = excluded.module,
    description = excluded.description,
    display_order = excluded.display_order;


-- ============================================================
-- 6. CREATE DEFAULT NUMBERING PROFILES
-- ============================================================

insert into public.numbering_profiles (
    company_id,
    document_type,
    document_name,
    prefix,
    separator,
    include_year,
    year_format,
    number_padding,
    next_number
)
select
    c.id,
    dt.code,
    dt.name,

    case dt.code

        when 'JV'  then 'JV'
        when 'INV' then 'INV'
        when 'SO'  then 'SO'
        when 'OR'  then 'OR'
        when 'PO'  then 'PO'
        when 'B'   then 'B'
        when 'PV'  then 'PV'
        when 'GRN' then 'GRN'
        when 'ISS' then 'ISS'
        when 'RET' then 'RET'
        when 'ADJ' then 'ADJ'
        when 'MO'  then 'MO'
        when 'WO'  then 'WO'
        when 'PAY' then 'PAY'
        when 'FA'  then 'FA'
        when 'BR'  then 'BR'
        else dt.code

    end,

    '-',

    false,

    'YYYY',

    4,

    1

from public.companies c
cross join public.document_types dt
where c.is_active = true

on conflict (
    company_id,
    document_type
)
do nothing;


-- ============================================================
-- 7. UPDATE EXISTING JOURNAL NUMBERING PROFILE
-- ============================================================
--
-- We tested journal numbers earlier as GJ-2026-000001.
-- The universal system now uses:
--
--     JV-0001
--
-- by default.
--
-- Users may enable the year in Settings later:
--
--     JV-2026-0001
--
-- ============================================================

update public.numbering_profiles
set
    prefix = 'JV',
    separator = '-',
    include_year = false,
    year_format = 'YYYY',
    number_padding = 4,
    updated_at = now()
where document_type = 'JV';


-- ============================================================
-- 8. UNIVERSAL REFERENCE NUMBER GENERATOR
-- ============================================================

create or replace function public.next_reference_number(
    p_company_id uuid,
    p_document_type varchar(50),
    p_reference_date date default current_date
)
returns varchar(100)
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_profile public.numbering_profiles%rowtype;

    v_number bigint;

    v_year text;

    v_result varchar(100);

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


    -- --------------------------------------------------------
    -- Lock profile row for concurrency.
    -- --------------------------------------------------------

    select *
    into v_profile
    from public.numbering_profiles
    where company_id = p_company_id
      and document_type = p_document_type
      and active = true
    for update;


    if not found then

        raise exception
            'No active numbering profile exists for document type "%".',
            p_document_type;

    end if;


    v_number :=
        v_profile.next_number;


    v_year :=
        case v_profile.year_format
            when 'YY' then
                to_char(
                    coalesce(
                        p_reference_date,
                        current_date
                    ),
                    'YY'
                )
            else
                to_char(
                    coalesce(
                        p_reference_date,
                        current_date
                    ),
                    'YYYY'
                )
        end;


    v_result :=
        v_profile.prefix
        || v_profile.separator;


    if v_profile.include_year then

        v_result :=
            v_result
            || v_year
            || v_profile.separator;

    end if;


    v_result :=
        v_result
        || lpad(
            v_number::text,
            v_profile.number_padding,
            '0'
        );


    update public.numbering_profiles
    set
        next_number =
            v_profile.next_number + 1,

        updated_at =
            now(),

        updated_by =
            auth.uid()

    where id = v_profile.id;


    return v_result;

end;
$function$;


-- ============================================================
-- 9. CHANGE NUMBERING PROFILE
-- ============================================================

create or replace function public.update_numbering_profile(
    p_company_id uuid,
    p_document_type varchar(50),
    p_prefix varchar(20),
    p_separator varchar(5) default '-',
    p_include_year boolean default false,
    p_year_format varchar(20) default 'YYYY',
    p_number_padding smallint default 4,
    p_next_number bigint default 1
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_id uuid;

begin

    if not exists (
        select 1
        from public.companies
        where id = p_company_id
          and is_active = true
    ) then

        raise exception
            'Active company does not exist.';

    end if;


    if not exists (
        select 1
        from public.document_types
        where code = p_document_type
    ) then

        raise exception
            'Document type "%" is not registered.',
            p_document_type;

    end if;


    if nullif(trim(p_prefix), '') is null then

        raise exception
            'Reference prefix is required.';

    end if;


    if p_number_padding < 1
       or p_number_padding > 12
    then

        raise exception
            'Number padding must be between 1 and 12.';

    end if;


    if p_next_number < 1 then

        raise exception
            'Next number must be at least 1.';

    end if;


    if p_year_format not in (
        'YY',
        'YYYY'
    ) then

        raise exception
            'Year format must be YY or YYYY.';

    end if;


    insert into public.numbering_profiles (
        company_id,
        document_type,
        document_name,
        prefix,
        separator,
        include_year,
        year_format,
        number_padding,
        next_number,
        active,
        created_at,
        created_by,
        updated_at,
        updated_by
    )
    select
        p_company_id,
        dt.code,
        dt.name,
        trim(p_prefix),
        p_separator,
        p_include_year,
        p_year_format,
        p_number_padding,
        p_next_number,
        true,
        now(),
        auth.uid(),
        now(),
        auth.uid()
    from public.document_types dt
    where dt.code = p_document_type

    on conflict (
        company_id,
        document_type
    )
    do update
    set
        document_name =
            excluded.document_name,

        prefix =
            excluded.prefix,

        separator =
            excluded.separator,

        include_year =
            excluded.include_year,

        year_format =
            excluded.year_format,

        number_padding =
            excluded.number_padding,

        next_number =
            excluded.next_number,

        active =
            true,

        updated_at =
            now(),

        updated_by =
            auth.uid()

    returning id
    into v_id;


    return v_id;

end;
$function$;


-- ============================================================
-- 10. JOURNAL REFERENCE SEARCH
-- ============================================================
--
-- Partial matching:
--
--   JV-00
--   INV-1
--   ABC
--   2026
-- ============================================================

create or replace function public.search_journal_references(
    p_company_id uuid,
    p_search text default null,
    p_limit integer default 50
)
returns table (
    journal_entry_id uuid,
    journal_number varchar(40),
    reference_type varchar(50),
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
        je.reference_number,
        je.entry_date,
        je.status,
        je.description

    from public.journal_entries je

    where je.company_id = p_company_id

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

    order by
        je.entry_date desc,
        je.journal_number desc

    limit greatest(
        least(
            coalesce(p_limit, 50),
            200
        ),
        1
    );

$function$;


-- ============================================================
-- 11. COMMENTS
-- ============================================================

comment on table public.numbering_profiles
is
    'Universal company-level document numbering configuration for Elvaris.';


comment on table public.document_types
is
    'Universal ERP document type catalogue used by numbering and references.';


comment on column public.journal_entries.reference_type
is
    'Document type of the related source/reference document.';


comment on column public.journal_entries.reference_number
is
    'Human-readable source/reference number associated with the journal entry.';


comment on function public.next_reference_number(
    uuid,
    varchar,
    date
)
is
    'Atomically generates the next configured reference number for a company and document type.';


comment on function public.update_numbering_profile(
    uuid,
    varchar,
    varchar,
    varchar,
    boolean,
    varchar,
    smallint,
    bigint
)
is
    'Creates or updates universal document numbering settings for a company.';


comment on function public.search_journal_references(
    uuid,
    text,
    integer
)
is
    'Searches journal and reference numbers using partial text matching.';


-- ============================================================
-- 12. VALIDATION
-- ============================================================

do $$
declare

    v_company_count integer;

    v_profile_count integer;

begin

    select count(*)
    into v_company_count
    from public.companies
    where is_active = true;


    select count(*)
    into v_profile_count
    from public.numbering_profiles np
    join public.companies c
      on c.id = np.company_id
    where c.is_active = true
      and np.active = true;


    if v_company_count = 0 then

        raise exception
            'No active companies exist.';

    end if;


    if v_profile_count <
       v_company_count * (
           select count(*)
           from public.document_types
           where is_active = true
       )
    then

        raise exception
            'Universal numbering profiles are incomplete.';

    end if;


    if not exists (
        select 1
        from public.numbering_profiles
        where document_type = 'JV'
          and prefix = 'JV'
          and number_padding = 4
          and include_year = false
    ) then

        raise exception
            'Default JV numbering profile is not configured correctly.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 026
-- ============================================================
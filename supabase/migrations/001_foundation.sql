-- ============================================================
-- ELVARIS ERP
-- Migration 001: Foundation
--
-- Purpose:
--   Establish the universal/global master data and
--   organization/fiscal foundation for the ERP.
--
-- Important:
--   This migration intentionally does NOT create accounting,
--   inventory, sales, purchasing, or manufacturing transactions.
--   Those depend on this foundation.
-- ============================================================


-- ============================================================
-- 1. EXTENSIONS
-- ============================================================

create extension if not exists pgcrypto;


-- ============================================================
-- 2. ENUM TYPES
-- ============================================================

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'fiscal_year_status'
  ) then
    create type public.fiscal_year_status as enum (
      'open',
      'closed'
    );
  end if;
end
$$;


do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'accounting_period_status'
  ) then
    create type public.accounting_period_status as enum (
      'open',
      'locked',
      'closed'
    );
  end if;
end
$$;


-- ============================================================
-- 3. UNIVERSAL MASTER: CURRENCIES
-- ============================================================

create table if not exists public.currencies (
  id uuid primary key default gen_random_uuid(),

  code varchar(3) not null,
  name text not null,
  symbol text,
  decimal_places smallint not null default 2,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint currencies_code_unique
    unique (code),

  constraint currencies_code_format
    check (char_length(code) = 3),

  constraint currencies_decimal_places_check
    check (
      decimal_places >= 0
      and decimal_places <= 6
    )
);


-- ============================================================
-- 4. UNIVERSAL MASTER: COUNTRIES
-- ============================================================

create table if not exists public.countries (
  id uuid primary key default gen_random_uuid(),

  name text not null,

  iso2_code varchar(2),
  iso3_code varchar(3),
  phone_code varchar(16),

  default_currency_id uuid
    references public.currencies(id)
    on delete restrict,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint countries_name_unique
    unique (name),

  constraint countries_iso2_unique
    unique (iso2_code),

  constraint countries_iso3_unique
    unique (iso3_code),

  constraint countries_iso2_format
    check (
      iso2_code is null
      or char_length(iso2_code) = 2
    ),

  constraint countries_iso3_format
    check (
      iso3_code is null
      or char_length(iso3_code) = 3
    )
);


-- ============================================================
-- 5. UNIVERSAL MASTER: TIME ZONES
-- ============================================================

create table if not exists public.time_zones (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  utc_offset text,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint time_zones_name_unique
    unique (name)
);


-- ============================================================
-- 6. UNIVERSAL MASTER: LANGUAGES
-- ============================================================

create table if not exists public.languages (
  id uuid primary key default gen_random_uuid(),

  code varchar(10) not null,
  name text not null,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint languages_code_unique
    unique (code)
);


-- ============================================================
-- 7. UNIVERSAL MASTER: UNITS OF MEASURE
-- ============================================================

create table if not exists public.units_of_measure (
  id uuid primary key default gen_random_uuid(),

  code varchar(30) not null,
  name text not null,
  abbreviation varchar(20),

  uom_type varchar(30) not null default 'quantity',

  conversion_factor numeric(18,6) not null default 1,

  base_uom_id uuid
    references public.units_of_measure(id)
    on delete restrict,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint units_of_measure_code_unique
    unique (code),

  constraint units_of_measure_conversion_check
    check (
      conversion_factor > 0
    )
);


-- ============================================================
-- 8. UNIVERSAL MASTER: PAYMENT TERMS
-- ============================================================

create table if not exists public.payment_terms (
  id uuid primary key default gen_random_uuid(),

  code varchar(30) not null,
  name text not null,

  days_due integer not null default 0,

  description text,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint payment_terms_code_unique
    unique (code),

  constraint payment_terms_days_due_check
    check (
      days_due >= 0
    )
);


-- ============================================================
-- 9. UNIVERSAL MASTER: TAX JURISDICTIONS
-- ============================================================

create table if not exists public.tax_jurisdictions (
  id uuid primary key default gen_random_uuid(),

  country_id uuid not null
    references public.countries(id)
    on delete restrict,

  name text not null,
  code varchar(30) not null,

  description text,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tax_jurisdictions_unique
    unique (
      country_id,
      code
    )
);


-- ============================================================
-- 10. UNIVERSAL MASTER: TAX CODES
-- ============================================================

create table if not exists public.tax_codes (
  id uuid primary key default gen_random_uuid(),

  jurisdiction_id uuid not null
    references public.tax_jurisdictions(id)
    on delete restrict,

  code varchar(30) not null,
  name text not null,

  rate numeric(12,6) not null default 0,

  tax_type varchar(30) not null default 'percentage',

  is_sales_tax boolean not null default false,
  is_purchase_tax boolean not null default false,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tax_codes_unique
    unique (
      jurisdiction_id,
      code
    ),

  constraint tax_codes_rate_check
    check (
      rate >= 0
    )
);


-- ============================================================
-- 11. ORGANIZATION: COMPANIES
-- ============================================================

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),

  company_code varchar(30) not null,

  legal_name text not null,
  display_name text,

  registration_number text,
  tax_registration_number text,

  email text,
  phone text,
  website text,

  address_line_1 text,
  address_line_2 text,

  city text,
  state text,
  postal_code text,

  country_id uuid
    references public.countries(id)
    on delete restrict,

  base_currency_id uuid not null
    references public.currencies(id)
    on delete restrict,

  time_zone_id uuid
    references public.time_zones(id)
    on delete restrict,

  date_format varchar(30)
    not null
    default 'YYYY-MM-DD',

  decimal_places smallint not null default 2,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  created_by uuid,

  updated_at timestamptz not null default now(),
  updated_by uuid,

  constraint companies_code_unique
    unique (company_code),

  constraint companies_decimal_places_check
    check (
      decimal_places >= 0
      and decimal_places <= 6
    )
);


-- ============================================================
-- 12. ORGANIZATION: BRANCHES
-- ============================================================

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),

  company_id uuid not null
    references public.companies(id)
    on delete cascade,

  branch_code varchar(30) not null,
  name text not null,

  address_line_1 text,
  address_line_2 text,

  city text,
  state text,
  postal_code text,

  country_id uuid
    references public.countries(id)
    on delete restrict,

  phone text,
  email text,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  created_by uuid,

  updated_at timestamptz not null default now(),
  updated_by uuid,

  constraint branches_company_code_unique
    unique (
      company_id,
      branch_code
    )
);


-- ============================================================
-- 13. ORGANIZATION: DEPARTMENTS
-- ============================================================

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),

  company_id uuid not null
    references public.companies(id)
    on delete cascade,

  branch_id uuid
    references public.branches(id)
    on delete restrict,

  code varchar(30) not null,
  name text not null,

  description text,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  created_by uuid,

  updated_at timestamptz not null default now(),
  updated_by uuid,

  constraint departments_company_code_unique
    unique (
      company_id,
      code
    )
);


-- ============================================================
-- 14. FISCAL YEARS
-- ============================================================

create table if not exists public.fiscal_years (
  id uuid primary key default gen_random_uuid(),

  company_id uuid not null
    references public.companies(id)
    on delete cascade,

  name varchar(30) not null,

  start_date date not null,
  end_date date not null,

  is_current boolean not null default false,

  status public.fiscal_year_status
    not null
    default 'open',

  created_at timestamptz not null default now(),
  created_by uuid,

  updated_at timestamptz not null default now(),
  updated_by uuid,

  constraint fiscal_years_date_check
    check (
      start_date < end_date
    ),

  constraint fiscal_years_company_name_unique
    unique (
      company_id,
      name
    )
);


-- ============================================================
-- 15. ACCOUNTING PERIODS
-- ============================================================

create table if not exists public.accounting_periods (
  id uuid primary key default gen_random_uuid(),

  fiscal_year_id uuid not null
    references public.fiscal_years(id)
    on delete cascade,

  period_number smallint not null,

  name varchar(50) not null,

  start_date date not null,
  end_date date not null,

  status public.accounting_period_status
    not null
    default 'open',

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint accounting_periods_date_check
    check (
      start_date <= end_date
    ),

  constraint accounting_periods_number_check
    check (
      period_number > 0
    ),

  constraint accounting_periods_unique
    unique (
      fiscal_year_id,
      period_number
    )
);


-- ============================================================
-- 16. INDEXES
-- ============================================================

create index if not exists idx_countries_default_currency
  on public.countries(default_currency_id);

create index if not exists idx_tax_jurisdictions_country
  on public.tax_jurisdictions(country_id);

create index if not exists idx_tax_codes_jurisdiction
  on public.tax_codes(jurisdiction_id);

create index if not exists idx_companies_country
  on public.companies(country_id);

create index if not exists idx_companies_currency
  on public.companies(base_currency_id);

create index if not exists idx_companies_time_zone
  on public.companies(time_zone_id);

create index if not exists idx_branches_company
  on public.branches(company_id);

create index if not exists idx_branches_country
  on public.branches(country_id);

create index if not exists idx_departments_company
  on public.departments(company_id);

create index if not exists idx_departments_branch
  on public.departments(branch_id);

create index if not exists idx_fiscal_years_company
  on public.fiscal_years(company_id);

create index if not exists idx_fiscal_years_dates
  on public.fiscal_years(
    company_id,
    start_date,
    end_date
  );

create index if not exists idx_accounting_periods_fiscal_year
  on public.accounting_periods(fiscal_year_id);

create index if not exists idx_accounting_periods_dates
  on public.accounting_periods(
    start_date,
    end_date
  );


-- ============================================================
-- 17. UPDATED_AT TRIGGER FUNCTION
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ============================================================
-- 18. UPDATED_AT TRIGGERS
-- ============================================================

drop trigger if exists currencies_set_updated_at
  on public.currencies;

create trigger currencies_set_updated_at
before update on public.currencies
for each row
execute function public.set_updated_at();


drop trigger if exists countries_set_updated_at
  on public.countries;

create trigger countries_set_updated_at
before update on public.countries
for each row
execute function public.set_updated_at();


drop trigger if exists time_zones_set_updated_at
  on public.time_zones;

create trigger time_zones_set_updated_at
before update on public.time_zones
for each row
execute function public.set_updated_at();


drop trigger if exists languages_set_updated_at
  on public.languages;

create trigger languages_set_updated_at
before update on public.languages
for each row
execute function public.set_updated_at();


drop trigger if exists units_of_measure_set_updated_at
  on public.units_of_measure;

create trigger units_of_measure_set_updated_at
before update on public.units_of_measure
for each row
execute function public.set_updated_at();


drop trigger if exists payment_terms_set_updated_at
  on public.payment_terms;

create trigger payment_terms_set_updated_at
before update on public.payment_terms
for each row
execute function public.set_updated_at();


drop trigger if exists tax_jurisdictions_set_updated_at
  on public.tax_jurisdictions;

create trigger tax_jurisdictions_set_updated_at
before update on public.tax_jurisdictions
for each row
execute function public.set_updated_at();


drop trigger if exists tax_codes_set_updated_at
  on public.tax_codes;

create trigger tax_codes_set_updated_at
before update on public.tax_codes
for each row
execute function public.set_updated_at();


drop trigger if exists companies_set_updated_at
  on public.companies;

create trigger companies_set_updated_at
before update on public.companies
for each row
execute function public.set_updated_at();


drop trigger if exists branches_set_updated_at
  on public.branches;

create trigger branches_set_updated_at
before update on public.branches
for each row
execute function public.set_updated_at();


drop trigger if exists departments_set_updated_at
  on public.departments;

create trigger departments_set_updated_at
before update on public.departments
for each row
execute function public.set_updated_at();


drop trigger if exists fiscal_years_set_updated_at
  on public.fiscal_years;

create trigger fiscal_years_set_updated_at
before update on public.fiscal_years
for each row
execute function public.set_updated_at();


drop trigger if exists accounting_periods_set_updated_at
  on public.accounting_periods;

create trigger accounting_periods_set_updated_at
before update on public.accounting_periods
for each row
execute function public.set_updated_at();


-- ============================================================
-- 19. ROW LEVEL SECURITY
--
-- We enable RLS now as a security baseline.
--
-- Policies will be added in the security/auth migration
-- after user/company/branch access tables exist.
-- ============================================================

alter table public.currencies enable row level security;
alter table public.countries enable row level security;
alter table public.time_zones enable row level security;
alter table public.languages enable row level security;
alter table public.units_of_measure enable row level security;
alter table public.payment_terms enable row level security;
alter table public.tax_jurisdictions enable row level security;
alter table public.tax_codes enable row level security;

alter table public.companies enable row level security;
alter table public.branches enable row level security;
alter table public.departments enable row level security;

alter table public.fiscal_years enable row level security;
alter table public.accounting_periods enable row level security;


-- ============================================================
-- 20. COMMENTS
-- ============================================================

comment on table public.currencies is
  'Universal currency master used throughout Elvaris.';

comment on table public.countries is
  'Universal country master used throughout Elvaris.';

comment on table public.time_zones is
  'Universal time-zone master.';

comment on table public.languages is
  'Universal language master.';

comment on table public.units_of_measure is
  'Universal unit-of-measure master including conversion support.';

comment on table public.payment_terms is
  'Universal payment-term master.';

comment on table public.tax_jurisdictions is
  'Tax jurisdiction master associated with countries.';

comment on table public.tax_codes is
  'Tax code master used for tax calculation and posting.';

comment on table public.companies is
  'Top-level business organization in Elvaris.';

comment on table public.branches is
  'Operating branches belonging to a company.';

comment on table public.departments is
  'Departments belonging to companies and optionally branches.';

comment on table public.fiscal_years is
  'Fiscal years belonging to a company.';

comment on table public.accounting_periods is
  'Accounting periods belonging to fiscal years.';
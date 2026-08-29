-- ============================================================
-- ELVARIS ERP
-- Migration 002: Global Code Refinement
--
-- Adds ISO numeric identifiers to universal masters.
--
-- Country:
--   ISO 3166 numeric code
--
-- Currency:
--   ISO 4217 numeric code
--
-- Important:
--   Currency numeric codes are stored for interoperability,
--   but are NOT enforced as globally unique.
--   The ISO alphabetic currency code remains the unique
--   business identifier in the currencies table.
-- ============================================================


-- ============================================================
-- 1. CURRENCY NUMERIC CODE
-- ============================================================

alter table public.currencies
add column if not exists numeric_code varchar(3);


-- ============================================================
-- 2. COUNTRY NUMERIC CODE
-- ============================================================

alter table public.countries
add column if not exists numeric_code varchar(3);


-- ============================================================
-- 3. VALIDATION
-- ============================================================

alter table public.currencies
drop constraint if exists currencies_numeric_code_format;

alter table public.currencies
add constraint currencies_numeric_code_format
check (
  numeric_code is null
  or numeric_code ~ '^[0-9]{3}$'
);


alter table public.countries
drop constraint if exists countries_numeric_code_format;

alter table public.countries
add constraint countries_numeric_code_format
check (
  numeric_code is null
  or numeric_code ~ '^[0-9]{3}$'
);


-- ============================================================
-- 4. COUNTRY NUMERIC CODE INDEX
--
-- Country ISO numeric codes are unique within ISO 3166.
-- Keep this constraint for country interoperability.
-- ============================================================

create unique index if not exists
idx_countries_numeric_code_unique
on public.countries(numeric_code)
where numeric_code is not null;


-- ============================================================
-- 5. COMMENTS
-- ============================================================

comment on column public.currencies.numeric_code is
  'ISO 4217 three-digit numeric currency code. Stored for interoperability; currency code remains the unique identifier.';


comment on column public.countries.numeric_code is
  'ISO 3166 three-digit numeric country code.';
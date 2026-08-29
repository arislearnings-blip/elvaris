-- ============================================================
-- ELVARIS ERP
-- Migration 010: Global Master Read Policies
--
-- Purpose:
--   Allow authenticated Elvaris users to READ universal
--   master data needed throughout the application.
--
-- These are reference/master tables, not tenant-owned
-- transaction tables.
--
-- Write permissions remain restricted and will be handled
-- through controlled application permissions/functions.
-- ============================================================


-- ============================================================
-- 1. GRANTS
-- ============================================================

revoke all
on table
  public.currencies,
  public.countries,
  public.time_zones,
  public.languages,
  public.units_of_measure,
  public.payment_terms,
  public.tax_jurisdictions,
  public.tax_codes
from anon, authenticated;


grant select
on table
  public.currencies,
  public.countries,
  public.time_zones,
  public.languages,
  public.units_of_measure,
  public.payment_terms,
  public.tax_jurisdictions,
  public.tax_codes
to authenticated;


-- ============================================================
-- 2. CURRENCIES
-- ============================================================

drop policy if exists
"authenticated_users_can_read_active_currencies"
on public.currencies;

create policy
"authenticated_users_can_read_active_currencies"
on public.currencies
for select
to authenticated
using (
  is_active = true
);


-- ============================================================
-- 3. COUNTRIES
-- ============================================================

drop policy if exists
"authenticated_users_can_read_active_countries"
on public.countries;

create policy
"authenticated_users_can_read_active_countries"
on public.countries
for select
to authenticated
using (
  is_active = true
);


-- ============================================================
-- 4. TIME ZONES
-- ============================================================

drop policy if exists
"authenticated_users_can_read_active_time_zones"
on public.time_zones;

create policy
"authenticated_users_can_read_active_time_zones"
on public.time_zones
for select
to authenticated
using (
  is_active = true
);


-- ============================================================
-- 5. LANGUAGES
-- ============================================================

drop policy if exists
"authenticated_users_can_read_active_languages"
on public.languages;

create policy
"authenticated_users_can_read_active_languages"
on public.languages
for select
to authenticated
using (
  is_active = true
);


-- ============================================================
-- 6. UNITS OF MEASURE
-- ============================================================

drop policy if exists
"authenticated_users_can_read_active_uom"
on public.units_of_measure;

create policy
"authenticated_users_can_read_active_uom"
on public.units_of_measure
for select
to authenticated
using (
  is_active = true
);


-- ============================================================
-- 7. PAYMENT TERMS
-- ============================================================

drop policy if exists
"authenticated_users_can_read_active_payment_terms"
on public.payment_terms;

create policy
"authenticated_users_can_read_active_payment_terms"
on public.payment_terms
for select
to authenticated
using (
  is_active = true
);


-- ============================================================
-- 8. TAX JURISDICTIONS
-- ============================================================

drop policy if exists
"authenticated_users_can_read_active_tax_jurisdictions"
on public.tax_jurisdictions;

create policy
"authenticated_users_can_read_active_tax_jurisdictions"
on public.tax_jurisdictions
for select
to authenticated
using (
  is_active = true
);


-- ============================================================
-- 9. TAX CODES
-- ============================================================

drop policy if exists
"authenticated_users_can_read_active_tax_codes"
on public.tax_codes;

create policy
"authenticated_users_can_read_active_tax_codes"
on public.tax_codes
for select
to authenticated
using (
  is_active = true
);
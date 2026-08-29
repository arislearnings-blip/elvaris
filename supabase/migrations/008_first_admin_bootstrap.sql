-- ============================================================
-- ELVARIS ERP
-- Migration 008: First Administrator Bootstrap
--
-- Purpose:
--   Allow the FIRST authenticated Elvaris user to establish
--   the initial company, branch, administrator role and access.
--
-- Security rules:
--
--   1. User must be authenticated.
--   2. User must have an Elvaris profile.
--   3. No company may already exist.
--   4. The function can only succeed once.
--   5. The calling user becomes SYSTEM_ADMIN.
--   6. The calling user receives access to the new company
--      and branch.
--
-- Important:
--   PostgreSQL does not permit CREATE OR REPLACE FUNCTION to
--   change an existing function's OUT/RETURNS TABLE structure.
--   Therefore the old function is dropped before recreation.
-- ============================================================


-- ============================================================
-- 1. DROP PREVIOUS FUNCTION VERSION
-- ============================================================

drop function if exists public.bootstrap_first_company(
  varchar,
  text,
  text,
  uuid,
  uuid,
  uuid,
  varchar,
  text
);


-- ============================================================
-- 2. CREATE FIRST ADMINISTRATOR BOOTSTRAP
-- ============================================================

create function public.bootstrap_first_company(
  p_company_code varchar(30),
  p_legal_name text,
  p_display_name text,
  p_country_id uuid,
  p_base_currency_id uuid,
  p_time_zone_id uuid,
  p_branch_code varchar(30),
  p_branch_name text
)
returns table (
  result_company_id uuid,
  result_branch_id uuid,
  result_user_profile_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_user_id uuid;
  v_user_profile_id uuid;
  v_company_id uuid;
  v_branch_id uuid;
  v_system_admin_role_id uuid;
begin

  -- ==========================================================
  -- 1. AUTHENTICATION
  -- ==========================================================

  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception
      'Authentication required.';
  end if;


  -- ==========================================================
  -- 2. GET / CREATE ELVARIS USER PROFILE
  -- ==========================================================

  v_user_profile_id :=
    public.ensure_current_user_profile();


  if v_user_profile_id is null then
    raise exception
      'Elvaris user profile could not be initialized.';
  end if;


  -- ==========================================================
  -- 3. FIRST-SETUP CONDITION
  -- ==========================================================

  if exists (
    select 1
    from public.companies
    limit 1
  ) then
    raise exception
      'Initial setup has already been completed.';
  end if;


  -- ==========================================================
  -- 4. VALIDATE REQUIRED VALUES
  -- ==========================================================

  if nullif(trim(p_company_code), '') is null then
    raise exception
      'Company code is required.';
  end if;


  if nullif(trim(p_legal_name), '') is null then
    raise exception
      'Legal company name is required.';
  end if;


  if nullif(trim(p_branch_code), '') is null then
    raise exception
      'Branch code is required.';
  end if;


  if nullif(trim(p_branch_name), '') is null then
    raise exception
      'Branch name is required.';
  end if;


  if p_base_currency_id is null then
    raise exception
      'Base currency is required.';
  end if;


  -- ==========================================================
  -- 5. VALIDATE CURRENCY
  -- ==========================================================

  if not exists (
    select 1
    from public.currencies
    where id = p_base_currency_id
      and is_active = true
  ) then
    raise exception
      'Selected currency does not exist or is inactive.';
  end if;


  -- ==========================================================
  -- 6. VALIDATE COUNTRY
  -- ==========================================================

  if p_country_id is not null then

    if not exists (
      select 1
      from public.countries
      where id = p_country_id
        and is_active = true
    ) then
      raise exception
        'Selected country does not exist or is inactive.';
    end if;

  end if;


  -- ==========================================================
  -- 7. VALIDATE TIME ZONE
  -- ==========================================================

  if p_time_zone_id is not null then

    if not exists (
      select 1
      from public.time_zones
      where id = p_time_zone_id
        and is_active = true
    ) then
      raise exception
        'Selected time zone does not exist or is inactive.';
    end if;

  end if;


  -- ==========================================================
  -- 8. CREATE COMPANY
  -- ==========================================================

  insert into public.companies (
    company_code,
    legal_name,
    display_name,
    country_id,
    base_currency_id,
    time_zone_id,
    created_by,
    updated_by
  )
  values (
    upper(trim(p_company_code)),
    trim(p_legal_name),
    nullif(
      trim(p_display_name),
      ''
    ),
    p_country_id,
    p_base_currency_id,
    p_time_zone_id,
    v_user_profile_id,
    v_user_profile_id
  )
  returning id
  into v_company_id;


  -- ==========================================================
  -- 9. CREATE FIRST BRANCH
  -- ==========================================================

  insert into public.branches (
    company_id,
    branch_code,
    name,
    country_id,
    created_by,
    updated_by
  )
  values (
    v_company_id,
    upper(trim(p_branch_code)),
    trim(p_branch_name),
    p_country_id,
    v_user_profile_id,
    v_user_profile_id
  )
  returning id
  into v_branch_id;


  -- ==========================================================
  -- 10. GET SYSTEM ADMIN ROLE
  -- ==========================================================

  select r.id
  into v_system_admin_role_id
  from public.roles as r
  where r.code = 'SYSTEM_ADMIN'
    and r.is_active = true
  limit 1;


  if v_system_admin_role_id is null then
    raise exception
      'SYSTEM_ADMIN role does not exist.';
  end if;


  -- ==========================================================
  -- 11. ASSIGN SYSTEM ADMIN ROLE
  -- ==========================================================

  insert into public.user_roles (
    user_id,
    role_id
  )
  values (
    v_user_profile_id,
    v_system_admin_role_id
  )
  on conflict (
    user_id,
    role_id
  )
  do nothing;


  -- ==========================================================
  -- 12. ASSIGN COMPANY ACCESS
  -- ==========================================================

  insert into public.user_company_access (
    user_id,
    company_id,
    is_default
  )
  values (
    v_user_profile_id,
    v_company_id,
    true
  )
  on conflict (
    user_id,
    company_id
  )
  do update set
    is_default = true;


  -- ==========================================================
  -- 13. ASSIGN BRANCH ACCESS
  -- ==========================================================

  insert into public.user_branch_access (
    user_id,
    branch_id,
    is_default
  )
  values (
    v_user_profile_id,
    v_branch_id,
    true
  )
  on conflict (
    user_id,
    branch_id
  )
  do update set
    is_default = true;


  -- ==========================================================
  -- 14. RETURN CREATED RECORDS
  -- ==========================================================

  return query
  select
    v_company_id,
    v_branch_id,
    v_user_profile_id;

end;
$$;


-- ============================================================
-- 15. DOCUMENTATION
-- ============================================================

comment on function public.bootstrap_first_company(
  varchar,
  text,
  text,
  uuid,
  uuid,
  uuid,
  varchar,
  text
)
is
  'One-time bootstrap for the first authenticated Elvaris administrator, company and branch.';


-- ============================================================
-- 16. EXECUTION PERMISSION
-- ============================================================

revoke all
on function public.bootstrap_first_company(
  varchar,
  text,
  text,
  uuid,
  uuid,
  uuid,
  varchar,
  text
)
from public;


grant execute
on function public.bootstrap_first_company(
  varchar,
  text,
  text,
  uuid,
  uuid,
  uuid,
  varchar,
  text
)
to authenticated;
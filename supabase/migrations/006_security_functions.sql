-- ============================================================
-- ELVARIS ERP
-- Migration 006: Security Helper Functions
--
-- Purpose:
--   Provide reusable PostgreSQL functions for:
--
--   1. Resolving the authenticated Elvaris user
--   2. Checking company access
--   3. Checking branch access
--   4. Checking permissions
--
-- These functions are used by the RLS policies.
-- ============================================================


-- ============================================================
-- 1. CURRENT ELVARIS USER
-- ============================================================
--
-- Returns the Elvaris user profile corresponding to
-- auth.uid().
-- ============================================================

create or replace function public.current_elvaris_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select up.id
  from public.user_profiles up
  where up.auth_user_id = auth.uid()
    and up.is_active = true
  limit 1;
$$;


-- ============================================================
-- 2. COMPANY ACCESS
-- ============================================================

create or replace function public.has_company_access(
  p_company_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_company_access uca
    join public.user_profiles up
      on up.id = uca.user_id
    where up.auth_user_id = auth.uid()
      and up.is_active = true
      and uca.company_id = p_company_id
  );
$$;


-- ============================================================
-- 3. BRANCH ACCESS
-- ============================================================

create or replace function public.has_branch_access(
  p_branch_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_branch_access uba
    join public.user_profiles up
      on up.id = uba.user_id
    where up.auth_user_id = auth.uid()
      and up.is_active = true
      and uba.branch_id = p_branch_id
  );
$$;


-- ============================================================
-- 4. PERMISSION CHECK
-- ============================================================
--
-- Returns true when the authenticated user has at least
-- one active role containing the requested active permission.
-- ============================================================

create or replace function public.has_permission(
  p_permission_code text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_profiles up

    join public.user_roles ur
      on ur.user_id = up.id

    join public.roles r
      on r.id = ur.role_id
     and r.is_active = true

    join public.role_permissions rp
      on rp.role_id = r.id

    join public.permissions p
      on p.id = rp.permission_id
     and p.is_active = true

    where up.auth_user_id = auth.uid()
      and up.is_active = true
      and p.code = p_permission_code
  );
$$;


-- ============================================================
-- 5. SYSTEM ADMIN CHECK
-- ============================================================

create or replace function public.is_system_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_profiles up

    join public.user_roles ur
      on ur.user_id = up.id

    join public.roles r
      on r.id = ur.role_id

    where up.auth_user_id = auth.uid()
      and up.is_active = true
      and r.code = 'SYSTEM_ADMIN'
      and r.is_active = true
  );
$$;


-- ============================================================
-- 6. DEFAULT COMPANY
-- ============================================================

create or replace function public.default_company_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select uca.company_id
  from public.user_company_access uca

  join public.user_profiles up
    on up.id = uca.user_id

  where up.auth_user_id = auth.uid()
    and up.is_active = true
    and uca.is_default = true

  order by uca.created_at
  limit 1;
$$;


-- ============================================================
-- 7. DEFAULT BRANCH
-- ============================================================

create or replace function public.default_branch_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select uba.branch_id
  from public.user_branch_access uba

  join public.user_profiles up
    on up.id = uba.user_id

  where up.auth_user_id = auth.uid()
    and up.is_active = true
    and uba.is_default = true

  order by uba.created_at
  limit 1;
$$;


-- ============================================================
-- 8. FUNCTION DOCUMENTATION
-- ============================================================

comment on function public.current_elvaris_user_id()
is
  'Returns the active Elvaris user profile for auth.uid().';


comment on function public.has_company_access(uuid)
is
  'Returns true when auth.uid() has access to the specified company.';


comment on function public.has_branch_access(uuid)
is
  'Returns true when auth.uid() has access to the specified branch.';


comment on function public.has_permission(text)
is
  'Returns true when auth.uid() has an active role containing the specified permission.';


comment on function public.is_system_admin()
is
  'Returns true when auth.uid() has the SYSTEM_ADMIN role.';


comment on function public.default_company_id()
is
  'Returns the default company assigned to auth.uid().';


comment on function public.default_branch_id()
is
  'Returns the default branch assigned to auth.uid().';
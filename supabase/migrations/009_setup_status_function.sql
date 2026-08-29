-- ============================================================
-- ELVARIS ERP
-- Migration 009: Initial Setup Status Function
--
-- Purpose:
--   Allow the authenticated application to determine whether
--   the first company has been created without exposing the
--   companies table directly through RLS.
--
-- Returns:
--   true  = initial setup is required
--   false = at least one company exists
-- ============================================================


create or replace function public.is_initial_setup_required()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.companies
    limit 1
  );
$$;


-- ============================================================
-- Documentation
-- ============================================================

comment on function public.is_initial_setup_required()
is
  'Returns true when the Elvaris environment has no company and initial setup is required.';


-- ============================================================
-- Permissions
-- ============================================================

revoke all
on function public.is_initial_setup_required()
from public;


grant execute
on function public.is_initial_setup_required()
to authenticated;
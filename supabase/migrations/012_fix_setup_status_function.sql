-- ============================================================
-- ELVARIS ERP
-- Migration 012: Fix Initial Setup Status
--
-- Purpose:
--   Make the initial-setup status check independent of normal
--   tenant RLS policies.
--
-- The function is only used to answer:
--
--   "Does any company exist yet?"
--
-- It does not expose company data to the browser.
-- ============================================================


create or replace function public.is_initial_setup_required()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_company_exists boolean;
begin

  /*
   * The setup-status check is a system-level operation.
   *
   * It deliberately bypasses normal row-security evaluation
   * for this single existence check.
   */
  perform set_config(
    'row_security',
    'off',
    true
  );


  select exists (
    select 1
    from public.companies
    limit 1
  )
  into v_company_exists;


  return not v_company_exists;

end;
$$;


-- ============================================================
-- Permissions
-- ============================================================

revoke all
on function public.is_initial_setup_required()
from public;


grant execute
on function public.is_initial_setup_required()
to authenticated;


-- ============================================================
-- Documentation
-- ============================================================

comment on function public.is_initial_setup_required()
is
  'Returns true only when the Elvaris database contains no company. Performs a system-level existence check independent of tenant RLS.';
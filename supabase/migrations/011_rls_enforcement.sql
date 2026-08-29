-- ============================================================
-- ELVARIS ERP
-- Migration 011: RLS Enforcement
--
-- Purpose:
--   Enforce company, branch, role and permission access at the
--   PostgreSQL Row Level Security layer.
--
-- Important:
--   RLS is the final database security boundary.
--
-- Security model:
--
--   Authentication
--       ↓
--   Elvaris User Profile
--       ↓
--   Role
--       ↓
--   Permission
--       ↓
--   Company Access
--       ↓
--   Branch Access
--       ↓
--   Database Record
-- ============================================================


-- ============================================================
-- 1. BASIC TABLE GRANTS
-- ============================================================
--
-- RLS still controls which rows are accessible.
-- Grants determine which operations the authenticated
-- API role may attempt.
-- ============================================================

grant select, insert, update, delete
on public.companies
to authenticated;

grant select, insert, update, delete
on public.branches
to authenticated;

grant select, insert, update, delete
on public.departments
to authenticated;

grant select, insert, update, delete
on public.fiscal_years
to authenticated;

grant select, insert, update, delete
on public.accounting_periods
to authenticated;


grant select
on public.user_profiles
to authenticated;

grant select
on public.roles
to authenticated;

grant select
on public.permissions
to authenticated;

grant select
on public.role_permissions
to authenticated;

grant select
on public.user_roles
to authenticated;

grant select
on public.user_company_access
to authenticated;

grant select
on public.user_branch_access
to authenticated;


-- ============================================================
-- 2. USER PROFILES
-- ============================================================
--
-- A user may read their own profile.
-- SYSTEM_ADMIN may read all profiles.
-- User modification will later be handled through controlled
-- administration workflows.
-- ============================================================

drop policy if exists
"user_profiles_select_own_or_admin"
on public.user_profiles;

create policy
"user_profiles_select_own_or_admin"
on public.user_profiles
for select
to authenticated
using (
  auth_user_id = auth.uid()
  or public.is_system_admin()
);


-- ============================================================
-- 3. ROLES
-- ============================================================

drop policy if exists
"roles_select_authenticated"
on public.roles;

create policy
"roles_select_authenticated"
on public.roles
for select
to authenticated
using (
  public.is_system_admin()
  or public.has_permission(
    'security.role.view'
  )
);


-- ============================================================
-- 4. PERMISSIONS
-- ============================================================

drop policy if exists
"permissions_select_authenticated"
on public.permissions;

create policy
"permissions_select_authenticated"
on public.permissions
for select
to authenticated
using (
  public.is_system_admin()
  or public.has_permission(
    'security.permission.view'
  )
);


-- ============================================================
-- 5. ROLE PERMISSIONS
-- ============================================================

drop policy if exists
"role_permissions_select_authenticated"
on public.role_permissions;

create policy
"role_permissions_select_authenticated"
on public.role_permissions
for select
to authenticated
using (
  public.is_system_admin()
  or public.has_permission(
    'security.role.view'
  )
);


-- ============================================================
-- 6. USER ROLES
-- ============================================================

drop policy if exists
"user_roles_select_own_or_admin"
on public.user_roles;

create policy
"user_roles_select_own_or_admin"
on public.user_roles
for select
to authenticated
using (
  user_id = public.current_elvaris_user_id()
  or public.is_system_admin()
  or public.has_permission(
    'security.user.view'
  )
);


-- ============================================================
-- 7. USER → COMPANY ACCESS
-- ============================================================

drop policy if exists
"user_company_access_select_own_or_admin"
on public.user_company_access;

create policy
"user_company_access_select_own_or_admin"
on public.user_company_access
for select
to authenticated
using (
  user_id = public.current_elvaris_user_id()
  or public.is_system_admin()
  or public.has_permission(
    'security.company_access.manage'
  )
);


-- ============================================================
-- 8. USER → BRANCH ACCESS
-- ============================================================

drop policy if exists
"user_branch_access_select_own_or_admin"
on public.user_branch_access;

create policy
"user_branch_access_select_own_or_admin"
on public.user_branch_access
for select
to authenticated
using (
  user_id = public.current_elvaris_user_id()
  or public.is_system_admin()
  or public.has_permission(
    'security.branch_access.manage'
  )
);


-- ============================================================
-- 9. COMPANIES — SELECT
-- ============================================================

drop policy if exists
"companies_select_authorized"
on public.companies;

create policy
"companies_select_authorized"
on public.companies
for select
to authenticated
using (
  public.is_system_admin()
  or public.has_company_access(id)
);


-- ============================================================
-- 10. COMPANIES — INSERT
-- ============================================================

drop policy if exists
"companies_insert_authorized"
on public.companies;

create policy
"companies_insert_authorized"
on public.companies
for insert
to authenticated
with check (
  public.is_system_admin()
  or public.has_permission(
    'settings.company.create'
  )
);


-- ============================================================
-- 11. COMPANIES — UPDATE
-- ============================================================

drop policy if exists
"companies_update_authorized"
on public.companies;

create policy
"companies_update_authorized"
on public.companies
for update
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_company_access(id)
    and public.has_permission(
      'settings.company.edit'
    )
  )
)
with check (
  public.is_system_admin()
  or (
    public.has_company_access(id)
    and public.has_permission(
      'settings.company.edit'
    )
  )
);


-- ============================================================
-- 12. COMPANIES — DELETE
-- ============================================================

drop policy if exists
"companies_delete_authorized"
on public.companies;

create policy
"companies_delete_authorized"
on public.companies
for delete
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_company_access(id)
    and public.has_permission(
      'settings.company.delete'
    )
  )
);


-- ============================================================
-- 13. BRANCHES — SELECT
-- ============================================================

drop policy if exists
"branches_select_authorized"
on public.branches;

create policy
"branches_select_authorized"
on public.branches
for select
to authenticated
using (
  public.is_system_admin()
  or public.has_branch_access(id)
);


-- ============================================================
-- 14. BRANCHES — INSERT
-- ============================================================

drop policy if exists
"branches_insert_authorized"
on public.branches;

create policy
"branches_insert_authorized"
on public.branches
for insert
to authenticated
with check (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'settings.branch.create'
    )
  )
);


-- ============================================================
-- 15. BRANCHES — UPDATE
-- ============================================================

drop policy if exists
"branches_update_authorized"
on public.branches;

create policy
"branches_update_authorized"
on public.branches
for update
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_branch_access(id)
    and public.has_permission(
      'settings.branch.edit'
    )
  )
)
with check (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'settings.branch.edit'
    )
  )
);


-- ============================================================
-- 16. BRANCHES — DELETE
-- ============================================================

drop policy if exists
"branches_delete_authorized"
on public.branches;

create policy
"branches_delete_authorized"
on public.branches
for delete
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_branch_access(id)
    and public.has_permission(
      'settings.branch.delete'
    )
  )
);


-- ============================================================
-- 17. DEPARTMENTS — SELECT
-- ============================================================

drop policy if exists
"departments_select_authorized"
on public.departments;

create policy
"departments_select_authorized"
on public.departments
for select
to authenticated
using (
  public.is_system_admin()
  or public.has_company_access(company_id)
);


-- ============================================================
-- 18. DEPARTMENTS — INSERT
-- ============================================================

drop policy if exists
"departments_insert_authorized"
on public.departments;

create policy
"departments_insert_authorized"
on public.departments
for insert
to authenticated
with check (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'settings.master.manage'
    )
  )
);


-- ============================================================
-- 19. DEPARTMENTS — UPDATE
-- ============================================================

drop policy if exists
"departments_update_authorized"
on public.departments;

create policy
"departments_update_authorized"
on public.departments
for update
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'settings.master.manage'
    )
  )
)
with check (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'settings.master.manage'
    )
  )
);


-- ============================================================
-- 20. DEPARTMENTS — DELETE
-- ============================================================

drop policy if exists
"departments_delete_authorized"
on public.departments;

create policy
"departments_delete_authorized"
on public.departments
for delete
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'settings.master.manage'
    )
  )
);


-- ============================================================
-- 21. FISCAL YEARS — SELECT
-- ============================================================

drop policy if exists
"fiscal_years_select_authorized"
on public.fiscal_years;

create policy
"fiscal_years_select_authorized"
on public.fiscal_years
for select
to authenticated
using (
  public.is_system_admin()
  or public.has_company_access(company_id)
);


-- ============================================================
-- 22. FISCAL YEARS — INSERT
-- ============================================================

drop policy if exists
"fiscal_years_insert_authorized"
on public.fiscal_years;

create policy
"fiscal_years_insert_authorized"
on public.fiscal_years
for insert
to authenticated
with check (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'finance.period.manage'
    )
  )
);


-- ============================================================
-- 23. FISCAL YEARS — UPDATE
-- ============================================================

drop policy if exists
"fiscal_years_update_authorized"
on public.fiscal_years;

create policy
"fiscal_years_update_authorized"
on public.fiscal_years
for update
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'finance.period.manage'
    )
  )
)
with check (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'finance.period.manage'
    )
  )
);


-- ============================================================
-- 24. FISCAL YEARS — DELETE
-- ============================================================

drop policy if exists
"fiscal_years_delete_authorized"
on public.fiscal_years;

create policy
"fiscal_years_delete_authorized"
on public.fiscal_years
for delete
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_company_access(company_id)
    and public.has_permission(
      'finance.period.manage'
    )
  )
);


-- ============================================================
-- 25. ACCOUNTING PERIODS — SELECT
-- ============================================================

drop policy if exists
"accounting_periods_select_authorized"
on public.accounting_periods;

create policy
"accounting_periods_select_authorized"
on public.accounting_periods
for select
to authenticated
using (
  public.is_system_admin()
  or exists (
    select 1
    from public.fiscal_years fy
    where fy.id =
      accounting_periods.fiscal_year_id
      and public.has_company_access(
        fy.company_id
      )
  )
);


-- ============================================================
-- 26. ACCOUNTING PERIODS — INSERT
-- ============================================================

drop policy if exists
"accounting_periods_insert_authorized"
on public.accounting_periods;

create policy
"accounting_periods_insert_authorized"
on public.accounting_periods
for insert
to authenticated
with check (
  public.is_system_admin()
  or (
    public.has_permission(
      'finance.period.manage'
    )
    and exists (
      select 1
      from public.fiscal_years fy
      where fy.id =
        accounting_periods.fiscal_year_id
        and public.has_company_access(
          fy.company_id
        )
    )
  )
);


-- ============================================================
-- 27. ACCOUNTING PERIODS — UPDATE
-- ============================================================

drop policy if exists
"accounting_periods_update_authorized"
on public.accounting_periods;

create policy
"accounting_periods_update_authorized"
on public.accounting_periods
for update
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_permission(
      'finance.period.manage'
    )
    and exists (
      select 1
      from public.fiscal_years fy
      where fy.id =
        accounting_periods.fiscal_year_id
        and public.has_company_access(
          fy.company_id
        )
    )
  )
)
with check (
  public.is_system_admin()
  or (
    public.has_permission(
      'finance.period.manage'
    )
    and exists (
      select 1
      from public.fiscal_years fy
      where fy.id =
        accounting_periods.fiscal_year_id
        and public.has_company_access(
          fy.company_id
        )
    )
  )
);


-- ============================================================
-- 28. ACCOUNTING PERIODS — DELETE
-- ============================================================

drop policy if exists
"accounting_periods_delete_authorized"
on public.accounting_periods;

create policy
"accounting_periods_delete_authorized"
on public.accounting_periods
for delete
to authenticated
using (
  public.is_system_admin()
  or (
    public.has_permission(
      'finance.period.manage'
    )
    and exists (
      select 1
      from public.fiscal_years fy
      where fy.id =
        accounting_periods.fiscal_year_id
        and public.has_company_access(
          fy.company_id
        )
    )
  )
);
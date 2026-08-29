-- ============================================================
-- ELVARIS ERP
-- Migration 004: Security & Multi-Tenant Foundation
--
-- Purpose:
--   Establish the application-level security model.
--
-- Authentication:
--   Supabase Auth owns the authentication identity.
--
-- Authorization:
--   Elvaris owns profiles, roles, permissions and
--   company/branch access mappings.
--
-- RLS policies are intentionally NOT created here.
-- They are created after these tables exist.
-- ============================================================


-- ============================================================
-- 1. USER PROFILES
-- ============================================================
--
-- One Elvaris profile corresponds to one Supabase Auth user.
--
-- We keep the authentication identity separate from the
-- application profile.
-- ============================================================

create table if not exists public.user_profiles (
  id uuid primary key default gen_random_uuid(),

  auth_user_id uuid not null,

  display_name text not null,

  email text,

  phone text,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint user_profiles_auth_user_unique
    unique (auth_user_id)
);


-- ============================================================
-- 2. ROLES
-- ============================================================

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),

  code varchar(50) not null,
  name varchar(100) not null,

  description text,

  is_system_role boolean not null default false,
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint roles_code_unique
    unique (code)
);


-- ============================================================
-- 3. PERMISSIONS
-- ============================================================

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),

  code varchar(120) not null,
  name varchar(150) not null,

  module varchar(50) not null,
  action varchar(50) not null,

  description text,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),

  constraint permissions_code_unique
    unique (code)
);


-- ============================================================
-- 4. ROLE PERMISSIONS
-- ============================================================

create table if not exists public.role_permissions (
  role_id uuid not null
    references public.roles(id)
    on delete cascade,

  permission_id uuid not null
    references public.permissions(id)
    on delete cascade,

  created_at timestamptz not null default now(),

  primary key (
    role_id,
    permission_id
  )
);


-- ============================================================
-- 5. USER ROLES
-- ============================================================

create table if not exists public.user_roles (
  user_id uuid not null
    references public.user_profiles(id)
    on delete cascade,

  role_id uuid not null
    references public.roles(id)
    on delete restrict,

  created_at timestamptz not null default now(),

  primary key (
    user_id,
    role_id
  )
);


-- ============================================================
-- 6. USER → COMPANY ACCESS
-- ============================================================

create table if not exists public.user_company_access (
  user_id uuid not null
    references public.user_profiles(id)
    on delete cascade,

  company_id uuid not null
    references public.companies(id)
    on delete cascade,

  is_default boolean not null default false,

  created_at timestamptz not null default now(),

  primary key (
    user_id,
    company_id
  )
);


-- ============================================================
-- 7. USER → BRANCH ACCESS
-- ============================================================

create table if not exists public.user_branch_access (
  user_id uuid not null
    references public.user_profiles(id)
    on delete cascade,

  branch_id uuid not null
    references public.branches(id)
    on delete cascade,

  is_default boolean not null default false,

  created_at timestamptz not null default now(),

  primary key (
    user_id,
    branch_id
  )
);


-- ============================================================
-- 8. INDEXES
-- ============================================================

create index if not exists
idx_user_profiles_auth_user
on public.user_profiles(auth_user_id);


create index if not exists
idx_user_profiles_active
on public.user_profiles(is_active);


create index if not exists
idx_roles_active
on public.roles(is_active);


create index if not exists
idx_permissions_module
on public.permissions(module);


create index if not exists
idx_permissions_action
on public.permissions(action);


create index if not exists
idx_role_permissions_permission
on public.role_permissions(permission_id);


create index if not exists
idx_user_roles_role
on public.user_roles(role_id);


create index if not exists
idx_user_company_access_company
on public.user_company_access(company_id);


create index if not exists
idx_user_branch_access_branch
on public.user_branch_access(branch_id);


-- ============================================================
-- 9. UPDATED_AT TRIGGERS
-- ============================================================

drop trigger if exists user_profiles_set_updated_at
on public.user_profiles;

create trigger user_profiles_set_updated_at
before update on public.user_profiles
for each row
execute function public.set_updated_at();


drop trigger if exists roles_set_updated_at
on public.roles;

create trigger roles_set_updated_at
before update on public.roles
for each row
execute function public.set_updated_at();


-- ============================================================
-- 10. ROW LEVEL SECURITY
-- ============================================================
--
-- Enable RLS now.
--
-- Actual policies are intentionally added in the next
-- security migration after the helper functions are created.
-- ============================================================

alter table public.user_profiles
enable row level security;

alter table public.roles
enable row level security;

alter table public.permissions
enable row level security;

alter table public.role_permissions
enable row level security;

alter table public.user_roles
enable row level security;

alter table public.user_company_access
enable row level security;

alter table public.user_branch_access
enable row level security;


-- ============================================================
-- 11. TABLE COMMENTS
-- ============================================================

comment on table public.user_profiles is
  'Elvaris application profile linked to a Supabase Auth user.';


comment on table public.roles is
  'Application roles used for authorization.';


comment on table public.permissions is
  'Atomic application permissions grouped by module and action.';


comment on table public.role_permissions is
  'Many-to-many mapping between roles and permissions.';


comment on table public.user_roles is
  'Many-to-many mapping between users and roles.';


comment on table public.user_company_access is
  'Companies that an Elvaris user is authorized to access.';


comment on table public.user_branch_access is
  'Branches that an Elvaris user is authorized to access.';
-- ============================================================
-- ELVARIS ERP
-- Migration 007: Auth → User Profile Foundation
--
-- Purpose:
--   Link an authenticated Supabase user to an Elvaris
--   application profile without modifying Supabase-managed
--   auth.users triggers.
--
-- Important:
--   We do NOT create triggers on auth.users here.
--   Supabase owns the auth.users relation.
--
-- The application will use ensure_current_user_profile()
-- after authentication to create the Elvaris profile.
-- ============================================================


-- ============================================================
-- 1. AUTH USER FOREIGN KEY
-- ============================================================

alter table public.user_profiles
drop constraint if exists user_profiles_auth_user_fk;

alter table public.user_profiles
add constraint user_profiles_auth_user_fk
foreign key (auth_user_id)
references auth.users(id)
on delete cascade;


-- ============================================================
-- 2. UNIQUE INDEX
-- ============================================================

create unique index if not exists
idx_user_profiles_auth_user_unique
on public.user_profiles(auth_user_id);


-- ============================================================
-- 3. ENSURE CURRENT USER PROFILE
-- ============================================================
--
-- Creates the Elvaris profile for the currently authenticated
-- Supabase user if it does not already exist.
--
-- Returns the Elvaris user_profile.id.
-- ============================================================

create or replace function public.ensure_current_user_profile()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_auth_user_id uuid;
  current_email text;
  current_display_name text;
  profile_id uuid;
begin

  current_auth_user_id := auth.uid();


  if current_auth_user_id is null then
    raise exception
      'Authentication required.';
  end if;


  select
    au.email,
    coalesce(
      nullif(
        trim(
          au.raw_user_meta_data ->> 'full_name'
        ),
        ''
      ),
      nullif(
        trim(
          au.raw_user_meta_data ->> 'name'
        ),
        ''
      ),
      nullif(
        trim(
          au.email
        ),
        ''
      ),
      'User'
    )
  into
    current_email,
    current_display_name
  from auth.users au
  where au.id = current_auth_user_id;


  if not found then
    raise exception
      'Authenticated user could not be found.';
  end if;


  insert into public.user_profiles (
    auth_user_id,
    display_name,
    email,
    is_active
  )
  values (
    current_auth_user_id,
    current_display_name,
    current_email,
    true
  )
  on conflict (auth_user_id)
  do update set
    email = excluded.email,
    updated_at = now()
  returning id
  into profile_id;


  return profile_id;

end;
$$;


-- ============================================================
-- 4. FUNCTION DOCUMENTATION
-- ============================================================

comment on function public.ensure_current_user_profile()
is
  'Creates or returns the Elvaris profile for the currently authenticated Supabase user.';
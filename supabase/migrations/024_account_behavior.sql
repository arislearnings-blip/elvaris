-- ============================================================
-- ELVARIS ERP
-- Migration 024
-- Account / Subledger Behavior
-- ============================================================
--
-- Purpose:
--   Define whether a Chart of Accounts account may or must have
--   an associated accounting Name.
--
-- Design:
--
--   Ordinary account:
--       Name optional
--
--   Accounts Receivable:
--       Name required
--
--   Accounts Payable:
--       Name required
--
--   Equity accounts:
--       Name required where configured
--
--   Future subledger-controlled accounts:
--       Can be configured without changing application code.
--
-- IMPORTANT:
--   This migration does NOT create Customer, Vendor, Employee
--   or Other master tables.
--
--   Those will be added in the Accounting Names migration.
--
-- ============================================================


-- ============================================================
-- 1. NAME REQUIREMENT ENUM
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_type
        where typname = 'account_name_requirement'
          and typnamespace = 'public'::regnamespace
    ) then

        create type public.account_name_requirement as enum (
            'optional',
            'required'
        );

    end if;

end
$$;


-- ============================================================
-- 2. ADD ACCOUNT NAME BEHAVIOR
-- ============================================================

alter table public.chart_of_accounts
add column if not exists
    name_requirement public.account_name_requirement
    not null
    default 'optional';


-- ============================================================
-- 3. OPTIONAL NAME ALLOWED FLAG
-- ============================================================
--
-- This is kept separate from the requirement setting so the
-- behavior remains explicit and easy to query from the UI.
--
-- required:
--     allow_name = true
--
-- optional:
--     allow_name = true
--
-- In future, restricted subledger behavior can be introduced
-- without redesigning the account table.
-- ============================================================

alter table public.chart_of_accounts
add column if not exists
    allow_name boolean
    not null
    default true;


-- ============================================================
-- 4. VALIDATE NAME BEHAVIOR
-- ============================================================

alter table public.chart_of_accounts
drop constraint if exists
    chart_of_accounts_name_behavior_check;


alter table public.chart_of_accounts
add constraint
    chart_of_accounts_name_behavior_check
check (
    allow_name = true
    or name_requirement = 'optional'
);


-- ============================================================
-- 5. SYSTEM ACCOUNT CONFIGURATION
-- ============================================================
--
-- The account itself determines the rule.
--
-- A/R:
--     Name required
--
-- A/P:
--     Name required
--
-- Owner Equity:
--     Name required
--
-- Owner Draw:
--     Name required
--
-- Retained Earnings:
--     Name optional
--
-- Opening Balance Equity:
--     Name optional
--
-- Other normal operating accounts:
--     Name optional
-- ============================================================


update public.chart_of_accounts
set
    name_requirement = 'required',
    allow_name = true,
    updated_at = now()
where system_account_code in (
    'accounts_receivable',
    'accounts_payable',
    'owner_equity',
    'owner_draw'
);


update public.chart_of_accounts
set
    name_requirement = 'optional',
    allow_name = true,
    updated_at = now()
where system_account_code in (
    'retained_earnings',
    'opening_balance_equity'
);


-- ============================================================
-- 6. OTHER SYSTEM ACCOUNTS DEFAULT TO OPTIONAL
-- ============================================================

update public.chart_of_accounts
set
    name_requirement = 'optional',
    allow_name = true,
    updated_at = now()
where is_system_account = true
  and system_account_code not in (
      'accounts_receivable',
      'accounts_payable',
      'owner_equity',
      'owner_draw',
      'retained_earnings',
      'opening_balance_equity'
  );


-- ============================================================
-- 7. ACCOUNT BEHAVIOR FUNCTION
-- ============================================================

create or replace function public.get_account_name_behavior(
    p_account_id uuid
)
returns table (
    account_id uuid,
    account_code varchar(30),
    account_name varchar(150),
    name_required boolean,
    name_optional boolean
)
language plpgsql
security definer
stable
set search_path = public
as $function$

begin

    return query

    select
        coa.id,
        coa.account_code,
        coa.account_name,
        coa.name_requirement = 'required'::public.account_name_requirement,
        coa.allow_name

    from public.chart_of_accounts coa

    where coa.id = p_account_id;

end;
$function$;


-- ============================================================
-- 8. VALIDATE WHETHER A NAME IS REQUIRED
-- ============================================================

create or replace function public.account_requires_name(
    p_account_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_required boolean;

begin

    select
        coa.name_requirement =
            'required'::public.account_name_requirement

    into v_required

    from public.chart_of_accounts coa

    where coa.id = p_account_id;


    if v_required is null then

        raise exception
            'Account does not exist.';

    end if;


    return v_required;

end;
$function$;


-- ============================================================
-- 9. VALIDATE WHETHER A NAME MAY BE USED
-- ============================================================

create or replace function public.account_allows_name(
    p_account_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_allowed boolean;

begin

    select
        coa.allow_name

    into v_allowed

    from public.chart_of_accounts coa

    where coa.id = p_account_id;


    if v_allowed is null then

        raise exception
            'Account does not exist.';

    end if;


    return v_allowed;

end;
$function$;


-- ============================================================
-- 10. UPDATE ACCOUNT MANAGEMENT FUNCTION
-- ============================================================
--
-- User-created accounts can choose whether a Name is optional
-- or required.
--
-- System accounts remain protected.
-- ============================================================

create or replace function public.set_coa_account_name_behavior(
    p_account_id uuid,
    p_name_requirement public.account_name_requirement,
    p_allow_name boolean default true
)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_account public.chart_of_accounts%rowtype;

begin

    select *
    into v_account
    from public.chart_of_accounts
    where id = p_account_id
    for update;


    if not found then

        raise exception
            'Account does not exist.';

    end if;


    if v_account.is_system_account then

        raise exception
            'System account "%" cannot have its name behavior changed through normal account maintenance.',
            v_account.account_code;

    end if;


    if p_allow_name = false
       and p_name_requirement = 'required'
    then

        raise exception
            'An account cannot require a Name while Name usage is disabled.';

    end if;


    update public.chart_of_accounts
    set
        name_requirement = p_name_requirement,
        allow_name = p_allow_name,
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_account_id;


    return true;

end;
$function$;


-- ============================================================
-- 11. COMMENTS
-- ============================================================

comment on column public.chart_of_accounts.name_requirement
is
    'Determines whether an accounting Name is optional or required when using this account.';


comment on column public.chart_of_accounts.allow_name
is
    'Determines whether an accounting Name may be attached to transactions using this account.';


comment on function public.get_account_name_behavior(
    uuid
)
is
    'Returns Name behavior configuration for an account.';


comment on function public.account_requires_name(
    uuid
)
is
    'Returns true when the selected account requires an accounting Name.';


comment on function public.account_allows_name(
    uuid
)
is
    'Returns true when an accounting Name may be used with the selected account.';


comment on function public.set_coa_account_name_behavior(
    uuid,
    public.account_name_requirement,
    boolean
)
is
    'Configures Name behavior for a non-system Chart of Accounts account.';


-- ============================================================
-- 12. VALIDATION
-- ============================================================

do $$
declare
    v_required integer;
begin

    select count(*)
    into v_required
    from public.chart_of_accounts
    where system_account_code in (
        'accounts_receivable',
        'accounts_payable',
        'owner_equity',
        'owner_draw'
    )
      and name_requirement =
          'required'::public.account_name_requirement;


    if v_required <> 4 then

        raise exception
            'Account Name behavior validation failed. Expected 4 required system accounts, found %.',
            v_required;

    end if;


    if exists (
        select 1
        from public.chart_of_accounts
        where is_system_account = true
          and allow_name = false
          and name_requirement =
              'required'::public.account_name_requirement
    ) then

        raise exception
            'Invalid system account Name behavior detected.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 024
-- ============================================================
-- ============================================================
-- ELVARIS ERP
-- Migration 028
-- Correct Control Account Posting Behavior
-- ============================================================
--
-- Purpose:
--   Correct the posting behavior of subledger control accounts.
--
-- Accounting rule:
--
--   A/R and A/P are posting/control accounts.
--   They may be used in journal entries.
--   A Name is mandatory when they are used.
--
-- Example:
--
--   Accounts Receivable
--       Name: ABC Traders
--       Debit: 5,000
--
--   Cash
--       Name: optional
--       Credit: 5,000
--
-- The Name requirement prevents unidentified A/R/A/P balances
-- while still allowing legitimate journal entries.
-- ============================================================


-- ============================================================
-- 1. ACCOUNTS RECEIVABLE
-- ============================================================

update public.chart_of_accounts
set
    account_role = 'control',
    node_type = 'account',
    is_header = false,
    is_posting = true,
    is_control_account = true,
    allow_manual_posting = true,
    name_requirement = 'required',
    allow_name = true,
    is_active = true,
    is_system_account = true,
    is_locked = true,
    updated_at = now()
where system_account_code = 'accounts_receivable';


-- ============================================================
-- 2. ACCOUNTS PAYABLE
-- ============================================================

update public.chart_of_accounts
set
    account_role = 'control',
    node_type = 'account',
    is_header = false,
    is_posting = true,
    is_control_account = true,
    allow_manual_posting = true,
    name_requirement = 'required',
    allow_name = true,
    is_active = true,
    is_system_account = true,
    is_locked = true,
    updated_at = now()
where system_account_code = 'accounts_payable';


-- ============================================================
-- 3. UPDATE ACCOUNT VALIDATION
-- ============================================================
--
-- Control accounts may post manually, but their Name requirement
-- is enforced separately by the journal posting engine.
-- ============================================================

create or replace function public.validate_journal_account(
    p_account_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_account record;

begin

    select
        is_active,
        is_header,
        is_posting,
        is_control_account,
        allow_manual_posting
    into v_account
    from public.chart_of_accounts
    where id = p_account_id;


    if not found then

        raise exception
            'Journal account does not exist.';

    end if;


    if v_account.is_active = false then

        raise exception
            'Journal account is inactive.';

    end if;


    if v_account.is_header = true then

        raise exception
            'Header account cannot receive journal postings.';

    end if;


    if v_account.is_posting = false then

        raise exception
            'Selected account is not a posting account.';

    end if;


    if v_account.allow_manual_posting = false then

        raise exception
            'Manual posting is not allowed to this account.';

    end if;


    return true;

end;
$function$;


-- ============================================================
-- 4. VALIDATION
-- ============================================================

do $$
declare
    v_ar_count integer;
    v_ap_count integer;
begin

    select count(*)
    into v_ar_count
    from public.chart_of_accounts
    where system_account_code = 'accounts_receivable'
      and account_role = 'control'
      and is_control_account = true
      and is_posting = true
      and allow_manual_posting = true
      and name_requirement =
          'required'::public.account_name_requirement
      and is_system_account = true
      and is_locked = true;


    select count(*)
    into v_ap_count
    from public.chart_of_accounts
    where system_account_code = 'accounts_payable'
      and account_role = 'control'
      and is_control_account = true
      and is_posting = true
      and allow_manual_posting = true
      and name_requirement =
          'required'::public.account_name_requirement
      and is_system_account = true
      and is_locked = true;


    if v_ar_count <> 1 then

        raise exception
            'Accounts Receivable control account configuration is invalid.';

    end if;


    if v_ap_count <> 1 then

        raise exception
            'Accounts Payable control account configuration is invalid.';

    end if;

end
$$;


-- ============================================================
-- 5. COMMENTS
-- ============================================================

comment on function public.validate_journal_account(
    uuid
)
is
    'Validates that an account is active, posting-enabled, and permitted for manual journal posting. Control accounts may post but their Name requirement is enforced separately.';


-- ============================================================
-- END MIGRATION 028
-- ============================================================
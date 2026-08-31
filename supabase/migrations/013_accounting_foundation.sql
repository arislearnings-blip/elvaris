-- ============================================================
-- ELVARIS ERP
-- Migration 013: Accounting Foundation
--
-- Purpose:
--   Establish the accounting master structure required for:
--
--   1. Chart of Accounts
--   2. Account Types
--   3. Account Hierarchy
--   4. Control Accounts
--   5. Financial Statement Classification
--
-- This migration does NOT yet post accounting transactions.
-- Journal entry and posting infrastructure comes next.
-- ============================================================


-- ============================================================
-- 1. ACCOUNT TYPE ENUM
-- ============================================================

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'account_type_code'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.account_type_code as enum (
      'asset',
      'liability',
      'equity',
      'income',
      'expense',
      'contra_asset',
      'contra_liability',
      'contra_equity',
      'contra_income',
      'contra_expense'
    );

  end if;
end
$$;


-- ============================================================
-- 2. NORMAL BALANCE ENUM
-- ============================================================

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'account_normal_balance'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.account_normal_balance as enum (
      'debit',
      'credit'
    );

  end if;
end
$$;


-- ============================================================
-- 3. ACCOUNT TYPES
-- ============================================================

create table if not exists public.account_types (
  id uuid primary key default gen_random_uuid(),

  code varchar(50) not null,
  name varchar(100) not null,

  account_type public.account_type_code not null,

  normal_balance public.account_normal_balance not null,

  statement_section varchar(50) not null,

  description text,

  display_order integer not null default 0,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint account_types_code_unique
    unique (code),

  constraint account_types_display_order_check
    check (display_order >= 0)
);


-- ============================================================
-- 4. CHART OF ACCOUNTS
-- ============================================================

create table if not exists public.chart_of_accounts (
  id uuid primary key default gen_random_uuid(),

  company_id uuid not null
    references public.companies(id)
    on delete cascade,

  account_type_id uuid not null
    references public.account_types(id)
    on delete restrict,

  parent_account_id uuid
    references public.chart_of_accounts(id)
    on delete restrict,

  account_code varchar(30) not null,

  account_name varchar(150) not null,

  description text,

  /*
   * Header accounts are grouping accounts.
   * Posting accounts are allowed on journal lines.
   */
  is_header boolean not null default false,

  is_posting boolean not null default true,

  /*
   * Control accounts are linked automatically to subledgers.
   *
   * Examples:
   *   Accounts Receivable
   *   Accounts Payable
   *   Inventory
   *   Fixed Assets
   */
  is_control_account boolean not null default false,

  /*
   * Used by accounting reports and automatic posting logic.
   *
   * Examples:
   *   cash
   *   bank
   *   accounts_receivable
   *   accounts_payable
   *   inventory
   *   sales
   *   cost_of_goods_sold
   *   tax_payable
   *   retained_earnings
   */
  system_account_code varchar(60),

  allow_manual_posting boolean not null default true,

  currency_id uuid
    references public.currencies(id)
    on delete restrict,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  created_by uuid,

  updated_at timestamptz not null default now(),
  updated_by uuid,

  constraint chart_of_accounts_company_code_unique
    unique (
      company_id,
      account_code
    ),

  constraint chart_of_accounts_header_posting_check
    check (
      not (
        is_header = true
        and is_posting = true
      )
    ),

  constraint chart_of_accounts_manual_posting_check
    check (
      is_posting = true
      or allow_manual_posting = false
    )
);


-- ============================================================
-- 5. ACCOUNT HIERARCHY INDEXES
-- ============================================================

create index if not exists
idx_chart_of_accounts_company
on public.chart_of_accounts(company_id);


create index if not exists
idx_chart_of_accounts_parent
on public.chart_of_accounts(parent_account_id);


create index if not exists
idx_chart_of_accounts_type
on public.chart_of_accounts(account_type_id);


create index if not exists
idx_chart_of_accounts_system_code
on public.chart_of_accounts(system_account_code);


create index if not exists
idx_chart_of_accounts_active
on public.chart_of_accounts(
  company_id,
  is_active
);


-- ============================================================
-- 6. ACCOUNT TYPES INDEXES
-- ============================================================

create index if not exists
idx_account_types_type
on public.account_types(account_type);


create index if not exists
idx_account_types_active
on public.account_types(is_active);


-- ============================================================
-- 7. UPDATED_AT TRIGGER — ACCOUNT TYPES
-- ============================================================

drop trigger if exists
account_types_set_updated_at
on public.account_types;

create trigger
account_types_set_updated_at
before update on public.account_types
for each row
execute function public.set_updated_at();


-- ============================================================
-- 8. UPDATED_AT TRIGGER — CHART OF ACCOUNTS
-- ============================================================

drop trigger if exists
chart_of_accounts_set_updated_at
on public.chart_of_accounts;

create trigger
chart_of_accounts_set_updated_at
before update on public.chart_of_accounts
for each row
execute function public.set_updated_at();


-- ============================================================
-- 9. SEED STANDARD ACCOUNT TYPES
-- ============================================================

insert into public.account_types (
  code,
  name,
  account_type,
  normal_balance,
  statement_section,
  description,
  display_order,
  is_active
)
values

(
  'ASSET',
  'Assets',
  'asset',
  'debit',
  'balance_sheet',
  'Resources controlled by the company.',
  10,
  true
),

(
  'LIABILITY',
  'Liabilities',
  'liability',
  'credit',
  'balance_sheet',
  'Obligations owed by the company.',
  20,
  true
),

(
  'EQUITY',
  'Equity',
  'equity',
  'credit',
  'balance_sheet',
  'Owners equity and accumulated balances.',
  30,
  true
),

(
  'INCOME',
  'Income',
  'income',
  'credit',
  'profit_and_loss',
  'Revenue and other income.',
  40,
  true
),

(
  'EXPENSE',
  'Expenses',
  'expense',
  'debit',
  'profit_and_loss',
  'Operating and other expenses.',
  50,
  true
),

(
  'CONTRA_ASSET',
  'Contra Assets',
  'contra_asset',
  'credit',
  'balance_sheet',
  'Accounts that reduce asset balances.',
  60,
  true
),

(
  'CONTRA_LIABILITY',
  'Contra Liabilities',
  'contra_liability',
  'debit',
  'balance_sheet',
  'Accounts that reduce liability balances.',
  70,
  true
),

(
  'CONTRA_EQUITY',
  'Contra Equity',
  'contra_equity',
  'debit',
  'balance_sheet',
  'Accounts that reduce equity balances.',
  80,
  true
),

(
  'CONTRA_INCOME',
  'Contra Income',
  'contra_income',
  'debit',
  'profit_and_loss',
  'Accounts that reduce income.',
  90,
  true
),

(
  'CONTRA_EXPENSE',
  'Contra Expenses',
  'contra_expense',
  'credit',
  'profit_and_loss',
  'Accounts that reduce expenses.',
  100,
  true
)

on conflict (code)
do update set
  name = excluded.name,
  account_type = excluded.account_type,
  normal_balance = excluded.normal_balance,
  statement_section = excluded.statement_section,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- 10. COMMENTS
-- ============================================================

comment on table public.account_types
is
  'Universal accounting classifications defining account behavior and normal balance.';


comment on table public.chart_of_accounts
is
  'Company-specific chart of accounts with hierarchical financial statement classification.';


comment on column public.chart_of_accounts.is_header
is
  'Header/group account that cannot be posted to directly.';


comment on column public.chart_of_accounts.is_posting
is
  'Indicates whether journal entries may post directly to the account.';


comment on column public.chart_of_accounts.is_control_account
is
  'Identifies accounts controlled by a related subledger.';


comment on column public.chart_of_accounts.system_account_code
is
  'Stable internal identifier used by automatic accounting processes.';
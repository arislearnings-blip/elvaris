-- ============================================================
-- ELVARIS ERP
-- Migration 014: Account Type Refinement
--
-- Purpose:
--   Refine the original accounting foundation into an
--   Elvaris-native Chart of Accounts classification model.
--
-- The model follows familiar desktop-accounting concepts:
--
--   BALANCE SHEET
--     Bank
--     Accounts Receivable
--     Other Current Asset
--     Fixed Asset
--     Other Asset
--     Accounts Payable
--     Credit Card
--     Other Current Liability
--     Long-Term Liability
--     Equity
--
--   PROFIT & LOSS
--     Income
--     Cost of Goods Sold
--     Expense
--     Other Income
--     Other Expense
--
-- Account roles:
--
--   Header
--     Grouping account; non-posting.
--
--   Posting
--     Normal ledger account.
--
--   Control
--     Posting account controlled by a subledger.
--
-- Document-level non-posting behavior will be handled by
-- the transaction/document engine separately.
-- ============================================================


-- ============================================================
-- 1. ACCOUNT CATEGORY ENUM
-- ============================================================

do $$
begin

  if not exists (
    select 1
    from pg_type
    where typname = 'account_category'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.account_category as enum (

      'bank',

      'accounts_receivable',

      'other_current_asset',

      'fixed_asset',

      'other_asset',

      'accounts_payable',

      'credit_card',

      'other_current_liability',

      'long_term_liability',

      'equity',

      'income',

      'cost_of_goods_sold',

      'expense',

      'other_income',

      'other_expense'

    );

  end if;

end
$$;


-- ============================================================
-- 2. ACCOUNT ROLE ENUM
-- ============================================================

do $$
begin

  if not exists (
    select 1
    from pg_type
    where typname = 'account_role'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.account_role as enum (
      'header',
      'posting',
      'control'
    );

  end if;

end
$$;


-- ============================================================
-- 3. ACCOUNT DETAIL TYPES
-- ============================================================

create table if not exists public.account_detail_types (

  id uuid primary key default gen_random_uuid(),

  account_category
    public.account_category
    not null,

  code varchar(80) not null,

  name varchar(150) not null,

  description text,

  display_order integer not null default 0,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint account_detail_types_unique
    unique (
      account_category,
      code
    ),

  constraint account_detail_types_display_order_check
    check (
      display_order >= 0
    )
);


-- ============================================================
-- 4. EXTEND EXISTING ACCOUNT TYPES TABLE
-- ============================================================

alter table public.account_types
add column if not exists
  account_category public.account_category;


alter table public.account_types
add column if not exists
  is_legacy boolean not null default false;


-- ============================================================
-- 5. EXTEND CHART OF ACCOUNTS
-- ============================================================

alter table public.chart_of_accounts
add column if not exists
  detail_type_id uuid
  references public.account_detail_types(id)
  on delete restrict;


alter table public.chart_of_accounts
add column if not exists
  account_role public.account_role;


-- ============================================================
-- 6. BACKFILL EXISTING ACCOUNT ROLES
-- ============================================================

update public.chart_of_accounts
set account_role =
  case

    when is_control_account = true
      then 'control'::public.account_role

    when is_header = true
      then 'header'::public.account_role

    else
      'posting'::public.account_role

  end
where account_role is null;


-- ============================================================
-- 7. ACCOUNT ROLE CONSISTENCY
-- ============================================================

alter table public.chart_of_accounts
drop constraint if exists
  chart_of_accounts_role_consistency_check;


alter table public.chart_of_accounts
add constraint
  chart_of_accounts_role_consistency_check
check (

  (
    account_role = 'header'
    and is_header = true
    and is_posting = false
    and is_control_account = false
    and allow_manual_posting = false
  )

  or

  (
    account_role = 'posting'
    and is_header = false
    and is_posting = true
    and is_control_account = false
  )

  or

  (
    account_role = 'control'
    and is_header = false
    and is_posting = true
    and is_control_account = true
  )

);


-- ============================================================
-- 8. ACCOUNT TYPE INDEXES
-- ============================================================

create index if not exists
idx_account_types_category
on public.account_types(
  account_category
);


create index if not exists
idx_account_types_active_category
on public.account_types(
  account_category,
  is_active
);


-- ============================================================
-- 9. DETAIL TYPE INDEXES
-- ============================================================

create index if not exists
idx_account_detail_types_category
on public.account_detail_types(
  account_category
);


create index if not exists
idx_account_detail_types_active
on public.account_detail_types(
  account_category,
  is_active
);


-- ============================================================
-- 10. CHART OF ACCOUNTS INDEXES
-- ============================================================

create index if not exists
idx_chart_of_accounts_detail_type
on public.chart_of_accounts(
  detail_type_id
);


create index if not exists
idx_chart_of_accounts_role
on public.chart_of_accounts(
  company_id,
  account_role
);


-- ============================================================
-- 11. UPDATED_AT TRIGGER
-- ============================================================

drop trigger if exists
account_detail_types_set_updated_at
on public.account_detail_types;


create trigger
account_detail_types_set_updated_at
before update on public.account_detail_types
for each row
execute function public.set_updated_at();


-- ============================================================
-- 12. CREATE / UPDATE THE 15 AUTHORITATIVE CATEGORIES
-- ============================================================
--
-- IMPORTANT:
--   The existing EQUITY, INCOME and EXPENSE rows are deliberately
--   reused rather than marked legacy.
--
--   The broad legacy rows are:
--     ASSET
--     LIABILITY
--     CONTRA_ASSET
--     CONTRA_LIABILITY
--     CONTRA_EQUITY
--     CONTRA_INCOME
--     CONTRA_EXPENSE
--
-- ============================================================

insert into public.account_types (
  code,
  name,
  account_type,
  normal_balance,
  statement_section,
  description,
  display_order,
  is_active,
  account_category,
  is_legacy
)
values

(
  'BANK',
  'Bank',
  'asset',
  'debit',
  'balance_sheet',
  'Bank accounts, checking accounts, savings accounts and cash accounts.',
  10,
  true,
  'bank',
  false
),

(
  'ACCOUNTS_RECEIVABLE',
  'Accounts Receivable',
  'asset',
  'debit',
  'balance_sheet',
  'Amounts owed to the company by customers.',
  20,
  true,
  'accounts_receivable',
  false
),

(
  'OTHER_CURRENT_ASSET',
  'Other Current Asset',
  'asset',
  'debit',
  'balance_sheet',
  'Current assets other than bank and accounts receivable.',
  30,
  true,
  'other_current_asset',
  false
),

(
  'FIXED_ASSET',
  'Fixed Asset',
  'asset',
  'debit',
  'balance_sheet',
  'Long-term tangible assets including property, machinery and equipment.',
  40,
  true,
  'fixed_asset',
  false
),

(
  'OTHER_ASSET',
  'Other Asset',
  'asset',
  'debit',
  'balance_sheet',
  'Other long-term or non-current assets.',
  50,
  true,
  'other_asset',
  false
),

(
  'ACCOUNTS_PAYABLE',
  'Accounts Payable',
  'liability',
  'credit',
  'balance_sheet',
  'Amounts owed to vendors through accounts payable transactions.',
  60,
  true,
  'accounts_payable',
  false
),

(
  'CREDIT_CARD',
  'Credit Card',
  'liability',
  'credit',
  'balance_sheet',
  'Credit card liabilities.',
  70,
  true,
  'credit_card',
  false
),

(
  'OTHER_CURRENT_LIABILITY',
  'Other Current Liability',
  'liability',
  'credit',
  'balance_sheet',
  'Current liabilities other than accounts payable and credit cards.',
  80,
  true,
  'other_current_liability',
  false
),

(
  'LONG_TERM_LIABILITY',
  'Long-Term Liability',
  'liability',
  'credit',
  'balance_sheet',
  'Long-term liabilities.',
  90,
  true,
  'long_term_liability',
  false
),

(
  'EQUITY',
  'Equity',
  'equity',
  'credit',
  'balance_sheet',
  'Owners equity, retained earnings and related equity accounts.',
  100,
  true,
  'equity',
  false
),

(
  'INCOME',
  'Income',
  'income',
  'credit',
  'profit_and_loss',
  'Operating revenue.',
  110,
  true,
  'income',
  false
),

(
  'COST_OF_GOODS_SOLD',
  'Cost of Goods Sold',
  'expense',
  'debit',
  'profit_and_loss',
  'Direct costs associated with goods and services sold.',
  120,
  true,
  'cost_of_goods_sold',
  false
),

(
  'EXPENSE',
  'Expense',
  'expense',
  'debit',
  'profit_and_loss',
  'Normal operating expenses.',
  130,
  true,
  'expense',
  false
),

(
  'OTHER_INCOME',
  'Other Income',
  'income',
  'credit',
  'profit_and_loss',
  'Income outside normal operating revenue.',
  140,
  true,
  'other_income',
  false
),

(
  'OTHER_EXPENSE',
  'Other Expense',
  'expense',
  'debit',
  'profit_and_loss',
  'Non-operating expenses.',
  150,
  true,
  'other_expense',
  false
)

on conflict (code)
do update set

  name =
    excluded.name,

  account_type =
    excluded.account_type,

  normal_balance =
    excluded.normal_balance,

  statement_section =
    excluded.statement_section,

  description =
    excluded.description,

  display_order =
    excluded.display_order,

  is_active =
    true,

  account_category =
    excluded.account_category,

  is_legacy =
    false;


-- ============================================================
-- 13. MARK ONLY THE OLD BROAD / CONTRA CATEGORIES AS LEGACY
-- ============================================================

update public.account_types
set
  is_active = false,
  is_legacy = true,
  account_category = null
where code in (
  'ASSET',
  'LIABILITY',
  'CONTRA_ASSET',
  'CONTRA_LIABILITY',
  'CONTRA_EQUITY',
  'CONTRA_INCOME',
  'CONTRA_EXPENSE'
);


-- ============================================================
-- 14. SEED ACCOUNT DETAIL TYPES
-- ============================================================


-- ============================================================
-- BANK
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'bank',
  'checking',
  'Checking',
  'Checking bank account.',
  10,
  true
),

(
  'bank',
  'savings',
  'Savings',
  'Savings bank account.',
  20,
  true
),

(
  'bank',
  'cash_on_hand',
  'Cash on Hand',
  'Physical cash held by the company.',
  30,
  true
),

(
  'bank',
  'petty_cash',
  'Petty Cash',
  'Petty cash account.',
  40,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- ACCOUNTS RECEIVABLE
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'accounts_receivable',
  'trade_receivables',
  'Trade Receivables',
  'Amounts due from customers.',
  10,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- OTHER CURRENT ASSET
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'other_current_asset',
  'inventory_asset',
  'Inventory Asset',
  'Value of inventory held for sale or production.',
  10,
  true
),

(
  'other_current_asset',
  'undeposited_funds',
  'Undeposited Funds',
  'Receipts held before deposit.',
  20,
  true
),

(
  'other_current_asset',
  'prepaid_expenses',
  'Prepaid Expenses',
  'Expenses paid before they are incurred.',
  30,
  true
),

(
  'other_current_asset',
  'short_term_investments',
  'Short-Term Investments',
  'Short-term investments.',
  40,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- FIXED ASSET
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'fixed_asset',
  'buildings',
  'Buildings',
  'Buildings owned by the company.',
  10,
  true
),

(
  'fixed_asset',
  'machinery_equipment',
  'Machinery and Equipment',
  'Machinery and production equipment.',
  20,
  true
),

(
  'fixed_asset',
  'vehicles',
  'Vehicles',
  'Company vehicles.',
  30,
  true
),

(
  'fixed_asset',
  'furniture_fixtures',
  'Furniture and Fixtures',
  'Furniture and fixtures.',
  40,
  true
),

(
  'fixed_asset',
  'computer_equipment',
  'Computer Equipment',
  'Computer and technology equipment.',
  50,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- OTHER ASSET
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'other_asset',
  'security_deposits',
  'Security Deposits',
  'Long-term security deposits.',
  10,
  true
),

(
  'other_asset',
  'long_term_investments',
  'Long-Term Investments',
  'Long-term investments.',
  20,
  true
),

(
  'other_asset',
  'goodwill',
  'Goodwill',
  'Business goodwill.',
  30,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- ACCOUNTS PAYABLE
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'accounts_payable',
  'trade_payables',
  'Trade Payables',
  'Amounts owed to vendors.',
  10,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- CREDIT CARD
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'credit_card',
  'credit_card_account',
  'Credit Card Account',
  'Company credit card account.',
  10,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- OTHER CURRENT LIABILITY
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'other_current_liability',
  'sales_tax_payable',
  'Sales Tax Payable',
  'Sales tax liability.',
  10,
  true
),

(
  'other_current_liability',
  'payroll_tax_payable',
  'Payroll Tax Payable',
  'Payroll-related tax liability.',
  20,
  true
),

(
  'other_current_liability',
  'accrued_expenses',
  'Accrued Expenses',
  'Expenses incurred but not yet paid.',
  30,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- LONG-TERM LIABILITY
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'long_term_liability',
  'long_term_loan',
  'Long-Term Loan',
  'Long-term financing or bank loan.',
  10,
  true
),

(
  'long_term_liability',
  'mortgage',
  'Mortgage',
  'Mortgage payable.',
  20,
  true
),

(
  'long_term_liability',
  'notes_payable',
  'Notes Payable',
  'Long-term notes payable.',
  30,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- EQUITY
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'equity',
  'owner_equity',
  'Owner Equity',
  'Owner investment in the company.',
  10,
  true
),

(
  'equity',
  'owner_draw',
  'Owner Draw',
  'Owner withdrawals.',
  20,
  true
),

(
  'equity',
  'retained_earnings',
  'Retained Earnings',
  'Accumulated retained earnings.',
  30,
  true
),

(
  'equity',
  'opening_balance_equity',
  'Opening Balance Equity',
  'Temporary equity account used during opening balance setup.',
  40,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- INCOME
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'income',
  'sales_income',
  'Sales Income',
  'Revenue from sale of goods.',
  10,
  true
),

(
  'income',
  'service_income',
  'Service Income',
  'Revenue from services.',
  20,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- COST OF GOODS SOLD
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'cost_of_goods_sold',
  'materials',
  'Materials',
  'Direct material cost included in cost of sales.',
  10,
  true
),

(
  'cost_of_goods_sold',
  'direct_labor',
  'Direct Labor',
  'Direct labor included in production or cost of sales.',
  20,
  true
),

(
  'cost_of_goods_sold',
  'manufacturing_overhead',
  'Manufacturing Overhead',
  'Manufacturing overhead assigned to production or cost of sales.',
  30,
  true
),

(
  'cost_of_goods_sold',
  'cost_of_sales',
  'Cost of Sales',
  'General cost of goods sold account.',
  40,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- EXPENSE
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'expense',
  'advertising',
  'Advertising',
  'Advertising expense.',
  10,
  true
),

(
  'expense',
  'rent',
  'Rent',
  'Rent expense.',
  20,
  true
),

(
  'expense',
  'utilities',
  'Utilities',
  'Utilities expense.',
  30,
  true
),

(
  'expense',
  'office_supplies',
  'Office Supplies',
  'Office supplies expense.',
  40,
  true
),

(
  'expense',
  'payroll_expense',
  'Payroll Expense',
  'Employee payroll expense.',
  50,
  true
),

(
  'expense',
  'depreciation',
  'Depreciation',
  'Depreciation expense.',
  60,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- OTHER INCOME
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'other_income',
  'interest_income',
  'Interest Income',
  'Interest earned.',
  10,
  true
),

(
  'other_income',
  'gain_on_asset_sale',
  'Gain on Sale of Asset',
  'Gain from disposal of assets.',
  20,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- OTHER EXPENSE
-- ============================================================

insert into public.account_detail_types (
  account_category,
  code,
  name,
  description,
  display_order,
  is_active
)
values

(
  'other_expense',
  'interest_expense',
  'Interest Expense',
  'Interest expense.',
  10,
  true
),

(
  'other_expense',
  'loss_on_asset_sale',
  'Loss on Sale of Asset',
  'Loss from disposal of assets.',
  20,
  true
),

(
  'other_expense',
  'bank_charges',
  'Bank Charges',
  'Bank fees and charges.',
  30,
  true
)

on conflict (
  account_category,
  code
)
do update set
  name = excluded.name,
  description = excluded.description,
  display_order = excluded.display_order,
  is_active = true;


-- ============================================================
-- 15. COMMENTS
-- ============================================================

comment on table public.account_detail_types
is
  'Elvaris account detail classifications used to refine major account categories.';


comment on column public.account_types.account_category
is
  'Authoritative Elvaris account category controlling financial statement classification.';


comment on column public.chart_of_accounts.detail_type_id
is
  'Specific detail classification for the Chart of Accounts record.';


comment on column public.chart_of_accounts.account_role
is
  'Account role: header/non-posting, posting, or control account.';


comment on column public.chart_of_accounts.parent_account_id
is
  'Optional parent account used for hierarchical Chart of Accounts subaccounts.';


comment on column public.chart_of_accounts.is_header
is
  'Grouping/header account that cannot receive journal postings.';


comment on column public.chart_of_accounts.is_posting
is
  'Indicates whether journal transactions may post directly to the account.';


comment on column public.chart_of_accounts.is_control_account
is
  'Indicates that the account is controlled by a related subledger.';


-- ============================================================
-- 16. FINAL VALIDATION
-- ============================================================

do $$
declare

  v_active_categories integer;

  v_missing_categories integer;

begin

  select count(*)
  into v_active_categories
  from public.account_types
  where account_category is not null
    and is_active = true
    and is_legacy = false;


  if v_active_categories <> 15 then

    raise exception
      'Account category validation failed. Expected 15 active categories, found %.',
      v_active_categories;

  end if;


  select count(*)
  into v_missing_categories
  from (
    values
      ('bank'::public.account_category),
      ('accounts_receivable'::public.account_category),
      ('other_current_asset'::public.account_category),
      ('fixed_asset'::public.account_category),
      ('other_asset'::public.account_category),
      ('accounts_payable'::public.account_category),
      ('credit_card'::public.account_category),
      ('other_current_liability'::public.account_category),
      ('long_term_liability'::public.account_category),
      ('equity'::public.account_category),
      ('income'::public.account_category),
      ('cost_of_goods_sold'::public.account_category),
      ('expense'::public.account_category),
      ('other_income'::public.account_category),
      ('other_expense'::public.account_category)
  ) as expected(category)
  where not exists (
    select 1
    from public.account_types at
    where at.account_category = expected.category
      and at.is_active = true
      and at.is_legacy = false
  );


  if v_missing_categories <> 0 then

    raise exception
      'Account category validation failed. % expected categories are missing.',
      v_missing_categories;

  end if;


end
$$;
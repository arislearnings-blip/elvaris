-- ============================================================
-- ELVARIS ERP
-- Migration 005: Permission Catalogue & System Roles
--
-- Purpose:
--   Create the initial application permission catalogue and
--   standard system roles.
--
-- Design:
--
--   Permission
--       ↓
--   Role
--       ↓
--   User
--       ↓
--   Company / Branch Access
--
-- Permissions are atomic.
-- Roles are collections of permissions.
--
-- This migration does NOT assign roles to users.
-- ============================================================


-- ============================================================
-- 1. PERMISSION CATALOGUE
-- ============================================================

insert into public.permissions (
  code,
  name,
  module,
  action,
  description,
  is_active
)
values

-- ============================================================
-- DASHBOARD
-- ============================================================

(
  'dashboard.view',
  'View Dashboard',
  'dashboard',
  'view',
  'View the Elvaris dashboard.',
  true
),


-- ============================================================
-- SETTINGS
-- ============================================================

(
  'settings.view',
  'View Settings',
  'settings',
  'view',
  'View system and company settings.',
  true
),

(
  'settings.company.create',
  'Create Company',
  'settings',
  'create',
  'Create a company.',
  true
),

(
  'settings.company.view',
  'View Company',
  'settings',
  'view',
  'View company information.',
  true
),

(
  'settings.company.edit',
  'Edit Company',
  'settings',
  'edit',
  'Edit company information.',
  true
),

(
  'settings.company.delete',
  'Delete Company',
  'settings',
  'delete',
  'Delete a company where permitted.',
  true
),

(
  'settings.branch.create',
  'Create Branch',
  'settings',
  'create',
  'Create a company branch.',
  true
),

(
  'settings.branch.view',
  'View Branch',
  'settings',
  'view',
  'View branch information.',
  true
),

(
  'settings.branch.edit',
  'Edit Branch',
  'settings',
  'edit',
  'Edit branch information.',
  true
),

(
  'settings.branch.delete',
  'Delete Branch',
  'settings',
  'delete',
  'Delete a branch where permitted.',
  true
),

(
  'settings.master.view',
  'View Master Data',
  'settings',
  'view',
  'View universal and application master data.',
  true
),

(
  'settings.master.manage',
  'Manage Master Data',
  'settings',
  'manage',
  'Create, edit, activate and deactivate master data.',
  true
),


-- ============================================================
-- SECURITY / ADMINISTRATION
-- ============================================================

(
  'security.user.view',
  'View Users',
  'security',
  'view',
  'View Elvaris application users.',
  true
),

(
  'security.user.create',
  'Create User',
  'security',
  'create',
  'Create an application user profile.',
  true
),

(
  'security.user.edit',
  'Edit User',
  'security',
  'edit',
  'Edit an application user profile.',
  true
),

(
  'security.user.deactivate',
  'Deactivate User',
  'security',
  'deactivate',
  'Deactivate an application user.',
  true
),

(
  'security.role.view',
  'View Roles',
  'security',
  'view',
  'View system roles.',
  true
),

(
  'security.role.manage',
  'Manage Roles',
  'security',
  'manage',
  'Create and modify application roles.',
  true
),

(
  'security.permission.view',
  'View Permissions',
  'security',
  'view',
  'View the application permission catalogue.',
  true
),

(
  'security.company_access.manage',
  'Manage Company Access',
  'security',
  'manage',
  'Assign users to companies.',
  true
),

(
  'security.branch_access.manage',
  'Manage Branch Access',
  'security',
  'manage',
  'Assign users to branches.',
  true
),


-- ============================================================
-- FINANCE
-- ============================================================

(
  'finance.account.view',
  'View Accounts',
  'finance',
  'view',
  'View chart of accounts.',
  true
),

(
  'finance.account.create',
  'Create Account',
  'finance',
  'create',
  'Create a chart-of-accounts record.',
  true
),

(
  'finance.account.edit',
  'Edit Account',
  'finance',
  'edit',
  'Edit a chart-of-accounts record.',
  true
),

(
  'finance.account.deactivate',
  'Deactivate Account',
  'finance',
  'deactivate',
  'Deactivate a chart-of-accounts record.',
  true
),

(
  'finance.journal.view',
  'View Journal Entries',
  'finance',
  'view',
  'View general journal entries.',
  true
),

(
  'finance.journal.create',
  'Create Journal Entry',
  'finance',
  'create',
  'Create a journal entry.',
  true
),

(
  'finance.journal.edit',
  'Edit Journal Entry',
  'finance',
  'edit',
  'Edit a draft journal entry.',
  true
),

(
  'finance.journal.post',
  'Post Journal Entry',
  'finance',
  'post',
  'Post a journal entry to the general ledger.',
  true
),

(
  'finance.journal.void',
  'Void Journal Entry',
  'finance',
  'void',
  'Void an eligible posted journal entry.',
  true
),

(
  'finance.ledger.view',
  'View General Ledger',
  'finance',
  'view',
  'View general ledger activity.',
  true
),

(
  'finance.trial_balance.view',
  'View Trial Balance',
  'finance',
  'view',
  'View trial balance reports.',
  true
),

(
  'finance.pnl.view',
  'View Profit and Loss',
  'finance',
  'view',
  'View profit and loss reports.',
  true
),

(
  'finance.balance_sheet.view',
  'View Balance Sheet',
  'finance',
  'view',
  'View balance sheet reports.',
  true
),

(
  'finance.period.manage',
  'Manage Accounting Periods',
  'finance',
  'manage',
  'Open, lock and close accounting periods.',
  true
),


-- ============================================================
-- CUSTOMER / SALES
-- ============================================================

(
  'sales.customer.view',
  'View Customers',
  'sales',
  'view',
  'View customer records.',
  true
),

(
  'sales.customer.create',
  'Create Customer',
  'sales',
  'create',
  'Create a customer.',
  true
),

(
  'sales.customer.edit',
  'Edit Customer',
  'sales',
  'edit',
  'Edit a customer.',
  true
),

(
  'sales.invoice.view',
  'View Sales Invoices',
  'sales',
  'view',
  'View sales invoices.',
  true
),

(
  'sales.invoice.create',
  'Create Sales Invoice',
  'sales',
  'create',
  'Create a sales invoice.',
  true
),

(
  'sales.invoice.edit',
  'Edit Sales Invoice',
  'sales',
  'edit',
  'Edit an eligible sales invoice.',
  true
),

(
  'sales.invoice.post',
  'Post Sales Invoice',
  'sales',
  'post',
  'Post a sales invoice and its accounting effects.',
  true
),

(
  'sales.receipt.create',
  'Record Customer Receipt',
  'sales',
  'create',
  'Record a customer receipt.',
  true
),

(
  'sales.receipt.view',
  'View Customer Receipts',
  'sales',
  'view',
  'View customer receipts.',
  true
),


-- ============================================================
-- PURCHASING / VENDORS
-- ============================================================

(
  'purchasing.vendor.view',
  'View Vendors',
  'purchasing',
  'view',
  'View vendor records.',
  true
),

(
  'purchasing.vendor.create',
  'Create Vendor',
  'purchasing',
  'create',
  'Create a vendor.',
  true
),

(
  'purchasing.vendor.edit',
  'Edit Vendor',
  'purchasing',
  'edit',
  'Edit a vendor.',
  true
),

(
  'purchasing.purchase_order.view',
  'View Purchase Orders',
  'purchasing',
  'view',
  'View purchase orders.',
  true
),

(
  'purchasing.purchase_order.create',
  'Create Purchase Order',
  'purchasing',
  'create',
  'Create a purchase order.',
  true
),

(
  'purchasing.purchase_order.edit',
  'Edit Purchase Order',
  'purchasing',
  'edit',
  'Edit an eligible purchase order.',
  true
),

(
  'purchasing.bill.view',
  'View Purchase Bills',
  'purchasing',
  'view',
  'View purchase bills.',
  true
),

(
  'purchasing.bill.create',
  'Create Purchase Bill',
  'purchasing',
  'create',
  'Create a purchase bill.',
  true
),

(
  'purchasing.bill.edit',
  'Edit Purchase Bill',
  'purchasing',
  'edit',
  'Edit an eligible purchase bill.',
  true
),

(
  'purchasing.bill.post',
  'Post Purchase Bill',
  'purchasing',
  'post',
  'Post a purchase bill and its accounting effects.',
  true
),

(
  'purchasing.payment.create',
  'Record Vendor Payment',
  'purchasing',
  'create',
  'Record a vendor payment.',
  true
),

(
  'purchasing.payment.view',
  'View Vendor Payments',
  'purchasing',
  'view',
  'View vendor payments.',
  true
),


-- ============================================================
-- INVENTORY
-- ============================================================

(
  'inventory.item.view',
  'View Items',
  'inventory',
  'view',
  'View item master records.',
  true
),

(
  'inventory.item.create',
  'Create Item',
  'inventory',
  'create',
  'Create an item.',
  true
),

(
  'inventory.item.edit',
  'Edit Item',
  'inventory',
  'edit',
  'Edit an item.',
  true
),

(
  'inventory.item.deactivate',
  'Deactivate Item',
  'inventory',
  'deactivate',
  'Deactivate an item.',
  true
),

(
  'inventory.warehouse.view',
  'View Warehouses',
  'inventory',
  'view',
  'View warehouses.',
  true
),

(
  'inventory.warehouse.manage',
  'Manage Warehouses',
  'inventory',
  'manage',
  'Create and modify warehouses.',
  true
),

(
  'inventory.receipt.view',
  'View Stock Receipts',
  'inventory',
  'view',
  'View inventory receipts.',
  true
),

(
  'inventory.receipt.create',
  'Create Stock Receipt',
  'inventory',
  'create',
  'Create an inventory receipt.',
  true
),

(
  'inventory.issue.view',
  'View Stock Issues',
  'inventory',
  'view',
  'View inventory issues.',
  true
),

(
  'inventory.issue.create',
  'Create Stock Issue',
  'inventory',
  'create',
  'Create an inventory issue.',
  true
),

(
  'inventory.return.create',
  'Create Stock Return',
  'inventory',
  'create',
  'Create an inventory return.',
  true
),

(
  'inventory.transfer.create',
  'Create Stock Transfer',
  'inventory',
  'create',
  'Create an inter-warehouse stock transfer.',
  true
),

(
  'inventory.adjustment.create',
  'Create Stock Adjustment',
  'inventory',
  'create',
  'Create an inventory adjustment.',
  true
),

(
  'inventory.ledger.view',
  'View Stock Ledger',
  'inventory',
  'view',
  'View stock ledger activity.',
  true
),

(
  'inventory.valuation.view',
  'View Stock Valuation',
  'inventory',
  'view',
  'View inventory valuation.',
  true
),


-- ============================================================
-- MANUFACTURING
-- ============================================================

(
  'manufacturing.bom.view',
  'View BOMs',
  'manufacturing',
  'view',
  'View bills of material.',
  true
),

(
  'manufacturing.bom.create',
  'Create BOM',
  'manufacturing',
  'create',
  'Create a bill of material.',
  true
),

(
  'manufacturing.bom.edit',
  'Edit BOM',
  'manufacturing',
  'edit',
  'Edit a bill of material.',
  true
),

(
  'manufacturing.work_center.view',
  'View Work Centers',
  'manufacturing',
  'view',
  'View manufacturing work centers.',
  true
),

(
  'manufacturing.work_center.manage',
  'Manage Work Centers',
  'manufacturing',
  'manage',
  'Create and modify work centers.',
  true
),

(
  'manufacturing.production.view',
  'View Production Orders',
  'manufacturing',
  'view',
  'View production orders.',
  true
),

(
  'manufacturing.production.create',
  'Create Production Order',
  'manufacturing',
  'create',
  'Create a production order.',
  true
),

(
  'manufacturing.production.edit',
  'Edit Production Order',
  'manufacturing',
  'edit',
  'Edit an eligible production order.',
  true
),

(
  'manufacturing.production.complete',
  'Complete Production Order',
  'manufacturing',
  'complete',
  'Complete a production order and record outputs.',
  true
),

(
  'manufacturing.scrap.create',
  'Record Production Scrap',
  'manufacturing',
  'create',
  'Record manufacturing scrap.',
  true
),

(
  'manufacturing.costing.view',
  'View Production Costing',
  'manufacturing',
  'view',
  'View production cost calculations.',
  true
),


-- ============================================================
-- REPORTS
-- ============================================================

(
  'reports.view',
  'View Reports',
  'reports',
  'view',
  'View standard Elvaris reports.',
  true
),

(
  'reports.export',
  'Export Reports',
  'reports',
  'export',
  'Export reports to supported formats.',
  true
),


-- ============================================================
-- AUDIT
-- ============================================================

(
  'audit.view',
  'View Audit Log',
  'audit',
  'view',
  'View system audit history.',
  true
)

on conflict (code)
do update set
  name = excluded.name,
  module = excluded.module,
  action = excluded.action,
  description = excluded.description,
  is_active = true;


-- ============================================================
-- 2. SYSTEM ROLES
-- ============================================================

insert into public.roles (
  code,
  name,
  description,
  is_system_role,
  is_active
)
values
(
  'SYSTEM_ADMIN',
  'System Administrator',
  'Full administrative access to the Elvaris system.',
  true,
  true
),
(
  'ACCOUNTANT',
  'Accountant',
  'Accounting, financial reporting and related transaction access.',
  true,
  true
),
(
  'SALES',
  'Sales User',
  'Customer and sales transaction access.',
  true,
  true
),
(
  'PURCHASING',
  'Purchasing User',
  'Vendor and purchasing transaction access.',
  true,
  true
),
(
  'INVENTORY',
  'Inventory User',
  'Inventory and warehouse operation access.',
  true,
  true
),
(
  'MANUFACTURING',
  'Manufacturing User',
  'BOM and production operation access.',
  true,
  true
),
(
  'REPORT_VIEWER',
  'Report Viewer',
  'Read-only access to reports.',
  true,
  true
)

on conflict (code)
do update set
  name = excluded.name,
  description = excluded.description,
  is_system_role = true,
  is_active = true;


-- ============================================================
-- 3. ASSIGN PERMISSIONS TO SYSTEM ADMIN
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
cross join public.permissions p
where r.code = 'SYSTEM_ADMIN'
on conflict do nothing;


-- ============================================================
-- 4. ACCOUNTANT PERMISSIONS
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
join public.permissions p
  on (
    p.module = 'finance'
    or p.code in (
      'dashboard.view',
      'reports.view',
      'reports.export',
      'sales.customer.view',
      'purchasing.vendor.view',
      'inventory.item.view',
      'inventory.ledger.view',
      'inventory.valuation.view'
    )
  )
where r.code = 'ACCOUNTANT'
on conflict do nothing;


-- ============================================================
-- 5. SALES PERMISSIONS
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
join public.permissions p
  on p.code in (
    'dashboard.view',
    'sales.customer.view',
    'sales.customer.create',
    'sales.customer.edit',
    'sales.invoice.view',
    'sales.invoice.create',
    'sales.invoice.edit',
    'sales.invoice.post',
    'sales.receipt.view',
    'sales.receipt.create',
    'inventory.item.view',
    'inventory.warehouse.view',
    'reports.view'
  )
where r.code = 'SALES'
on conflict do nothing;


-- ============================================================
-- 6. PURCHASING PERMISSIONS
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
join public.permissions p
  on p.code in (
    'dashboard.view',
    'purchasing.vendor.view',
    'purchasing.vendor.create',
    'purchasing.vendor.edit',
    'purchasing.purchase_order.view',
    'purchasing.purchase_order.create',
    'purchasing.purchase_order.edit',
    'purchasing.bill.view',
    'purchasing.bill.create',
    'purchasing.bill.edit',
    'purchasing.bill.post',
    'purchasing.payment.view',
    'purchasing.payment.create',
    'inventory.item.view',
    'inventory.warehouse.view',
    'reports.view'
  )
where r.code = 'PURCHASING'
on conflict do nothing;


-- ============================================================
-- 7. INVENTORY PERMISSIONS
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
join public.permissions p
  on p.code in (
    'dashboard.view',
    'inventory.item.view',
    'inventory.item.create',
    'inventory.item.edit',
    'inventory.item.deactivate',
    'inventory.warehouse.view',
    'inventory.warehouse.manage',
    'inventory.receipt.view',
    'inventory.receipt.create',
    'inventory.issue.view',
    'inventory.issue.create',
    'inventory.return.create',
    'inventory.transfer.create',
    'inventory.adjustment.create',
    'inventory.ledger.view',
    'inventory.valuation.view',
    'manufacturing.bom.view',
    'reports.view'
  )
where r.code = 'INVENTORY'
on conflict do nothing;


-- ============================================================
-- 8. MANUFACTURING PERMISSIONS
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
join public.permissions p
  on p.code in (
    'dashboard.view',
    'inventory.item.view',
    'inventory.warehouse.view',
    'inventory.issue.view',
    'inventory.issue.create',
    'inventory.receipt.view',
    'inventory.receipt.create',
    'manufacturing.bom.view',
    'manufacturing.bom.create',
    'manufacturing.bom.edit',
    'manufacturing.work_center.view',
    'manufacturing.work_center.manage',
    'manufacturing.production.view',
    'manufacturing.production.create',
    'manufacturing.production.edit',
    'manufacturing.production.complete',
    'manufacturing.scrap.create',
    'manufacturing.costing.view',
    'reports.view'
  )
where r.code = 'MANUFACTURING'
on conflict do nothing;


-- ============================================================
-- 9. REPORT VIEWER PERMISSIONS
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
join public.permissions p
  on p.code in (
    'dashboard.view',
    'reports.view',
    'reports.export',
    'finance.ledger.view',
    'finance.trial_balance.view',
    'finance.pnl.view',
    'finance.balance_sheet.view',
    'inventory.ledger.view',
    'inventory.valuation.view',
    'manufacturing.costing.view',
    'audit.view'
  )
where r.code = 'REPORT_VIEWER'
on conflict do nothing;


-- ============================================================
-- 10. COMMENTS
-- ============================================================

comment on table public.permissions is
  'Atomic Elvaris application permissions.';

comment on table public.roles is
  'Elvaris system and custom authorization roles.';

comment on table public.role_permissions is
  'Mapping between roles and permissions.';
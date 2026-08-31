-- ============================================================
-- ELVARIS ERP
-- Migration 016
-- System Chart of Accounts Bootstrap
-- ============================================================

create or replace function public.create_system_coa_account(
    p_company_id uuid,
    p_account_code varchar(30),
    p_account_name varchar(150),
    p_account_type_code varchar(50),
    p_detail_type_code varchar(80),
    p_parent_code varchar(30),
    p_account_role public.account_role,
    p_node_type public.account_node_type,
    p_is_control_account boolean,
    p_system_account_code varchar(60),
    p_display_order integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_account_id uuid;
    v_account_type_id uuid;
    v_detail_type_id uuid;
    v_parent_account_id uuid;

    v_parent_depth smallint;
    v_depth smallint;

    v_parent_path text;
    v_path text;

    v_category public.account_category;

    v_existing_system_code varchar(60);
    v_existing_account_name varchar(150);

begin

    select
        at.id,
        at.account_category
    into
        v_account_type_id,
        v_category
    from public.account_types at
    where at.code = p_account_type_code
      and at.is_active = true
      and at.is_legacy = false
    limit 1;


    if v_account_type_id is null then
        raise exception
            'Account type "%" was not found.',
            p_account_type_code;
    end if;


    if p_detail_type_code is not null then

        select adt.id
        into v_detail_type_id
        from public.account_detail_types adt
        where adt.account_category = v_category
          and adt.code = p_detail_type_code
          and adt.is_active = true
        limit 1;

        if v_detail_type_id is null then
            raise exception
                'Detail type "%" was not found for category "%".',
                p_detail_type_code,
                v_category;
        end if;

    else

        v_detail_type_id := null;

    end if;


    if p_parent_code is not null then

        select
            coa.id,
            coalesce(coa.account_depth, 0),
            coa.account_path
        into
            v_parent_account_id,
            v_parent_depth,
            v_parent_path
        from public.chart_of_accounts coa
        where coa.company_id = p_company_id
          and coa.account_code = p_parent_code
        limit 1;


        if v_parent_account_id is null then
            raise exception
                'Parent account "%" was not found for company %.',
                p_parent_code,
                p_company_id;
        end if;


        v_depth =
            coalesce(v_parent_depth, 0) + 1;

        v_path =
            coalesce(
                nullif(trim(v_parent_path), ''),
                p_parent_code
            )
            || '.'
            || p_account_code;

    else

        v_depth := 0;
        v_path := p_account_code;

    end if;


    select
        coa.id,
        coa.system_account_code,
        coa.account_name
    into
        v_account_id,
        v_existing_system_code,
        v_existing_account_name
    from public.chart_of_accounts coa
    where coa.company_id = p_company_id
      and coa.account_code = p_account_code
    limit 1;


    if v_account_id is not null then

        if v_existing_system_code is not null
           and v_existing_system_code <> p_system_account_code
        then

            raise exception
                'Account code "%" already belongs to system account "%". It cannot be reassigned to "%".',
                p_account_code,
                v_existing_system_code,
                p_system_account_code;

        end if;


        if v_existing_system_code is null then

            if lower(trim(coalesce(v_existing_account_name, '')))
               <> lower(trim(p_account_name))
            then

                raise exception
                    'Account code "%" already exists with account name "%", but system account "%" expects "%". Existing account was not changed.',
                    p_account_code,
                    coalesce(v_existing_account_name, ''),
                    p_system_account_code,
                    p_account_name;

            end if;

        end if;


        update public.chart_of_accounts
        set
            account_type_id = v_account_type_id,
            parent_account_id = v_parent_account_id,
            account_name = p_account_name,
            is_header = (p_account_role = 'header'),
            is_posting = (p_account_role <> 'header'),
            is_control_account = p_is_control_account,
            system_account_code = p_system_account_code,
            allow_manual_posting = (p_account_role <> 'header'),
            detail_type_id = v_detail_type_id,
            account_role = p_account_role,
            display_order = p_display_order,
            account_depth = v_depth,
            account_path = v_path,
            is_active = true,
            node_type = p_node_type,
            is_system_account = true,
            is_locked = true,
            updated_at = now()
        where id = v_account_id;

    else

        insert into public.chart_of_accounts (
            company_id,
            account_type_id,
            parent_account_id,
            account_code,
            account_name,
            description,
            is_header,
            is_posting,
            is_control_account,
            system_account_code,
            allow_manual_posting,
            currency_id,
            detail_type_id,
            account_role,
            display_order,
            account_depth,
            account_path,
            is_active,
            node_type,
            is_system_account,
            is_locked
        )
        values (
            p_company_id,
            v_account_type_id,
            v_parent_account_id,
            p_account_code,
            p_account_name,
            null,
            (p_account_role = 'header'),
            (p_account_role <> 'header'),
            p_is_control_account,
            p_system_account_code,
            (p_account_role <> 'header'),
            null,
            v_detail_type_id,
            p_account_role,
            p_display_order,
            v_depth,
            v_path,
            true,
            p_node_type,
            true,
            true
        )
        returning id
        into v_account_id;

    end if;


    return v_account_id;

end;
$function$;


-- ============================================================
-- BOOTSTRAP EVERY COMPANY
-- ============================================================

do $block$

declare
    v_company record;

begin

    for v_company in
        select
            c.id,
            c.company_code
        from public.companies c
        order by c.company_code
    loop


        -- ====================================================
        -- ASSETS
        -- ====================================================

        perform public.create_system_coa_account(
            v_company.id,
            '1000',
            'Assets',
            'BANK',
            null,
            null,
            'header',
            'report_group',
            false,
            'assets_group',
            100
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1100',
            'Cash and Cash Equivalents',
            'BANK',
            null,
            '1000',
            'header',
            'report_group',
            false,
            'cash_group',
            110
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1110',
            'Cash on Hand',
            'BANK',
            'cash_on_hand',
            '1100',
            'posting',
            'account',
            false,
            'cash_on_hand',
            111
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1120',
            'Petty Cash',
            'BANK',
            'petty_cash',
            '1100',
            'posting',
            'account',
            false,
            'petty_cash',
            112
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1130',
            'Main Bank',
            'BANK',
            'checking',
            '1100',
            'posting',
            'account',
            false,
            'main_bank',
            113
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1200',
            'Accounts Receivable',
            'ACCOUNTS_RECEIVABLE',
            'trade_receivables',
            '1000',
            'control',
            'account',
            true,
            'accounts_receivable',
            120
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1300',
            'Other Current Assets',
            'OTHER_CURRENT_ASSET',
            null,
            '1000',
            'header',
            'report_group',
            false,
            'current_assets_group',
            130
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1310',
            'Raw Materials Inventory',
            'OTHER_CURRENT_ASSET',
            'inventory_asset',
            '1300',
            'posting',
            'account',
            false,
            'raw_material_inventory',
            131
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1320',
            'Work in Process Inventory',
            'OTHER_CURRENT_ASSET',
            'inventory_asset',
            '1300',
            'posting',
            'account',
            false,
            'wip_inventory',
            132
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1330',
            'Finished Goods Inventory',
            'OTHER_CURRENT_ASSET',
            'inventory_asset',
            '1300',
            'posting',
            'account',
            false,
            'finished_goods_inventory',
            133
        );


        -- 1340 IS RESERVED FOR THE ALREADY-ESTABLISHED
        -- UNDEPOSITED FUNDS SYSTEM ACCOUNT.

        perform public.create_system_coa_account(
            v_company.id,
            '1340',
            'Undeposited Funds',
            'OTHER_CURRENT_ASSET',
            'undeposited_funds',
            '1300',
            'posting',
            'account',
            false,
            'undeposited_funds',
            134
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1350',
            'Prepaid Expenses',
            'OTHER_CURRENT_ASSET',
            'prepaid_expenses',
            '1300',
            'posting',
            'account',
            false,
            'prepaid_expenses',
            135
        );


        -- 1370 IS DELIBERATELY USED FOR SCRAP INVENTORY
        -- SO 1340 IS NEVER REASSIGNED.

        perform public.create_system_coa_account(
            v_company.id,
            '1370',
            'Scrap and By-Products Inventory',
            'OTHER_CURRENT_ASSET',
            'inventory_asset',
            '1300',
            'posting',
            'account',
            false,
            'scrap_inventory',
            137
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1500',
            'Fixed Assets',
            'FIXED_ASSET',
            null,
            '1000',
            'header',
            'report_group',
            false,
            'fixed_assets_group',
            150
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1510',
            'Buildings',
            'FIXED_ASSET',
            'buildings',
            '1500',
            'posting',
            'account',
            false,
            'buildings',
            151
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1520',
            'Machinery and Equipment',
            'FIXED_ASSET',
            'machinery_equipment',
            '1500',
            'posting',
            'account',
            false,
            'machinery_equipment',
            152
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1530',
            'Vehicles',
            'FIXED_ASSET',
            'vehicles',
            '1500',
            'posting',
            'account',
            false,
            'vehicles',
            153
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1540',
            'Furniture and Fixtures',
            'FIXED_ASSET',
            'furniture_fixtures',
            '1500',
            'posting',
            'account',
            false,
            'furniture_fixtures',
            154
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1550',
            'Computer Equipment',
            'FIXED_ASSET',
            'computer_equipment',
            '1500',
            'posting',
            'account',
            false,
            'computer_equipment',
            155
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1600',
            'Other Assets',
            'OTHER_ASSET',
            null,
            '1000',
            'header',
            'report_group',
            false,
            'other_assets_group',
            160
        );


        perform public.create_system_coa_account(
            v_company.id,
            '1610',
            'Security Deposits',
            'OTHER_ASSET',
            'security_deposits',
            '1600',
            'posting',
            'account',
            false,
            'security_deposits',
            161
        );


        -- ====================================================
        -- LIABILITIES
        -- ====================================================

        perform public.create_system_coa_account(
            v_company.id,
            '2000',
            'Liabilities',
            'LONG_TERM_LIABILITY',
            null,
            null,
            'header',
            'report_group',
            false,
            'liabilities_group',
            200
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2100',
            'Accounts Payable',
            'ACCOUNTS_PAYABLE',
            'trade_payables',
            '2000',
            'control',
            'account',
            true,
            'accounts_payable',
            210
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2200',
            'Other Current Liabilities',
            'OTHER_CURRENT_LIABILITY',
            null,
            '2000',
            'header',
            'report_group',
            false,
            'current_liabilities_group',
            220
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2210',
            'Sales Tax Payable',
            'OTHER_CURRENT_LIABILITY',
            'sales_tax_payable',
            '2200',
            'posting',
            'account',
            false,
            'sales_tax_payable',
            221
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2220',
            'Payroll Tax Payable',
            'OTHER_CURRENT_LIABILITY',
            'payroll_tax_payable',
            '2200',
            'posting',
            'account',
            false,
            'payroll_tax_payable',
            222
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2230',
            'Accrued Expenses',
            'OTHER_CURRENT_LIABILITY',
            'accrued_expenses',
            '2200',
            'posting',
            'account',
            false,
            'accrued_expenses',
            223
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2300',
            'Long-Term Liabilities',
            'LONG_TERM_LIABILITY',
            null,
            '2000',
            'header',
            'report_group',
            false,
            'long_term_liabilities_group',
            230
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2310',
            'Long-Term Loans',
            'LONG_TERM_LIABILITY',
            'long_term_loan',
            '2300',
            'posting',
            'account',
            false,
            'long_term_loans',
            231
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2320',
            'Mortgage',
            'LONG_TERM_LIABILITY',
            'mortgage',
            '2300',
            'posting',
            'account',
            false,
            'mortgage',
            232
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2330',
            'Notes Payable',
            'LONG_TERM_LIABILITY',
            'notes_payable',
            '2300',
            'posting',
            'account',
            false,
            'notes_payable',
            233
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2400',
            'Credit Cards',
            'CREDIT_CARD',
            null,
            '2000',
            'header',
            'report_group',
            false,
            'credit_cards_group',
            240
        );


        perform public.create_system_coa_account(
            v_company.id,
            '2410',
            'Company Credit Card',
            'CREDIT_CARD',
            'credit_card_account',
            '2400',
            'posting',
            'account',
            false,
            'credit_card',
            241
        );


        -- ====================================================
        -- EQUITY
        -- ====================================================

        perform public.create_system_coa_account(
            v_company.id,
            '3000',
            'Equity',
            'EQUITY',
            null,
            null,
            'header',
            'report_group',
            false,
            'equity_group',
            300
        );


        perform public.create_system_coa_account(
            v_company.id,
            '3100',
            'Owner Equity',
            'EQUITY',
            'owner_equity',
            '3000',
            'posting',
            'account',
            false,
            'owner_equity',
            310
        );


        perform public.create_system_coa_account(
            v_company.id,
            '3200',
            'Owner Draw',
            'EQUITY',
            'owner_draw',
            '3000',
            'posting',
            'account',
            false,
            'owner_draw',
            320
        );


        perform public.create_system_coa_account(
            v_company.id,
            '3300',
            'Retained Earnings',
            'EQUITY',
            'retained_earnings',
            '3000',
            'posting',
            'account',
            false,
            'retained_earnings',
            330
        );


        perform public.create_system_coa_account(
            v_company.id,
            '3400',
            'Opening Balance Equity',
            'EQUITY',
            'opening_balance_equity',
            '3000',
            'posting',
            'account',
            false,
            'opening_balance_equity',
            340
        );


        -- ====================================================
        -- INCOME
        -- ====================================================

        perform public.create_system_coa_account(
            v_company.id,
            '4000',
            'Income',
            'INCOME',
            null,
            null,
            'header',
            'report_group',
            false,
            'income_group',
            400
        );


        perform public.create_system_coa_account(
            v_company.id,
            '4100',
            'Sales Income',
            'INCOME',
            'sales_income',
            '4000',
            'posting',
            'account',
            false,
            'sales_income',
            410
        );


        perform public.create_system_coa_account(
            v_company.id,
            '4200',
            'Service Income',
            'INCOME',
            'service_income',
            '4000',
            'posting',
            'account',
            false,
            'service_income',
            420
        );


        -- ====================================================
        -- COST OF GOODS SOLD
        -- ====================================================

        perform public.create_system_coa_account(
            v_company.id,
            '5000',
            'Cost of Goods Sold',
            'COST_OF_GOODS_SOLD',
            null,
            null,
            'header',
            'report_group',
            false,
            'cogs_group',
            500
        );


        perform public.create_system_coa_account(
            v_company.id,
            '5100',
            'Materials',
            'COST_OF_GOODS_SOLD',
            'materials',
            '5000',
            'posting',
            'account',
            false,
            'materials_cogs',
            510
        );


        perform public.create_system_coa_account(
            v_company.id,
            '5200',
            'Direct Labor',
            'COST_OF_GOODS_SOLD',
            'direct_labor',
            '5000',
            'posting',
            'account',
            false,
            'direct_labor_cogs',
            520
        );


        perform public.create_system_coa_account(
            v_company.id,
            '5300',
            'Manufacturing Overhead',
            'COST_OF_GOODS_SOLD',
            'manufacturing_overhead',
            '5000',
            'posting',
            'account',
            false,
            'manufacturing_overhead_cogs',
            530
        );


        perform public.create_system_coa_account(
            v_company.id,
            '5400',
            'Cost of Sales',
            'COST_OF_GOODS_SOLD',
            'cost_of_sales',
            '5000',
            'posting',
            'account',
            false,
            'cost_of_sales',
            540
        );


        -- ====================================================
        -- OPERATING EXPENSES
        -- ====================================================

        perform public.create_system_coa_account(
            v_company.id,
            '6000',
            'Expenses',
            'EXPENSE',
            null,
            null,
            'header',
            'report_group',
            false,
            'expense_group',
            600
        );


        perform public.create_system_coa_account(
            v_company.id,
            '6100',
            'Advertising',
            'EXPENSE',
            'advertising',
            '6000',
            'posting',
            'account',
            false,
            'advertising_expense',
            610
        );


        perform public.create_system_coa_account(
            v_company.id,
            '6200',
            'Rent',
            'EXPENSE',
            'rent',
            '6000',
            'posting',
            'account',
            false,
            'rent_expense',
            620
        );


        perform public.create_system_coa_account(
            v_company.id,
            '6300',
            'Utilities',
            'EXPENSE',
            'utilities',
            '6000',
            'posting',
            'account',
            false,
            'utilities_expense',
            630
        );


        perform public.create_system_coa_account(
            v_company.id,
            '6400',
            'Office Supplies',
            'EXPENSE',
            'office_supplies',
            '6000',
            'posting',
            'account',
            false,
            'office_supplies_expense',
            640
        );


        perform public.create_system_coa_account(
            v_company.id,
            '6500',
            'Payroll Expense',
            'EXPENSE',
            'payroll_expense',
            '6000',
            'posting',
            'account',
            false,
            'payroll_expense',
            650
        );


        perform public.create_system_coa_account(
            v_company.id,
            '6600',
            'Depreciation Expense',
            'EXPENSE',
            'depreciation',
            '6000',
            'posting',
            'account',
            false,
            'depreciation_expense',
            660
        );


        -- ====================================================
        -- OTHER INCOME
        -- ====================================================

        perform public.create_system_coa_account(
            v_company.id,
            '7000',
            'Other Income',
            'OTHER_INCOME',
            null,
            null,
            'header',
            'report_group',
            false,
            'other_income_group',
            700
        );


        perform public.create_system_coa_account(
            v_company.id,
            '7100',
            'Interest Income',
            'OTHER_INCOME',
            'interest_income',
            '7000',
            'posting',
            'account',
            false,
            'interest_income',
            710
        );


        perform public.create_system_coa_account(
            v_company.id,
            '7200',
            'Gain on Asset Sale',
            'OTHER_INCOME',
            'gain_on_asset_sale',
            '7000',
            'posting',
            'account',
            false,
            'gain_on_asset_sale',
            720
        );


        -- ====================================================
        -- OTHER EXPENSE
        -- ====================================================

        perform public.create_system_coa_account(
            v_company.id,
            '8000',
            'Other Expense',
            'OTHER_EXPENSE',
            null,
            null,
            'header',
            'report_group',
            false,
            'other_expense_group',
            800
        );


        perform public.create_system_coa_account(
            v_company.id,
            '8100',
            'Interest Expense',
            'OTHER_EXPENSE',
            'interest_expense',
            '8000',
            'posting',
            'account',
            false,
            'interest_expense',
            810
        );


        perform public.create_system_coa_account(
            v_company.id,
            '8200',
            'Loss on Asset Sale',
            'OTHER_EXPENSE',
            'loss_on_asset_sale',
            '8000',
            'posting',
            'account',
            false,
            'loss_on_asset_sale',
            820
        );


        perform public.create_system_coa_account(
            v_company.id,
            '8300',
            'Bank Charges',
            'OTHER_EXPENSE',
            'bank_charges',
            '8000',
            'posting',
            'account',
            false,
            'bank_charges',
            830
        );


        -- ====================================================
        -- SYSTEM AND CLEARING
        -- ====================================================

        perform public.create_system_coa_account(
            v_company.id,
            '9000',
            'System and Clearing',
            'OTHER_CURRENT_ASSET',
            null,
            null,
            'header',
            'report_group',
            false,
            'system_clearing_group',
            900
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9100',
            'Suspense Accounts',
            'OTHER_CURRENT_ASSET',
            null,
            '9000',
            'header',
            'report_group',
            false,
            'suspense_group',
            910
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9110',
            'General Suspense',
            'OTHER_CURRENT_ASSET',
            null,
            '9100',
            'posting',
            'account',
            false,
            'general_suspense',
            911
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9120',
            'Unassigned Receipt Suspense',
            'OTHER_CURRENT_ASSET',
            null,
            '9100',
            'posting',
            'account',
            false,
            'unassigned_receipt_suspense',
            912
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9130',
            'Unassigned Payment Suspense',
            'OTHER_CURRENT_ASSET',
            null,
            '9100',
            'posting',
            'account',
            false,
            'unassigned_payment_suspense',
            913
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9140',
            'Bank Reconciliation Suspense',
            'OTHER_CURRENT_ASSET',
            null,
            '9100',
            'posting',
            'account',
            false,
            'bank_reconciliation_suspense',
            914
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9200',
            'Inventory Clearing',
            'OTHER_CURRENT_ASSET',
            null,
            '9000',
            'header',
            'report_group',
            false,
            'inventory_clearing_group',
            920
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9210',
            'Goods Received Not Invoiced',
            'OTHER_CURRENT_LIABILITY',
            null,
            '9200',
            'posting',
            'account',
            false,
            'goods_received_not_invoiced',
            921
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9220',
            'Inventory Receipt Clearing',
            'OTHER_CURRENT_ASSET',
            null,
            '9200',
            'posting',
            'account',
            false,
            'inventory_receipt_clearing',
            922
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9230',
            'Inventory Issue Clearing',
            'OTHER_CURRENT_ASSET',
            null,
            '9200',
            'posting',
            'account',
            false,
            'inventory_issue_clearing',
            923
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9300',
            'Opening and Migration Clearing',
            'EQUITY',
            null,
            '9000',
            'header',
            'report_group',
            false,
            'opening_migration_group',
            930
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9310',
            'Opening Balance Clearing',
            'EQUITY',
            'opening_balance_equity',
            '9300',
            'posting',
            'account',
            false,
            'opening_balance_clearing',
            931
        );


        perform public.create_system_coa_account(
            v_company.id,
            '9320',
            'Migration Clearing',
            'EQUITY',
            'opening_balance_equity',
            '9300',
            'posting',
            'account',
            false,
            'migration_clearing',
            932
        );

    end loop;

end
$block$;


-- ============================================================
-- VALIDATION
-- ============================================================

do $validation$

declare
    v_company record;

begin

    for v_company in
        select
            c.id,
            c.company_code
        from public.companies c
        order by c.company_code
    loop

        if not exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and system_account_code = 'accounts_receivable'
              and account_role = 'control'
              and is_system_account = true
        ) then
            raise exception
                'Accounts Receivable system account missing for company "%".',
                v_company.company_code;
        end if;


        if not exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and system_account_code = 'accounts_payable'
              and account_role = 'control'
              and is_system_account = true
        ) then
            raise exception
                'Accounts Payable system account missing for company "%".',
                v_company.company_code;
        end if;


        if not exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and system_account_code = 'raw_material_inventory'
              and is_system_account = true
        ) then
            raise exception
                'Raw Materials Inventory system account missing for company "%".',
                v_company.company_code;
        end if;


        if not exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and system_account_code = 'wip_inventory'
              and is_system_account = true
        ) then
            raise exception
                'WIP Inventory system account missing for company "%".',
                v_company.company_code;
        end if;


        if not exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and system_account_code = 'finished_goods_inventory'
              and is_system_account = true
        ) then
            raise exception
                'Finished Goods Inventory system account missing for company "%".',
                v_company.company_code;
        end if;


        if not exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and system_account_code = 'scrap_inventory'
              and is_system_account = true
        ) then
            raise exception
                'Scrap Inventory system account missing for company "%".',
                v_company.company_code;
        end if;


        if not exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and system_account_code = 'undeposited_funds'
              and account_code = '1340'
              and is_system_account = true
        ) then
            raise exception
                'Undeposited Funds must remain account 1340 for company "%".',
                v_company.company_code;
        end if;


        if not exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and system_account_code = 'general_suspense'
              and is_system_account = true
        ) then
            raise exception
                'General Suspense system account missing for company "%".',
                v_company.company_code;
        end if;


        if not exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and system_account_code = 'opening_balance_equity'
              and is_system_account = true
        ) then
            raise exception
                'Opening Balance Equity system account missing for company "%".',
                v_company.company_code;
        end if;


        if exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and is_system_account = true
              and is_locked = false
        ) then
            raise exception
                'A system account is not locked for company "%".',
                v_company.company_code;
        end if;


        if exists (
            select 1
            from public.chart_of_accounts
            where company_id = v_company.id
              and is_system_account = true
              and account_role = 'header'
              and (
                  is_posting = true
                  or allow_manual_posting = true
              )
        ) then
            raise exception
                'A system header is incorrectly configured as posting for company "%".',
                v_company.company_code;
        end if;

    end loop;

end
$validation$;


-- ============================================================
-- HIERARCHICAL STRUCTURE VIEW
-- ============================================================

create or replace view public.chart_of_accounts_structure
as

with recursive account_tree as (

    select
        coa.id,
        coa.company_id,
        coa.parent_account_id,
        coa.account_code,
        coa.account_name,
        coa.account_role,
        coa.node_type,
        coa.account_depth,
        coa.account_path,
        coa.is_header,
        coa.is_posting,
        coa.is_control_account,
        coa.system_account_code,
        coa.is_system_account,
        coa.is_locked,
        coa.display_order,
        array[coa.id] as ancestry
    from public.chart_of_accounts coa
    where coa.parent_account_id is null


    union all


    select
        child.id,
        child.company_id,
        child.parent_account_id,
        child.account_code,
        child.account_name,
        child.account_role,
        child.node_type,
        child.account_depth,
        child.account_path,
        child.is_header,
        child.is_posting,
        child.is_control_account,
        child.system_account_code,
        child.is_system_account,
        child.is_locked,
        child.display_order,
        parent.ancestry || child.id
    from public.chart_of_accounts child
    join account_tree parent
      on parent.id = child.parent_account_id
    where not child.id = any(parent.ancestry)

)

select
    id,
    company_id,
    parent_account_id,
    account_code,
    account_name,
    account_role,
    node_type,
    account_depth,
    account_path,
    is_header,
    is_posting,
    is_control_account,
    system_account_code,
    is_system_account,
    is_locked,
    display_order
from account_tree;


comment on function public.create_system_coa_account(
    uuid,
    varchar,
    varchar,
    varchar,
    varchar,
    varchar,
    public.account_role,
    public.account_node_type,
    boolean,
    varchar,
    integer
)
is
    'Creates, adopts, or repairs an Elvaris system Chart of Accounts account without silently changing an unrelated account.';


comment on view public.chart_of_accounts_structure
is
    'Hierarchical Elvaris Chart of Accounts structure for navigation and reporting.';
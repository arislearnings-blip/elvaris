import {
  supabase,
} from '../lib/supabaseClient'


export type JournalStatus =
  | 'draft'
  | 'posted'
  | 'reversed'
  | 'void'


export type JournalSourceType =
  | 'general_journal'
  | 'sales'
  | 'purchase'
  | 'receipt'
  | 'payment'
  | 'inventory'
  | 'manufacturing'
  | 'payroll'
  | 'fixed_asset'
  | 'bank'
  | 'opening_balance'
  | 'adjustment'
  | 'system'


export type JournalLine = {
  id?: string
  line_number?: number

  account_id: string
  account_code?: string
  account_name?: string
  account_role?:
    | 'header'
    | 'posting'
    | 'control'

  name_id?: string | null
  name_code?: string | null
  name_type?:
    | 'customer'
    | 'vendor'
    | 'employee'
    | 'other'
    | null

  name_display?: string | null

  description?: string

  debit: number
  credit: number

  branch_id?: string | null
  department_id?: string | null
}


export type JournalHeader = {
  id: string
  company_id: string
  branch_id: string | null
  journal_number: string
  entry_date: string
  source_type: JournalSourceType
  reference_type: string | null
  reference_number: string | null
  description: string | null
  status: JournalStatus
  currency_id: string | null
  exchange_rate: number
  fiscal_year_id: string | null
  accounting_period_id: string | null
  is_reversal: boolean
  reverses_entry_id: string | null
  reversed_by_entry_id: string | null
  posted_at: string | null
  posted_by: string | null
  created_at: string
  created_by: string | null
  updated_at: string
  updated_by: string | null
}


export type JournalTransaction = {
  header: JournalHeader
  lines: JournalLine[]
  line_count?: number
}


export type JournalGridTotals = {
  line_count: number
  total_debit: number
  total_credit: number
  difference: number
  is_balanced: boolean
}


export type AccountingNameSearchResult = {
  id: string
  name_code: string
  name_type:
    | 'customer'
    | 'vendor'
    | 'employee'
    | 'other'
  display_name: string
  legal_name: string | null
  phone: string | null
  email: string | null
}


export type AccountSearchResult = {
  id: string
  company_id: string
  account_code: string
  account_name: string
  account_role:
    | 'header'
    | 'posting'
    | 'control'
  node_type:
    | 'report_group'
    | 'account'
  is_posting: boolean
  is_control_account: boolean
  is_active: boolean
  name_requirement:
    | 'optional'
    | 'required'
  allow_name: boolean
}


export type JournalReferenceResult = {
  journal_entry_id: string
  journal_number: string
  reference_type: string | null
  reference_type_name:
    | string
    | null
  reference_number: string | null
  entry_date: string
  status: JournalStatus
  description: string | null
}


export type JournalSearchResult = {
  id: string
  journal_number: string
  entry_date: string
  reference_type: string | null
  reference_type_name: string | null
  reference_number: string | null
  description: string | null
  status: JournalStatus
  line_count: number
  total_debit: number
  total_credit: number
}


export type CreateJournalTransactionInput = {
  companyId: string
  entryDate: string
  description?: string | null
  branchId?: string | null
  sourceType?: JournalSourceType
  currencyId?: string | null
  referenceType?: string | null
  referenceNumber?: string | null
  manualJournalNumber?: string | null
}


export type SaveJournalTransactionInput = {
  journalEntryId: string
  entryDate: string
  description?: string | null
  branchId?: string | null
  referenceType?: string | null
  referenceNumber?: string | null
  lines: JournalLine[]
}


export type CreateAccountingNameInput = {
  companyId: string
  nameType:
    | 'customer'
    | 'vendor'
    | 'employee'
    | 'other'
  displayName: string
  nameCode?: string | null
  legalName?: string | null
  phone?: string | null
  email?: string | null
}


function normalizeError(
  error: unknown,
): Error {
  if (
    error instanceof Error
  ) {
    return error
  }

  if (
    typeof error === 'object' &&
    error !== null &&
    'message' in error &&
    typeof (
      error as {
        message?: unknown
      }
    ).message === 'string'
  ) {
    return new Error(
      (
        error as {
          message: string
        }
      ).message,
    )
  }

  return new Error(
    'An unexpected accounting service error occurred.',
  )
}


function assertNoRpcError(
  error: unknown,
): void {
  if (error) {
    throw normalizeError(
      error,
    )
  }
}


function asRecordArray(
  data: unknown,
): Array<
  Record<string, unknown>
> {
  if (
    !Array.isArray(data)
  ) {
    return []
  }

  return data.filter(
    (
      row,
    ): row is Record<
      string,
      unknown
    > =>
      typeof row ===
        'object' &&
      row !== null,
  )
}


function mapLine(
  line: JournalLine,
): Record<string, unknown> {
  return {
    account_id:
      line.account_id,

    name_id:
      line.name_id ??
      null,

    description:
      line.description ??
      '',

    debit:
      Number(
        line.debit,
      ) || 0,

    credit:
      Number(
        line.credit,
      ) || 0,

    branch_id:
      line.branch_id ??
      null,

    department_id:
      line.department_id ??
      null,
  }
}


/* ============================================================
   CREATE JOURNAL
============================================================ */

export async function createJournalTransaction(
  input: CreateJournalTransactionInput,
): Promise<string> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'create_journal_transaction',
      {
        p_company_id:
          input.companyId,

        p_entry_date:
          input.entryDate,

        p_description:
          input.description ??
          null,

        p_branch_id:
          input.branchId ??
          null,

        p_source_type:
          input.sourceType ??
          'general_journal',

        p_currency_id:
          input.currencyId ??
          null,

        p_reference_type:
          input.referenceType ??
          null,

        p_reference_number:
          input.referenceNumber ??
          null,

        p_manual_journal_number:
          input.manualJournalNumber ??
          null,
      },
    )

  assertNoRpcError(
    error,
  )

  if (!data) {
    throw new Error(
      'Journal transaction could not be created.',
    )
  }

  return String(
    data,
  )
}


/* ============================================================
   LOAD JOURNAL
============================================================ */

export async function loadJournalTransaction(
  journalEntryId: string,
): Promise<JournalTransaction> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'load_journal_transaction',
      {
        p_journal_entry_id:
          journalEntryId,
      },
    )

  assertNoRpcError(
    error,
  )

  if (!data) {
    throw new Error(
      'Journal transaction could not be loaded.',
    )
  }

  return data as JournalTransaction
}


/* ============================================================
   SAVE JOURNAL
============================================================ */

export async function saveJournalTransaction(
  input: SaveJournalTransactionInput,
): Promise<JournalTransaction> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'save_journal_transaction',
      {
        p_journal_entry_id:
          input.journalEntryId,

        p_entry_date:
          input.entryDate,

        p_description:
          input.description ??
          null,

        p_branch_id:
          input.branchId ??
          null,

        p_reference_type:
          input.referenceType ??
          null,

        p_reference_number:
          input.referenceNumber ??
          null,

        p_lines:
          input.lines.map(
            mapLine,
          ),
      },
    )

  assertNoRpcError(
    error,
  )

  if (!data) {
    throw new Error(
      'Journal transaction could not be saved.',
    )
  }

  return data as JournalTransaction
}


/* ============================================================
   POST JOURNAL
============================================================ */

export async function postJournalTransaction(
  journalEntryId: string,
): Promise<JournalTransaction> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'post_journal_transaction',
      {
        p_journal_entry_id:
          journalEntryId,
      },
    )

  assertNoRpcError(
    error,
  )

  if (!data) {
    throw new Error(
      'Journal transaction could not be posted.',
    )
  }

  return data as JournalTransaction
}


/* ============================================================
   DELETE DRAFT
============================================================ */

export async function deleteJournalTransaction(
  journalEntryId: string,
): Promise<boolean> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'delete_journal_transaction',
      {
        p_journal_entry_id:
          journalEntryId,
      },
    )

  assertNoRpcError(
    error,
  )

  return Boolean(
    data,
  )
}


/* ============================================================
   REVERSE
============================================================ */

export async function reverseJournalTransaction(
  journalEntryId: string,
  reversalDate: string,
  description?: string | null,
): Promise<JournalTransaction> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'reverse_journal_transaction',
      {
        p_journal_entry_id:
          journalEntryId,

        p_reversal_date:
          reversalDate,

        p_description:
          description ??
          null,
      },
    )

  assertNoRpcError(
    error,
  )

  if (!data) {
    throw new Error(
      'Journal transaction could not be reversed.',
    )
  }

  return data as JournalTransaction
}


/* ============================================================
   GRID TOTALS
============================================================ */

export async function getJournalGridTotals(
  journalEntryId: string,
): Promise<JournalGridTotals> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'get_journal_grid_totals',
      {
        p_journal_entry_id:
          journalEntryId,
      },
    )

  assertNoRpcError(
    error,
  )

  if (!data) {
    throw new Error(
      'Journal totals could not be loaded.',
    )
  }

  const value =
    Array.isArray(data)
      ? data[0]
      : data

  const row =
    (
      typeof value ===
        'object' &&
      value !== null
    )
      ? value as Record<
          string,
          unknown
        >
      : {}

  return {
    line_count:
      Number(
        row.line_count ??
          0,
      ),

    total_debit:
      Number(
        row.total_debit ??
          0,
      ),

    total_credit:
      Number(
        row.total_credit ??
          0,
      ),

    difference:
      Number(
        row.difference ??
          0,
      ),

    is_balanced:
      Boolean(
        row.is_balanced,
      ),
  }
}


/* ============================================================
   SEARCH JOURNAL TRANSACTIONS
============================================================ */

export async function searchJournalTransactions(
  companyId: string,
  search = '',
  status:
    | JournalStatus
    | null = null,
  referenceType:
    | string
    | null = null,
  limit = 100,
) {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'search_journal_transactions',
      {
        p_company_id:
          companyId,

        p_search:
          search ||
          null,

        p_status:
          status,

        p_reference_type:
          referenceType,

        p_limit:
          limit,
      },
    )

  assertNoRpcError(
    error,
  )

  return asRecordArray(
    data,
  ).map(
    (
      row,
    ) => ({
      id:
        String(
          row.id,
        ),

      journal_number:
        String(
          row.journal_number ??
            '',
        ),

      entry_date:
        String(
          row.entry_date ??
            '',
        ),

      reference_type:
        row.reference_type ==
        null
          ? null
          : String(
              row.reference_type,
            ),

      reference_number:
        row.reference_number ==
        null
          ? null
          : String(
              row.reference_number,
            ),

      description:
        row.description ==
        null
          ? null
          : String(
              row.description,
            ),

      status:
        row.status as JournalStatus,

      line_count:
        Number(
          row.line_count ??
            0,
        ),

      total_debit:
        Number(
          row.total_debit ??
            0,
        ),

      total_credit:
        Number(
          row.total_credit ??
            0,
        ),
    }),
  )
}


/* ============================================================
   ACCOUNTING NAME SEARCH
============================================================ */

export async function searchAccountingNames(
  companyId: string,
  search = '',
  nameType:
    | 'customer'
    | 'vendor'
    | 'employee'
    | 'other'
    | null = null,
  limit = 50,
): Promise<
  AccountingNameSearchResult[]
> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'search_accounting_names',
      {
        p_company_id:
          companyId,

        p_search:
          search ||
          null,

        p_name_type:
          nameType,

        p_limit:
          limit,
      },
    )

  assertNoRpcError(
    error,
  )

  return asRecordArray(
    data,
  ).map(
    (
      row,
    ) => ({
      id:
        String(
          row.id,
        ),

      name_code:
        String(
          row.name_code ??
            '',
        ),

      name_type:
        row.name_type as
          AccountingNameSearchResult[
            'name_type'
          ],

      display_name:
        String(
          row.display_name ??
            '',
        ),

      legal_name:
        row.legal_name ==
        null
          ? null
          : String(
              row.legal_name,
            ),

      phone:
        row.phone ==
        null
          ? null
          : String(
              row.phone,
            ),

      email:
        row.email ==
        null
          ? null
          : String(
              row.email,
            ),
    }),
  )
}


/* ============================================================
   ACCOUNT SEARCH
============================================================ */

export async function searchAccounts(
  companyId: string,
  search = '',
  limit = 100,
): Promise<
  AccountSearchResult[]
> {
  let query =
    supabase
      .from(
        'chart_of_accounts',
      )
      .select(
        [
          'id',
          'company_id',
          'account_code',
          'account_name',
          'account_role',
          'node_type',
          'is_posting',
          'is_control_account',
          'is_active',
          'name_requirement',
          'allow_name',
        ].join(','),
      )
      .eq(
        'company_id',
        companyId,
      )
      .eq(
        'is_active',
        true,
      )
      .eq(
        'is_posting',
        true,
      )
      .order(
        'account_code',
        {
          ascending:
            true,
        },
      )
      .limit(
        limit,
      )

  const trimmed =
    search.trim()

  if (trimmed) {
    query =
      query.or(
        [
          `account_code.ilike.%${trimmed}%`,
          `account_name.ilike.%${trimmed}%`,
        ].join(','),
      )
  }

  const {
    data,
    error,
  } =
    await query

  assertNoRpcError(
    error,
  )

  return asRecordArray(
    data,
  ).map(
    (
      row,
    ) => ({
      id:
        String(
          row.id,
        ),

      company_id:
        String(
          row.company_id,
        ),

      account_code:
        String(
          row.account_code ??
            '',
        ),

      account_name:
        String(
          row.account_name ??
            '',
        ),

      account_role:
        row.account_role as
          AccountSearchResult[
            'account_role'
          ],

      node_type:
        row.node_type as
          AccountSearchResult[
            'node_type'
          ],

      is_posting:
        Boolean(
          row.is_posting,
        ),

      is_control_account:
        Boolean(
          row.is_control_account,
        ),

      is_active:
        Boolean(
          row.is_active,
        ),

      name_requirement:
        row.name_requirement as
          AccountSearchResult[
            'name_requirement'
          ],

      allow_name:
        Boolean(
          row.allow_name,
        ),
    }),
  )
}


/* ============================================================
   CREATE ACCOUNTING NAME
============================================================ */

export async function createAccountingName(
  input: CreateAccountingNameInput,
): Promise<string> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'create_accounting_name',
      {
        p_company_id:
          input.companyId,

        p_name_type:
          input.nameType,

        p_display_name:
          input.displayName,

        p_name_code:
          input.nameCode ??
          null,

        p_legal_name:
          input.legalName ??
          null,

        p_phone:
          input.phone ??
          null,

        p_email:
          input.email ??
          null,
      },
    )

  assertNoRpcError(
    error,
  )

  if (!data) {
    throw new Error(
      'Accounting Name could not be created.',
    )
  }

  return String(
    data,
  )
}


/* ============================================================
   TRANSACTION REFERENCE SEARCH
============================================================ */

export async function searchTransactionReferences(
  companyId: string,
  search = '',
  referenceType:
    | string
    | null = null,
  limit = 100,
): Promise<
  JournalReferenceResult[]
> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'search_transaction_references',
      {
        p_company_id:
          companyId,

        p_search:
          search ||
          null,

        p_reference_type:
          referenceType,

        p_limit:
          limit,
      },
    )

  assertNoRpcError(
    error,
  )

  return asRecordArray(
    data,
  ).map(
    (
      row,
    ) => ({
      journal_entry_id:
        String(
          row.journal_entry_id,
        ),

      journal_number:
        String(
          row.journal_number ??
            '',
        ),

      reference_type:
        row.reference_type ==
        null
          ? null
          : String(
              row.reference_type,
            ),

      reference_type_name:
        row.reference_type_name ==
        null
          ? null
          : String(
              row.reference_type_name,
            ),

      reference_number:
        row.reference_number ==
        null
          ? null
          : String(
              row.reference_number,
            ),

      entry_date:
        String(
          row.entry_date ??
            '',
        ),

      status:
        row.status as JournalStatus,

      description:
        row.description ==
        null
          ? null
          : String(
              row.description,
            ),
    }),
  )
}


/* ============================================================
   UNIVERSAL DOCUMENT TYPES
============================================================ */

export async function getDocumentTypes(): Promise<
  Array<{
    code: string
    name: string
    module: string
  }>
> {
  const {
    data,
    error,
  } =
    await supabase
      .from(
        'document_types',
      )
      .select(
        'code,name,module',
      )
      .eq(
        'is_active',
        true,
      )
      .order(
        'display_order',
        {
          ascending:
            true,
        },
      )

  assertNoRpcError(
    error,
  )

  return asRecordArray(
    data,
  ).map(
    (
      row,
    ) => ({
      code:
        String(
          row.code ??
            '',
        ),

      name:
        String(
          row.name ??
            '',
        ),

      module:
        String(
          row.module ??
            '',
        ),
    }),
  )
}


/* ============================================================
   PROFESSIONAL JOURNAL SEARCH
   Added by Migration 033
============================================================ */

export async function findJournalTransactions(
  companyId: string,
  filters: {
    search?: string

    dateFrom?: string | null
    dateTo?: string | null

    referenceFrom?:
      | string
      | null

    referenceTo?:
      | string
      | null

    amountFrom?:
      | number
      | null

    amountTo?:
      | number
      | null

    referenceType?:
      | string
      | null

    accountId?:
      | string
      | null

    nameId?:
      | string
      | null

    branchId?:
      | string
      | null

    departmentId?:
      | string
      | null

    status?:
      | JournalStatus
      | null

    limit?: number
  } = {},
): Promise<
  JournalSearchResult[]
> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'find_journal_transactions',
      {
        p_company_id:
          companyId,

        p_search:
          filters.search ||
          null,

        p_date_from:
          filters.dateFrom ||
          null,

        p_date_to:
          filters.dateTo ||
          null,

        p_reference_from:
          filters.referenceFrom ||
          null,

        p_reference_to:
          filters.referenceTo ||
          null,

        p_amount_from:
          filters.amountFrom ??
          null,

        p_amount_to:
          filters.amountTo ??
          null,

        p_reference_type:
          filters.referenceType ||
          null,

        p_account_id:
          filters.accountId ||
          null,

        p_name_id:
          filters.nameId ||
          null,

        p_branch_id:
          filters.branchId ||
          null,

        p_department_id:
          filters.departmentId ||
          null,

        p_status:
          filters.status ??
          null,

        p_limit:
          filters.limit ??
          100,
      },
    )

  assertNoRpcError(
    error,
  )

  return asRecordArray(
    data,
  ).map(
    (
      row,
    ) => ({
      id:
        String(
          row.id,
        ),

      journal_number:
        String(
          row.journal_number ??
            '',
        ),

      entry_date:
        String(
          row.entry_date ??
            '',
        ),

      reference_type:
        row.reference_type ==
        null
          ? null
          : String(
              row.reference_type,
            ),

      reference_type_name:
        row.reference_type_name ==
        null
          ? null
          : String(
              row.reference_type_name,
            ),

      reference_number:
        row.reference_number ==
        null
          ? null
          : String(
              row.reference_number,
            ),

      description:
        row.description ==
        null
          ? null
          : String(
              row.description,
            ),

      status:
        row.status as JournalStatus,

      line_count:
        Number(
          row.line_count ??
            0,
        ),

      total_debit:
        Number(
          row.total_debit ??
            0,
        ),

      total_credit:
        Number(
          row.total_credit ??
            0,
        ),
    }),
  )
}


/* ============================================================
   GLOBAL JOURNAL SEARCH
============================================================ */

export async function findJournalGlobal(
  companyId: string,
  search: string,
  limit = 100,
): Promise<
  JournalSearchResult[]
> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'find_journal_global',
      {
        p_company_id:
          companyId,

        p_search:
          search,

        p_limit:
          limit,
      },
    )

  assertNoRpcError(
    error,
  )

  return asRecordArray(
    data,
  ).map(
    (
      row,
    ) => ({
      id:
        String(
          row.id,
        ),

      journal_number:
        String(
          row.journal_number ??
            '',
        ),

      entry_date:
        String(
          row.entry_date ??
            '',
        ),

      reference_type:
        row.reference_type ==
        null
          ? null
          : String(
              row.reference_type,
            ),

      reference_type_name:
        row.reference_type_name ==
        null
          ? null
          : String(
              row.reference_type_name,
            ),

      reference_number:
        row.reference_number ==
        null
          ? null
          : String(
              row.reference_number,
            ),

      description:
        row.description ==
        null
          ? null
          : String(
              row.description,
            ),

      status:
        row.status as JournalStatus,

      line_count:
        Number(
          row.line_count ??
            0,
        ),

      total_debit:
        Number(
          row.total_debit ??
            0,
        ),

      total_credit:
        Number(
          row.total_credit ??
            0,
        ),
    }),
  )
}
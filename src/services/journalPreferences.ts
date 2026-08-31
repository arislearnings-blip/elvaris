export type JournalGridColumn =
  | 'account'
  | 'name'
  | 'memo'
  | 'debit'
  | 'credit'

export type JournalGridDensity =
  | 'compact'
  | 'standard'
  | 'comfortable'

export type JournalDateFormat =
  | 'DD/MM/YYYY'
  | 'MM/DD/YYYY'
  | 'YYYY-MM-DD'
  | 'DD-MM-YYYY'
  | 'DD.MM.YYYY'

export type JournalNumberFormat = {
  prefix: string
  separator: string
  includeYear: boolean
  yearFormat: 'YYYY' | 'YY'
  includeDate: boolean
  dateFormat: 'DDMMYYYY' | 'MMDDYYYY' | 'YYYYMMDD'
  numberPadding: number
}

export type JournalGridPreferences = {
  visibleColumns: JournalGridColumn[]
  columnOrder: JournalGridColumn[]
  columnWidths: Record<JournalGridColumn, number>
  density: JournalGridDensity
  freezeAccount: boolean
  showRowNumbers: boolean
  rememberLayout: boolean
  autoExpandRows: boolean
  showKeyboardHints: boolean
  showReferencePreview: boolean
  stickyTotals: boolean
  defaultFocus: JournalGridColumn
  enterMoves: 'down' | 'next-cell'
  amountExpressions: boolean
  thousandsSeparator: boolean
  amountDecimals: number
  showRecentTransactions: boolean
  recentTransactionCount: number
  autoFitColumns: boolean
  dateFormat: JournalDateFormat
  allowManualJournalNumber: boolean
  exportIncludeHeader: boolean
  printPaperSize: 'A4' | 'LETTER'
  printOrientation: 'portrait' | 'landscape'
  printMargins: 'compact' | 'standard' | 'wide'
  printShowCompanyDetails: boolean
  printShowLogo: boolean
  printShowApprovalLines: boolean
  journalNumberFormat: JournalNumberFormat
  referenceFormat: JournalNumberFormat
}

export type MemorizedJournalTemplate = {
  id: string
  name: string
  createdAt: string
  rows: Array<{
    accountId: string
    accountCode: string
    accountName: string
    nameId: string | null
    nameCode: string
    nameDisplay: string
    memo: string
    debit: string
    credit: string
  }>
}

const PREFS_KEY = 'elvaris.journal.grid.preferences.v5'
const MEMO_KEY = 'elvaris.journal.memorized.templates'

const DEFAULT_NUMBER_FORMAT: JournalNumberFormat = {
  prefix: '',
  separator: '-',
  includeYear: false,
  yearFormat: 'YYYY',
  includeDate: false,
  dateFormat: 'DDMMYYYY',
  numberPadding: 4,
}

export const DEFAULT_JOURNAL_GRID_PREFERENCES: JournalGridPreferences = {
  visibleColumns: [
    'account',
    'name',
    'memo',
    'debit',
    'credit',
  ],
  columnOrder: [
    'account',
    'name',
    'memo',
    'debit',
    'credit',
  ],
  columnWidths: {
    account: 29,
    name: 20,
    memo: 25,
    debit: 13,
    credit: 13,
  },
  density: 'standard',
  freezeAccount: true,
  showRowNumbers: true,
  rememberLayout: true,
  autoExpandRows: true,
  showKeyboardHints: true,
  showReferencePreview: true,
  stickyTotals: true,
  defaultFocus: 'account',
  enterMoves: 'down',
  amountExpressions: true,
  thousandsSeparator: true,
  amountDecimals: 2,
  showRecentTransactions: true,
  recentTransactionCount: 8,
  autoFitColumns: true,
  dateFormat: 'DD/MM/YYYY',
  allowManualJournalNumber: true,
  exportIncludeHeader: true,
  printPaperSize: 'A4',
  printOrientation: 'portrait',
  printMargins: 'standard',
  printShowCompanyDetails: true,
  printShowLogo: true,
  printShowApprovalLines: true,
  journalNumberFormat: {
    ...DEFAULT_NUMBER_FORMAT,
    prefix: 'JV',
  },
  referenceFormat: {
    ...DEFAULT_NUMBER_FORMAT,
    prefix: '',
  },
}

function cloneDefaults(): JournalGridPreferences {
  return {
    ...DEFAULT_JOURNAL_GRID_PREFERENCES,
    visibleColumns: [
      ...DEFAULT_JOURNAL_GRID_PREFERENCES.visibleColumns,
    ],
    columnOrder: [
      ...DEFAULT_JOURNAL_GRID_PREFERENCES.columnOrder,
    ],
    columnWidths: {
      ...DEFAULT_JOURNAL_GRID_PREFERENCES.columnWidths,
    },
    journalNumberFormat: {
      ...DEFAULT_JOURNAL_GRID_PREFERENCES.journalNumberFormat,
    },
    referenceFormat: {
      ...DEFAULT_JOURNAL_GRID_PREFERENCES.referenceFormat,
    },
  }
}

export function loadJournalGridPreferences(): JournalGridPreferences {
  try {
    const raw = localStorage.getItem(PREFS_KEY)
    if (!raw) return cloneDefaults()

    const parsed = JSON.parse(raw) as Partial<JournalGridPreferences> & {
      referenceFormat?: Partial<JournalNumberFormat>
      journalNumberFormat?: Partial<JournalNumberFormat>
    }
    const defaults = cloneDefaults()

    return {
      ...defaults,
      ...parsed,
      visibleColumns:
        parsed.visibleColumns ?? defaults.visibleColumns,
      columnOrder:
        parsed.columnOrder ?? defaults.columnOrder,
      columnWidths: {
        ...defaults.columnWidths,
        ...(parsed.columnWidths ?? {}),
      },
      journalNumberFormat: {
        ...defaults.journalNumberFormat,
        ...(parsed.journalNumberFormat ?? {}),
      },
      referenceFormat: {
        ...defaults.referenceFormat,
        ...(parsed.referenceFormat ?? {}),
      },
    }
  } catch {
    return cloneDefaults()
  }
}

export function saveJournalGridPreferences(
  preferences: JournalGridPreferences,
) {
  if (!preferences.rememberLayout) return
  localStorage.setItem(
    PREFS_KEY,
    JSON.stringify(preferences),
  )
}

export function resetJournalGridPreferences() {
  const next = cloneDefaults()
  saveJournalGridPreferences(next)
  return next
}

export function loadMemorizedJournalTemplates(): MemorizedJournalTemplate[] {
  try {
    const raw = localStorage.getItem(MEMO_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as unknown
    return Array.isArray(parsed)
      ? (parsed as MemorizedJournalTemplate[])
      : []
  } catch {
    return []
  }
}

export function saveMemorizedJournalTemplates(
  templates: MemorizedJournalTemplate[],
) {
  localStorage.setItem(
    MEMO_KEY,
    JSON.stringify(templates),
  )
}

export function addMemorizedJournalTemplate(
  template: Omit<MemorizedJournalTemplate, 'id' | 'createdAt'>,
) {
  const created: MemorizedJournalTemplate = {
    ...template,
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
    createdAt: new Date().toISOString(),
  }

  saveMemorizedJournalTemplates([
    ...loadMemorizedJournalTemplates(),
    created,
  ])

  return created
}

export function removeMemorizedJournalTemplate(
  templateId: string,
) {
  saveMemorizedJournalTemplates(
    loadMemorizedJournalTemplates().filter(
      (template) => template.id !== templateId,
    ),
  )
}

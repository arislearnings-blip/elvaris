import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react'

import type {
  ChangeEvent,
  ClipboardEvent,
  KeyboardEvent,
} from 'react'

import {
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  Check,
  ChevronDown,
  Copy,
  Download,
  FilePlus2,
  FileText,
  Maximize2,
  Minimize2,
  Paperclip,
  Plus,
  Printer,
  RotateCcw,
  Redo2,
  Save,
  Undo2,
  Search,
  Settings,
  X,
} from 'lucide-react'

import {
  createAccountingName,
  createJournalTransaction,
  deleteJournalTransaction,
  findJournalTransactions,
  loadJournalTransaction,
  postJournalTransaction,
  reverseJournalTransaction,
  saveJournalTransaction,
  searchAccountingNames,
  searchAccounts,
  type AccountSearchResult,
  type AccountingNameSearchResult,
  type JournalLine,
  type JournalSearchResult,
  type JournalTransaction,
} from '../services/journalService'

import { supabase } from '../lib/supabaseClient'

import {
  addMemorizedJournalTemplate,
  loadJournalGridPreferences,
  loadMemorizedJournalTemplates,
  resetJournalGridPreferences,
  saveJournalGridPreferences,
  type JournalGridColumn,
  type JournalGridPreferences,
  type MemorizedJournalTemplate,
} from '../services/journalPreferences'

import './JournalVoucherPage.css'

type Company = {
  id: string
  company_code: string
  legal_name: string
  display_name: string | null
  base_currency_id: string
  decimal_places: number
  branch_accounting_enabled: boolean
  allow_manual_journal_number: boolean
  logo_url?: string | null
  registration_number?: string | null
  tax_registration_number?: string | null
  email?: string | null
  phone?: string | null
  website?: string | null
  address_line_1?: string | null
  address_line_2?: string | null
  city?: string | null
  state?: string | null
  postal_code?: string | null
}

type Branch = {
  id: string
  branch_code: string
  name: string
}

type DocumentType = {
  code: string
  name: string
  module: string
  prefix?: string
  separator?: string
  include_year?: boolean
  year_format?: string
  number_padding?: number
  next_number?: number
}

type GridRow = {
  localId: string
  accountId: string
  accountCode: string
  accountName: string
  accountRole: 'header' | 'posting' | 'control' | ''
  accountSearch: string
  accountOpen: boolean
  accountResults: AccountSearchResult[]
  nameId: string | null
  nameCode: string
  nameDisplay: string
  nameType: 'customer' | 'vendor' | 'employee' | 'other' | ''
  nameSearch: string
  nameOpen: boolean
  nameResults: AccountingNameSearchResult[]
  nameRequired: boolean
  allowName: boolean
  memo: string
  debit: string
  credit: string
}

type CellColumn = JournalGridColumn
type WindowMode = 'normal' | 'maximized' | 'minimized'

type SearchResult = JournalSearchResult & {
  matched_accounts?: string | null
  matched_names?: string | null
}

type Attachment = {
  id: string
  file: File
}

type QuickName = {
  open: boolean
  rowIndex: number | null
  nameType: 'customer' | 'vendor' | 'employee' | 'other'
  displayName: string
  nameCode: string
  legalName: string
  phone: string
  email: string
}

const INITIAL_ROWS = 20
const COLUMNS: CellColumn[] = ['account', 'name', 'memo', 'debit', 'credit']

function newId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}

function emptyRow(): GridRow {
  return {
    localId: newId(),
    accountId: '',
    accountCode: '',
    accountName: '',
    accountRole: '',
    accountSearch: '',
    accountOpen: false,
    accountResults: [],
    nameId: null,
    nameCode: '',
    nameDisplay: '',
    nameType: '',
    nameSearch: '',
    nameOpen: false,
    nameResults: [],
    nameRequired: false,
    allowName: true,
    memo: '',
    debit: '',
    credit: '',
  }
}

function makeRows(count = INITIAL_ROWS) {
  return Array.from({ length: count }, emptyRow)
}

function evaluateArithmetic(input: string): number {
  const source = input.replace(/,/g, '').replace(/\s+/g, '')
  if (!source) return 0

  const tokens = source.match(/(?:\d+(?:\.\d+)?|\.\d+|[()+\-*/])/g)
  if (!tokens || tokens.join('') !== source) throw new Error('Invalid amount expression.')

  let position = 0

  const primary = (): number => {
    const token = tokens[position]
    if (token === undefined) throw new Error('Incomplete amount expression.')

    if (token === '(') {
      position += 1
      const value = additive()
      if (tokens[position] !== ')') throw new Error('Missing closing parenthesis.')
      position += 1
      return value
    }

    if (token === '+' || token === '-') {
      position += 1
      const value = primary()
      return token === '-' ? -value : value
    }

    position += 1
    const value = Number(token)
    if (!Number.isFinite(value)) throw new Error('Invalid amount.')
    return value
  }

  const multiplicative = (): number => {
    let value = primary()
    while (tokens[position] === '*' || tokens[position] === '/') {
      const op = tokens[position]
      position += 1
      const rhs = primary()
      if (op === '/' && rhs === 0) throw new Error('Division by zero.')
      value = op === '*' ? value * rhs : value / rhs
    }
    return value
  }

  const additive = (): number => {
    let value = multiplicative()
    while (tokens[position] === '+' || tokens[position] === '-') {
      const op = tokens[position]
      position += 1
      const rhs = multiplicative()
      value = op === '+' ? value + rhs : value - rhs
    }
    return value
  }

  const result = additive()
  if (position !== tokens.length || !Number.isFinite(result)) {
    throw new Error('Invalid amount expression.')
  }
  return result
}

function numeric(value: string) {
  try {
    return evaluateArithmetic(value)
  } catch {
    return 0
  }
}

function money(value: number, decimals: number, separators = true) {
  return new Intl.NumberFormat(undefined, {
    useGrouping: separators,
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value)
}

function refPreview(
  number: number,
  date: string,
  format: JournalGridPreferences['referenceFormat'],
) {
  const [year, month, day] = date.split('-')
  const numericPart = String(number).padStart(
    Math.max(1, format.numberPadding),
    '0',
  )
  const pieces: string[] = []

  if (format.includeDate) {
    pieces.push(
      format.dateFormat === 'MMDDYYYY'
        ? `${month}${day}${year}`
        : format.dateFormat === 'YYYYMMDD'
          ? `${year}${month}${day}`
          : `${day}${month}${year}`,
    )
  }

  if (format.includeYear) {
    pieces.push(format.yearFormat === 'YY' ? year.slice(2) : year)
  }

  if (format.prefix) pieces.push(format.prefix)
  pieces.push(numericPart)
  return pieces.join(format.separator)
}

function JournalVoucherPage() {
  const [company, setCompany] = useState<Company | null>(null)
  const [branches, setBranches] = useState<Branch[]>([])
  const [documents, setDocuments] = useState<DocumentType[]>([])
  const [rows, setRows] = useState<GridRow[]>(makeRows())
  const [entryDate, setEntryDate] = useState(
    new Date().toISOString().slice(0, 10),
  )
  const [journalNumber, setJournalNumber] = useState('')
  const [manualJournalNumber, setManualJournalNumber] = useState(false)
  const [referenceType, setReferenceType] = useState('JV')
  const [referenceNumber, setReferenceNumber] = useState('')
  const [branchId, setBranchId] = useState('')
  const [journalId, setJournalId] = useState<string | null>(null)
  const [status, setStatus] = useState<'new' | 'draft' | 'posted' | 'reversed' | 'void'>('new')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [windowMode, setWindowMode] = useState<WindowMode>('normal')
  const [searchOpen, setSearchOpen] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [settingsSection, setSettingsSection] = useState<'workspace' | 'grid' | 'columns' | 'amounts' | 'numbering' | 'shortcuts' | 'printing'>('workspace')
  const [printPreviewOpen, setPrintPreviewOpen] = useState(false)
  const [exportOpen, setExportOpen] = useState(false)
  const [moreOpen, setMoreOpen] = useState(false)
  const [memoOpen, setMemoOpen] = useState(false)
  const [memoName, setMemoName] = useState('')
  const [attachments, setAttachments] = useState<Attachment[]>([])
  const [quickName, setQuickName] = useState<QuickName>({
    open: false,
    rowIndex: null,
    nameType: 'other',
    displayName: '',
    nameCode: '',
    legalName: '',
    phone: '',
    email: '',
  })
  const [accountQuickAddOpen, setAccountQuickAddOpen] = useState(false)
  const [searchLoading, setSearchLoading] = useState(false)
  const [searchResults, setSearchResults] = useState<SearchResult[]>([])
  const [searchFilters, setSearchFilters] = useState({
    search: '',
    name: '',
    dateFrom: '',
    dateTo: '',
    referenceFrom: '',
    referenceTo: '',
    amountFrom: '',
    amountTo: '',
    referenceType: '',
    status: '',
  })
  const [preferences, setPreferences] = useState<JournalGridPreferences>(() =>
    loadJournalGridPreferences(),
  )
  const [activeRow, setActiveRow] = useState<number | null>(null)
  const [activeColumn, setActiveColumn] = useState<CellColumn | null>(null)
  const [memorized, setMemorized] = useState<MemorizedJournalTemplate[]>(() =>
    loadMemorizedJournalTemplates(),
  )

  type JournalSnapshot = {
    entryDate: string
    journalNumber: string
    manualJournalNumber: boolean
    referenceNumber: string
    branchId: string
    rows: GridRow[]
  }

  const [undoStack, setUndoStack] = useState<JournalSnapshot[]>([])
  const [redoStack, setRedoStack] = useState<JournalSnapshot[]>([])
  const tableRef = useRef<HTMLTableElement | null>(null)
  const fileRef = useRef<HTMLInputElement | null>(null)

  const editable = status === 'new' || status === 'draft'
  const decimals = company?.decimal_places ?? preferences.amountDecimals

  const totals = useMemo(() => {
    let debit = 0
    let credit = 0
    let entered = 0

    for (const row of rows) {
      debit += numeric(row.debit)
      credit += numeric(row.credit)
      if (
        row.accountId ||
        row.accountSearch.trim() ||
        row.nameSearch.trim() ||
        row.memo.trim() ||
        row.debit.trim() ||
        row.credit.trim()
      ) entered += 1
    }

    return {
      debit,
      credit,
      difference: debit - credit,
      entered,
      balanced: entered > 0 && Math.abs(debit - credit) < 0.000001,
    }
  }, [rows])

  const journalDocument = documents.find((document) => document.code === 'JV')
  const nextJournalNumber = Number(journalDocument?.next_number ?? 1)
  const journalPreview = journalNumber || `JV-${String(nextJournalNumber).padStart(4, '0')}`
  const referencePreview = refPreview(
    1,
    entryDate,
    preferences.referenceFormat,
  )
  const visibleColumns = preferences.columnOrder.filter((column) =>
    preferences.visibleColumns.includes(column),
  )

  useEffect(() => {
    saveJournalGridPreferences(preferences)
  }, [preferences])

  useEffect(() => {
    void initialize()
  }, [])

  useEffect(() => {
    const closeMenus = (event: MouseEvent) => {
      const target = event.target as HTMLElement | null
      if (!target?.closest('.journal-menu-wrap')) {
        setExportOpen(false)
        setMoreOpen(false)
      }
    }
    document.addEventListener('mousedown', closeMenus)
    return () => document.removeEventListener('mousedown', closeMenus)
  }, [])

  useEffect(() => {
    const keyHandler = (event: globalThis.KeyboardEvent) => {
      if (event.ctrlKey && event.key.toLowerCase() === 's') {
        event.preventDefault()
        if (editable) void save()
      }
      if (event.altKey && event.key.toLowerCase() === 'n') {
        event.preventDefault()
        if (editable) void saveAndNew()
      }
      if (event.ctrlKey && event.key.toLowerCase() === 'f') {
        event.preventDefault()
        setSearchOpen(true)
      }
      if (event.ctrlKey && event.key.toLowerCase() === 'p') {
        event.preventDefault()
        setPrintPreviewOpen(true)
      }
      if (event.ctrlKey && event.key.toLowerCase() === 'e') {
        event.preventDefault()
        setExportOpen((value) => !value)
      }
      if (event.ctrlKey && event.key.toLowerCase() === 'z' && !event.shiftKey) {
        event.preventDefault()
        undo()
        return
      }
      if ((event.ctrlKey && event.key.toLowerCase() === 'y') || (event.ctrlKey && event.shiftKey && event.key.toLowerCase() === 'z')) {
        event.preventDefault()
        redo()
        return
      }
      if (event.ctrlKey && event.key === 'Enter') {
        event.preventDefault()
        void post()
      }
      if (event.key === 'Escape') {
        if (exportOpen || moreOpen || searchOpen || settingsOpen || printPreviewOpen || memoOpen || accountQuickAddOpen || quickName.open) {
          setSearchOpen(false)
          setSettingsOpen(false)
          setPrintPreviewOpen(false)
          setMemoOpen(false)
          setAccountQuickAddOpen(false)
          setQuickName((current) => ({ ...current, open: false }))
          setExportOpen(false)
          setMoreOpen(false)
          return
        }

        const dirty = rows.some((row) => row.accountId || row.accountSearch.trim() || row.nameSearch.trim() || row.memo.trim() || row.debit.trim() || row.credit.trim())
        if (editable && dirty) {
          const discard = window.confirm('This Journal Voucher contains unsaved work. Close and discard the current entry?')
          if (discard) clearForm()
          return
        }
      }
    }

    window.addEventListener('keydown', keyHandler)
    return () => window.removeEventListener('keydown', keyHandler)
  }, [editable, journalId, searchOpen, settingsOpen, printPreviewOpen])

  async function initialize() {
    try {
      const [companyResult, branchResult, documentResult] = await Promise.all([
        supabase
          .from('companies')
          .select(
            'id,company_code,legal_name,display_name,registration_number,tax_registration_number,email,phone,website,address_line_1,address_line_2,city,state,postal_code,logo_url,base_currency_id,decimal_places,branch_accounting_enabled,allow_manual_journal_number',
          )
          .eq('is_active', true)
          .limit(1),
        supabase
          .from('branches')
          .select('id,branch_code,name')
          .eq('is_active', true)
          .order('branch_code'),
        supabase
          .from('document_types')
          .select(
            'code,name,module,prefix,separator,include_year,year_format,number_padding,next_number',
          )
          .eq('is_active', true)
          .order('display_order'),
      ])

      if (companyResult.error) throw companyResult.error
      if (branchResult.error) throw branchResult.error
      if (documentResult.error) throw documentResult.error

      const companyRow = (companyResult.data ?? [])[0] as Record<string, unknown> | undefined
      if (!companyRow?.id) throw new Error('No active company is configured.')

      setCompany({
        id: String(companyRow.id),
        company_code: String(companyRow.company_code ?? ''),
        legal_name: String(companyRow.legal_name ?? ''),
        display_name:
          typeof companyRow.display_name === 'string'
            ? companyRow.display_name
            : null,
        logo_url: companyRow.logo_url == null ? null : String(companyRow.logo_url),
        registration_number: companyRow.registration_number == null ? null : String(companyRow.registration_number),
        tax_registration_number: companyRow.tax_registration_number == null ? null : String(companyRow.tax_registration_number),
        email: companyRow.email == null ? null : String(companyRow.email),
        phone: companyRow.phone == null ? null : String(companyRow.phone),
        website: companyRow.website == null ? null : String(companyRow.website),
        address_line_1: companyRow.address_line_1 == null ? null : String(companyRow.address_line_1),
        address_line_2: companyRow.address_line_2 == null ? null : String(companyRow.address_line_2),
        city: companyRow.city == null ? null : String(companyRow.city),
        state: companyRow.state == null ? null : String(companyRow.state),
        postal_code: companyRow.postal_code == null ? null : String(companyRow.postal_code),
        base_currency_id: String(companyRow.base_currency_id ?? ''),
        decimal_places: Number(companyRow.decimal_places ?? 2),
        branch_accounting_enabled: Boolean(companyRow.branch_accounting_enabled),
        allow_manual_journal_number: Boolean(companyRow.allow_manual_journal_number),
      })

      setBranches(
        (branchResult.data ?? []).filter(Boolean).map((value) => {
          const row = value as Record<string, unknown>
          return {
            id: String(row.id),
            branch_code: String(row.branch_code ?? ''),
            name: String(row.name ?? ''),
          }
        }),
      )

      setDocuments(
        (documentResult.data ?? []).map((value) => {
          const row = value as Record<string, unknown>
          return {
            code: String(row.code ?? ''),
            name: String(row.name ?? ''),
            module: String(row.module ?? ''),
            prefix: row.prefix == null ? undefined : String(row.prefix),
            separator: row.separator == null ? undefined : String(row.separator),
            include_year: Boolean(row.include_year),
            year_format: row.year_format == null ? undefined : String(row.year_format),
            number_padding: Number(row.number_padding ?? 4),
            next_number: Number(row.next_number ?? 1),
          }
        }),
      )
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : 'Unable to initialize Journal Voucher.',
      )
    } finally {
      setLoading(false)
    }
  }

  function snapshot(): JournalSnapshot {
    return {
      entryDate,
      journalNumber,
      manualJournalNumber,
      referenceNumber,
      branchId,
      rows: rows.map((row) => ({
        ...row,
        accountResults: [],
        nameResults: [],
      })),
    }
  }

  function pushHistory() {
    setUndoStack((current) => [...current.slice(-39), snapshot()])
    setRedoStack([])
  }

  function restoreSnapshot(value: JournalSnapshot) {
    setEntryDate(value.entryDate)
    setJournalNumber(value.journalNumber)
    setManualJournalNumber(value.manualJournalNumber)
    setReferenceNumber(value.referenceNumber)
    setBranchId(value.branchId)
    setRows(value.rows)
  }

  function undo() {
    setUndoStack((current) => {
      if (!current.length) return current
      const previous = current[current.length - 1]
      setRedoStack((redo) => [...redo.slice(-39), snapshot()])
      restoreSnapshot(previous)
      return current.slice(0, -1)
    })
  }

  function redo() {
    setRedoStack((current) => {
      if (!current.length) return current
      const next = current[current.length - 1]
      setUndoStack((undoHistory) => [...undoHistory.slice(-39), snapshot()])
      restoreSnapshot(next)
      return current.slice(0, -1)
    })
  }

  function updateRow(index: number, changes: Partial<GridRow>) {
    const historyKeys = Object.keys(changes)
    const historyRelevant = historyKeys.some((key) => !['accountOpen', 'accountResults', 'nameOpen', 'nameResults'].includes(key))
    if (historyRelevant) pushHistory()
    setRows((current) =>
      current.map((row, rowIndex) =>
        rowIndex === index ? { ...row, ...changes } : row,
      ),
    )
  }

  function ensureRows(count: number) {
    setRows((current) => {
      if (current.length >= count) return current
      return [
        ...current,
        ...Array.from(
          { length: count - current.length },
          emptyRow,
        ),
      ]
    })
  }

  function focusCell(row: number, column: number) {
    const boundedRow = Math.max(0, Math.min(rows.length - 1, row))
    const boundedColumn = Math.max(0, Math.min(COLUMNS.length - 1, column))
    const node = tableRef.current?.querySelector(
      `[data-row="${boundedRow}"][data-column="${COLUMNS[boundedColumn]}"]`,
    ) as HTMLInputElement | null
    node?.focus()
  }

  function handleCellKeyDown(
    event: KeyboardEvent<HTMLInputElement>,
    rowIndex: number,
    column: CellColumn,
  ) {
    const index = COLUMNS.indexOf(column)

    if (event.key === 'ArrowUp') {
      event.preventDefault()
      focusCell(rowIndex - 1, index)
      return
    }
    if (event.key === 'ArrowDown') {
      event.preventDefault()
      if (rowIndex === rows.length - 1) ensureRows(rows.length + 1)
      window.setTimeout(() => focusCell(rowIndex + 1, index), 0)
      return
    }
    if (event.key === 'ArrowLeft' && event.currentTarget.selectionStart === 0) {
      event.preventDefault()
      focusCell(rowIndex, index - 1)
      return
    }
    if (
      event.key === 'ArrowRight' &&
      event.currentTarget.selectionStart === event.currentTarget.value.length
    ) {
      event.preventDefault()
      focusCell(rowIndex, index + 1)
      return
    }
    if (event.key === 'Enter') {
      event.preventDefault()
      if (rowIndex === rows.length - 1 && preferences.autoExpandRows) {
        ensureRows(rows.length + 1)
      }
      window.setTimeout(
        () =>
          preferences.enterMoves === 'next-cell'
            ? focusCell(
                rowIndex + (index === COLUMNS.length - 1 ? 1 : 0),
                index === COLUMNS.length - 1 ? 0 : index + 1,
              )
            : focusCell(rowIndex + 1, index),
        0,
      )
      return
    }
    if (event.key === 'Tab') {
      event.preventDefault()
      let nextRow = rowIndex
      let nextColumn = index + (event.shiftKey ? -1 : 1)
      if (nextColumn >= COLUMNS.length) {
        nextColumn = 0
        nextRow += 1
      }
      if (nextColumn < 0) {
        nextColumn = COLUMNS.length - 1
        nextRow -= 1
      }
      if (nextRow >= rows.length) ensureRows(rows.length + 1)
      window.setTimeout(() => focusCell(nextRow, nextColumn), 0)
    }
  }

  const handlePaste = useCallback(
    async (event: ClipboardEvent<HTMLDivElement>) => {
      if (!editable) return
      const text = event.clipboardData.getData('text/plain')
      if (!text.includes('\t') && !text.includes('\n')) return

      event.preventDefault()

      const lines = text
        .replace(/\r\n/g, '\n')
        .split('\n')
        .filter((line) => line.trim())

      const start = activeRow ?? 0
      if (preferences.autoExpandRows) {
        ensureRows(Math.max(INITIAL_ROWS, start + lines.length))
      }

      const imported: GridRow[] = []

      for (const line of lines) {
        const cells = line.split('\t')
        const row = emptyRow()
        const accountText = (cells[0] ?? '').trim()
        const nameText = (cells[1] ?? '').trim()
        row.memo = (cells[2] ?? '').trim()
        row.debit = (cells[3] ?? '').trim()
        row.credit = (cells[4] ?? '').trim()

        if (company && accountText) {
          try {
            const accounts = await searchAccounts(company.id, accountText, 5)
            const account =
              accounts.find(
                (item) =>
                  item.account_code === accountText ||
                  item.account_name.toLowerCase() === accountText.toLowerCase(),
              ) ?? accounts[0]

            if (account) {
              row.accountId = account.id
              row.accountCode = account.account_code
              row.accountName = account.account_name
              row.accountRole = account.account_role
              row.accountSearch = `${account.account_code} — ${account.account_name}`
              row.nameRequired = account.name_requirement === 'required'
              row.allowName = account.allow_name

              if (nameText) {
                const nameType =
                  account.account_code === '1210'
                    ? 'customer'
                    : account.account_code === '2110'
                      ? 'vendor'
                      : null
                const names = await searchAccountingNames(
                  company.id,
                  nameText,
                  nameType,
                  5,
                )
                const name = names[0]
                if (name) {
                  row.nameId = name.id
                  row.nameCode = name.name_code
                  row.nameDisplay = name.display_name
                  row.nameType = name.name_type
                  row.nameSearch = `${name.name_code} — ${name.display_name}`
                } else {
                  row.nameSearch = nameText
                }
              }
            } else {
              row.accountSearch = accountText
            }
          } catch {
            row.accountSearch = accountText
          }
        } else {
          row.accountSearch = accountText
        }

        if (!row.nameSearch) row.nameSearch = nameText
        imported.push(row)
      }

      setRows((current) => {
        const next = [...current]
        while (next.length < start + imported.length) next.push(emptyRow())
        imported.forEach((row, index) => {
          next[start + index] = row
        })
        while (next.length < INITIAL_ROWS) next.push(emptyRow())
        return next
      })

      setMessage(`${imported.length} row(s) pasted.`)
    },
    [activeRow, company, editable, preferences.autoExpandRows],
  )

  function selectAccount(rowIndex: number, account: AccountSearchResult) {
    updateRow(rowIndex, {
      accountId: account.id,
      accountCode: account.account_code,
      accountName: account.account_name,
      accountRole: account.account_role,
      accountSearch: `${account.account_code} — ${account.account_name}`,
      accountOpen: false,
      accountResults: [],
      nameId: null,
      nameCode: '',
      nameDisplay: '',
      nameType: '',
      nameSearch: '',
      nameOpen: false,
      nameResults: [],
      nameRequired: account.name_requirement === 'required',
      allowName: account.allow_name,
    })
    window.setTimeout(() => focusCell(rowIndex, 1), 0)
  }

  function selectName(rowIndex: number, name: AccountingNameSearchResult) {
    updateRow(rowIndex, {
      nameId: name.id,
      nameCode: name.name_code,
      nameDisplay: name.display_name,
      nameType: name.name_type,
      nameSearch: `${name.name_code} — ${name.display_name}`,
      nameOpen: false,
      nameResults: [],
    })
  }

  async function accountSearch(rowIndex: number, value: string) {
    updateRow(rowIndex, {
      accountSearch: value,
      accountOpen: true,
      accountResults: [],
    })

    if (!company || !value.trim()) return

    try {
      updateRow(rowIndex, {
        accountResults: await searchAccounts(company.id, value, 25),
      })
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Account search failed.')
    }
  }

  async function nameSearch(rowIndex: number, value: string) {
    const row = rows[rowIndex]
    updateRow(rowIndex, {
      nameSearch: value,
      nameOpen: true,
      nameResults: [],
    })

    if (!company || !value.trim()) return

    const type =
      row.accountCode === '1210'
        ? 'customer'
        : row.accountCode === '2110'
          ? 'vendor'
          : null

    try {
      updateRow(rowIndex, {
        nameResults: await searchAccountingNames(company.id, value, type, 25),
      })
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Name search failed.')
    }
  }

  function updateAmount(
    rowIndex: number,
    side: 'debit' | 'credit',
    value: string,
  ) {
    updateRow(rowIndex, {
      [side]: value,
      [side === 'debit' ? 'credit' : 'debit']:
        value ? '' : rows[rowIndex][side === 'debit' ? 'credit' : 'debit'],
    })
  }

  function validate(): string | null {
    const filled = rows.filter(
      (row) =>
        row.accountId ||
        row.accountSearch.trim() ||
        row.nameSearch.trim() ||
        row.memo.trim() ||
        row.debit.trim() ||
        row.credit.trim(),
    )

    if (!filled.length) return 'Enter at least one journal line.'

    for (let index = 0; index < rows.length; index += 1) {
      const row = rows[index]
      const populated =
        row.accountId ||
        row.accountSearch.trim() ||
        row.nameSearch.trim() ||
        row.memo.trim() ||
        row.debit.trim() ||
        row.credit.trim()

      if (!populated) continue
      if (!row.accountId) return `Line ${index + 1} requires an Account.`
      if (row.nameRequired && !row.nameId) return `Line ${index + 1} requires a Name.`
      if (row.debit.trim() && row.credit.trim()) {
        return `Line ${index + 1} cannot contain both Debit and Credit.`
      }
      if (row.debit.trim()) {
        try {
          evaluateArithmetic(row.debit)
        } catch (caught) {
          return `Line ${index + 1}: ${caught instanceof Error ? caught.message : 'Invalid Debit.'}`
        }
      }
      if (row.credit.trim()) {
        try {
          evaluateArithmetic(row.credit)
        } catch (caught) {
          return `Line ${index + 1}: ${caught instanceof Error ? caught.message : 'Invalid Credit.'}`
        }
      }
    }

    if (!totals.balanced) return 'Debit and Credit totals must balance.'
    return null
  }

  function toLines(): JournalLine[] {
    return rows
      .filter(
        (row) =>
          row.accountId ||
          row.accountSearch.trim() ||
          row.nameSearch.trim() ||
          row.memo.trim() ||
          row.debit.trim() ||
          row.credit.trim(),
      )
      .map((row) => ({
        account_id: row.accountId,
        name_id: row.nameId,
        description: row.memo,
        debit: numeric(row.debit),
        credit: numeric(row.credit),
        branch_id:
          company?.branch_accounting_enabled
            ? branchId || null
            : null,
        department_id: null,
      }))
  }

  async function save(): Promise<JournalTransaction | null> {
    if (!company) {
      setError('No active company is available.')
      return null
    }

    const validation = validate()
    if (validation) {
      setError(validation)
      return null
    }

    setSaving(true)
    setError('')
    setMessage('')

    try {
      let id = journalId

      if (!id) {
        id = await createJournalTransaction({
          companyId: company.id,
          entryDate,
          description: null,
          branchId: company.branch_accounting_enabled ? branchId || null : null,
          sourceType: 'general_journal',
          currencyId: null,
          referenceType,
          referenceNumber: referenceNumber || null,
          manualJournalNumber:
            manualJournalNumber && journalNumber.trim()
              ? journalNumber.trim()
              : null,
        })
        setJournalId(id)
      }

      const transaction = await saveJournalTransaction({
        journalEntryId: id,
        entryDate,
        description: null,
        branchId: company.branch_accounting_enabled ? branchId || null : null,
        referenceType: referenceType || null,
        referenceNumber: referenceNumber || null,
        lines: toLines(),
      })

      applyTransaction(transaction)
      setMessage(`Saved ${transaction.header.journal_number}.`)
      return transaction
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Unable to save Journal Voucher.')
      return null
    } finally {
      setSaving(false)
    }
  }

  async function saveAndNew() {
    const transaction = await save()
    if (transaction) clearForm()
  }

  async function post() {
    const validation = validate()
    if (validation) {
      setError(validation)
      return
    }

    let id = journalId
    if (!id) {
      const created = await save()
      id = created?.header.id ?? null
    }
    if (!id) return

    setSaving(true)
    setError('')

    try {
      const transaction = await postJournalTransaction(id)
      applyTransaction(transaction)
      setMessage(`Posted ${transaction.header.journal_number}.`)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Unable to post Journal Voucher.')
    } finally {
      setSaving(false)
    }
  }

  async function deleteCurrent() {
    if (!journalId || status !== 'draft') return
    if (!window.confirm('Delete this draft Journal Voucher?')) return

    setSaving(true)
    try {
      await deleteJournalTransaction(journalId)
      clearForm()
      setMessage('Draft Journal Voucher deleted.')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Unable to delete Journal Voucher.')
    } finally {
      setSaving(false)
    }
  }

  async function reverseCurrent() {
    if (!journalId || status !== 'posted') return
    if (!window.confirm('Create a reversal for this Journal Voucher?')) return

    setSaving(true)
    try {
      const transaction = await reverseJournalTransaction(
        journalId,
        entryDate,
        `Reversal of ${journalNumber}`,
      )
      applyTransaction(transaction)
      setMessage(`Reversal created: ${transaction.header.journal_number}.`)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Unable to reverse Journal Voucher.')
    } finally {
      setSaving(false)
    }
  }

  function applyTransaction(transaction: JournalTransaction) {
    setJournalId(transaction.header.id)
    setJournalNumber(transaction.header.journal_number)
    setManualJournalNumber(false)
    setEntryDate(transaction.header.entry_date)
    setBranchId(transaction.header.branch_id ?? '')
    setReferenceType(transaction.header.reference_type ?? 'JV')
    setReferenceNumber(transaction.header.reference_number ?? '')
    setStatus(transaction.header.status)

    const mapped: GridRow[] = transaction.lines.map((line) => ({
      ...emptyRow(),
      localId: line.id ?? newId(),
      accountId: line.account_id,
      accountCode: line.account_code ?? '',
      accountName: line.account_name ?? '',
      accountRole: line.account_role ?? '',
      accountSearch: line.account_code
        ? `${line.account_code} — ${line.account_name ?? ''}`
        : '',
      nameId: line.name_id ?? null,
      nameCode: line.name_code ?? '',
      nameDisplay: line.name_display ?? '',
      nameType: line.name_type ?? '',
      nameSearch: line.name_code
        ? `${line.name_code} — ${line.name_display ?? ''}`
        : '',
      memo: line.description ?? '',
      debit: line.debit ? String(line.debit) : '',
      credit: line.credit ? String(line.credit) : '',
    }))

    while (mapped.length < INITIAL_ROWS) mapped.push(emptyRow())
    setRows(mapped)
  }

  async function searchPrevious() {
    if (!company) return
    setSearchLoading(true)
    try {
      const results = await findJournalTransactions(company.id, {
        search: [searchFilters.search, searchFilters.name].filter(Boolean).join(' '),
        dateFrom: searchFilters.dateFrom || null,
        dateTo: searchFilters.dateTo || null,
        referenceFrom: searchFilters.referenceFrom || null,
        referenceTo: searchFilters.referenceTo || null,
        amountFrom: searchFilters.amountFrom ? numeric(searchFilters.amountFrom) : null,
        amountTo: searchFilters.amountTo ? numeric(searchFilters.amountTo) : null,
        referenceType: searchFilters.referenceType || null,
        status: searchFilters.status
          ? (searchFilters.status as 'draft' | 'posted' | 'reversed' | 'void')
          : null,
        limit: 250,
      })
      setSearchResults(results as SearchResult[])
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Journal search failed.')
    } finally {
      setSearchLoading(false)
    }
  }

  async function openPrevious(result: SearchResult) {
    setSearchOpen(false)
    setLoading(true)
    try {
      applyTransaction(await loadJournalTransaction(result.id))
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Unable to open Journal Voucher.')
    } finally {
      setLoading(false)
    }
  }

  function clearForm() {
    setJournalId(null)
    setJournalNumber('')
    setManualJournalNumber(false)
    setEntryDate(new Date().toISOString().slice(0, 10))
    setReferenceType('JV')
    setReferenceNumber('')
    setBranchId('')
    setStatus('new')
    setRows(makeRows())
    setActiveRow(null)
    setActiveColumn(null)
    setError('')
    setMessage('')
  }

  function printVoucher() {
    setPrintPreviewOpen(true)
  }

  function exportCsv() {
    const filled = rows.filter((row) => row.accountId)
    const lines = [
      ['Journal Number', 'Date', 'Reference Type', 'Reference Number', 'Account Code', 'Account', 'Name', 'Description', 'Debit', 'Credit'],
      ...filled.map((row) => [
        journalNumber,
        entryDate,
        referenceType,
        referenceNumber,
        row.accountCode,
        row.accountName,
        row.nameDisplay,
        row.memo,
        numeric(row.debit),
        numeric(row.credit),
      ]),
    ]
    const csv = lines
      .map((line) => line.map((value) => `"${String(value ?? '').replace(/"/g, '""')}"`).join(','))
      .join('\r\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `${journalNumber || 'Journal-Voucher'}.csv`
    link.click()
    URL.revokeObjectURL(url)
    setExportOpen(false)
  }

  function exportExcel() {
    const filled = rows.filter((row) => row.accountId)
    const body = filled
      .map(
        (row) => `
          <tr>
            <td>${journalNumber}</td><td>${entryDate}</td><td>${referenceType}</td><td>${referenceNumber}</td>
            <td>${row.accountCode}</td><td>${row.accountName}</td><td>${row.nameDisplay}</td><td>${row.memo}</td>
            <td>${numeric(row.debit)}</td><td>${numeric(row.credit)}</td>
          </tr>`,
      )
      .join('')
    const html = `<!doctype html><html><head><meta charset="utf-8"></head><body><table border="1"><thead><tr>
      <th>Journal Number</th><th>Date</th><th>Reference Type</th><th>Reference Number</th><th>Account Code</th><th>Account</th><th>Name</th><th>Description</th><th>Debit</th><th>Credit</th>
      </tr></thead><tbody>${body}</tbody></table></body></html>`
    const blob = new Blob([html], { type: 'application/vnd.ms-excel;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `${journalNumber || 'Journal-Voucher'}.xls`
    link.click()
    URL.revokeObjectURL(url)
    setExportOpen(false)
  }

  function copyFilledRows() {
    const filled = rows.filter((row) => row.accountId)
    const text = filled
      .map((row) =>
        [
          row.accountCode,
          row.accountName,
          row.nameCode,
          row.nameDisplay,
          row.memo,
          row.debit,
          row.credit,
        ].join('\t'),
      )
      .join('\n')
    void navigator.clipboard.writeText(text)
    setMessage(`${filled.length} row(s) copied.`)
  }

  function attachFiles(event: ChangeEvent<HTMLInputElement>) {
    const files = Array.from(event.target.files ?? [])
    setAttachments((current) => [
      ...current,
      ...files.map((file) => ({ id: newId(), file })),
    ])
    event.target.value = ''
  }

  function downloadAttachment(attachment: Attachment) {
    const url = URL.createObjectURL(attachment.file)
    const link = document.createElement('a')
    link.href = url
    link.download = attachment.file.name
    link.click()
    URL.revokeObjectURL(url)
  }

  function addName(rowIndex: number) {
    const row = rows[rowIndex]
    setQuickName({
      open: true,
      rowIndex,
      nameType:
        row.accountCode === '1210'
          ? 'customer'
          : row.accountCode === '2110'
            ? 'vendor'
            : 'other',
      displayName: '',
      nameCode: '',
      legalName: '',
      phone: '',
      email: '',
    })
  }

  async function saveQuickName() {
    if (!company || quickName.rowIndex == null || !quickName.displayName.trim()) return
    setSaving(true)
    try {
      const id = await createAccountingName({
        companyId: company.id,
        nameType: quickName.nameType,
        displayName: quickName.displayName.trim(),
        nameCode: quickName.nameCode.trim() || null,
        legalName: quickName.legalName.trim() || null,
        phone: quickName.phone.trim() || null,
        email: quickName.email.trim() || null,
      })
      const results = await searchAccountingNames(
        company.id,
        quickName.displayName,
        quickName.nameType,
        10,
      )
      const created = results.find((item) => item.id === id) ?? results[0]
      if (created) selectName(quickName.rowIndex, created)
      setQuickName((current) => ({ ...current, open: false }))
      setMessage('Name added.')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Unable to create Name.')
    } finally {
      setSaving(false)
    }
  }

  function memorizeCurrent() {
    const name = memoName.trim()
    if (!name) return
    const template = addMemorizedJournalTemplate({
      name,
      rows: rows
        .filter((row) => row.accountId)
        .map((row) => ({
          accountId: row.accountId,
          accountCode: row.accountCode,
          accountName: row.accountName,
          nameId: row.nameId,
          nameCode: row.nameCode,
          nameDisplay: row.nameDisplay,
          memo: row.memo,
          debit: row.debit,
          credit: row.credit,
        })),
    })
    setMemorized((current) => [...current, template])
    setMemoOpen(false)
    setMemoName('')
    setMessage(`Memorized as "${name}".`)
  }

  function loadMemorized(template: MemorizedJournalTemplate) {
    const nextRows: GridRow[] = template.rows.map((source) => ({
      ...emptyRow(),
      accountId: source.accountId,
      accountCode: source.accountCode,
      accountName: source.accountName,
      accountRole: 'posting',
      accountSearch: `${source.accountCode} — ${source.accountName}`,
      nameId: source.nameId,
      nameCode: source.nameCode,
      nameDisplay: source.nameDisplay,
      nameType: source.nameCode ? 'other' : '',
      nameSearch: source.nameCode
        ? `${source.nameCode} — ${source.nameDisplay}`
        : '',
      memo: source.memo,
      debit: source.debit,
      credit: source.credit,
    }))
    while (nextRows.length < INITIAL_ROWS) nextRows.push(emptyRow())
    setRows(nextRows)
    setMoreOpen(false)
  }

  function toggleColumn(column: JournalGridColumn) {
    setPreferences((current) => ({
      ...current,
      visibleColumns: current.visibleColumns.includes(column)
        ? current.visibleColumns.filter((value) => value !== column)
        : [...current.visibleColumns, column],
    }))
  }

  function reorderColumn(column: JournalGridColumn, direction: -1 | 1) {
    setPreferences((current) => {
      const order = [...current.columnOrder]
      const index = order.indexOf(column)
      const target = index + direction
      if (index < 0 || target < 0 || target >= order.length) return current
      ;[order[index], order[target]] = [order[target], order[index]]
      return { ...current, columnOrder: order }
    })
  }

  if (loading) {
    return <section className="journal-loading">Loading Journal Voucher...</section>
  }

  return (
    <section
      className={`journal-window journal-window--${windowMode}`}
      onPaste={handlePaste}
    >
      <header className="journal-titlebar">
        <div className="journal-titlebar-left">
          <FileText size={14} />
          <strong>Journal Voucher</strong>
          <span className="journal-status">{status}</span>
          <span className="journal-doc-chip">
            {journalNumber || journalPreview}
          </span>
        </div>

        <div className="journal-titlebar-right">
          <button type="button" title="Minimize" onClick={() => setWindowMode('minimized')}>
            <Minimize2 size={13} />
          </button>
          <button
            type="button"
            title="Maximize / Restore"
            onClick={() =>
              setWindowMode((current) =>
                current === 'maximized' ? 'normal' : 'maximized',
              )
            }
          >
            <Maximize2 size={13} />
          </button>
          <button type="button" title="Close" onClick={() => window.history.back()}>
            <X size={13} />
          </button>
        </div>
      </header>

      {windowMode !== 'minimized' && (
        <>
          <div className="journal-toolbar">
            <button type="button" onClick={clearForm}>
              <FilePlus2 size={12} /> New
            </button>
            <button type="button" disabled={!journalId || status !== 'draft'}>
              Edit
            </button>
            <button type="button" disabled={!editable || saving} onClick={() => void save()}>
              <Save size={12} /> Save
            </button>
            <button type="button" disabled={!editable || saving} onClick={() => void saveAndNew()}>
              Save &amp; New
            </button>
            <button type="button" disabled={!journalId || status !== 'draft'} onClick={() => void deleteCurrent()}>
              Delete
            </button>
            <button type="button" disabled={!undoStack.length} onClick={undo} title="Undo (Ctrl+Z)">
              <Undo2 size={12} /> Undo
            </button>
            <button type="button" disabled={!redoStack.length} onClick={redo} title="Redo (Ctrl+Y)">
              <Redo2 size={12} /> Redo
            </button>
            <button type="button" disabled={!journalId} onClick={printVoucher}>
              <Printer size={12} /> Print
            </button>

            <div className="journal-menu-wrap">
              <button type="button" onClick={() => setExportOpen((value) => !value)}>
                <Download size={12} /> Export <ChevronDown size={10} />
              </button>
              {exportOpen && (
                <div className="journal-popover">
                  <button type="button" onClick={exportExcel}>Excel</button>
                  <button type="button" onClick={exportCsv}>CSV</button>
                </div>
              )}
            </div>

            <button type="button" disabled={status !== 'posted'} onClick={() => void reverseCurrent()}>
              <RotateCcw size={12} /> Reverse
            </button>
            <button type="button" onClick={() => { setMemoName(journalNumber || 'Recurring Journal'); setMemoOpen(true) }}>
              Memorize
            </button>
            <button type="button" onClick={() => fileRef.current?.click()}>
              <Paperclip size={12} /> Attach
            </button>
            <button type="button" onClick={copyFilledRows}>
              <Copy size={12} /> Copy
            </button>
            <span className="journal-toolbar-grow" />
            <button type="button" onClick={() => setSearchOpen(true)}>
              <Search size={12} /> Find <kbd>Ctrl+F</kbd>
            </button>
            <button type="button" onClick={() => setMoreOpen((value) => !value)}>
              More <ChevronDown size={10} />
            </button>
            <button type="button" onClick={() => setSettingsOpen(true)}>
              <Settings size={13} />
            </button>

            <input ref={fileRef} type="file" hidden multiple onChange={attachFiles} />

            {moreOpen && (
              <div className="journal-popover journal-more-popover">
                <button type="button" onClick={() => void post()}>Post</button>
                <button type="button" onClick={() => setPrintPreviewOpen(true)}>Print Preview</button>
                <button type="button" onClick={copyFilledRows}>Copy all filled lines</button>
                {memorized.map((template) => (
                  <button key={template.id} type="button" onClick={() => loadMemorized(template)}>
                    Use: {template.name}
                  </button>
                ))}
              </div>
            )}
          </div>

          <div className="journal-documentbar">
            <label>
              <span>Date</span>
              <input
                type="date"
                value={entryDate}
                disabled={!editable}
                onChange={(event) => setEntryDate(event.target.value)}
              />
            </label>

            <label className="journal-number-field">
              <span>Journal No.</span>
              <input
                value={manualJournalNumber ? journalNumber : journalPreview}
                disabled={!editable || !manualJournalNumber}
                onChange={(event) => {
                  setManualJournalNumber(true)
                  setJournalNumber(event.target.value)
                }}
              />
              <button
                type="button"
                disabled={!company?.allow_manual_journal_number}
                onClick={() => {
                  setManualJournalNumber((value) => !value)
                  if (!manualJournalNumber) setJournalNumber(journalPreview)
                  else setJournalNumber('')
                }}
              >
                {manualJournalNumber ? 'Manual' : 'Auto'}
              </button>
            </label>

            <label>
              <span>Reference</span>
              <input
                value={referenceNumber}
                disabled={!editable}
                placeholder={referencePreview}
                onChange={(event) => setReferenceNumber(event.target.value)}
              />
            </label>

            {company?.branch_accounting_enabled && (
              <label>
                <span>Branch</span>
                <select
                  value={branchId}
                  disabled={!editable}
                  onChange={(event) => setBranchId(event.target.value)}
                >
                  <option value="">No Branch</option>
                  {branches.map((branch) => (
                    <option key={branch.id} value={branch.id}>
                      {branch.branch_code} — {branch.name}
                    </option>
                  ))}
                </select>
              </label>
            )}

            <div className="journal-documentbar-spacer" />
            {attachments.length > 0 && (
              <span className="journal-attachment-badge">
                <Paperclip size={11} /> {attachments.length}
              </span>
            )}
          </div>

          {error && <div className="journal-alert journal-alert-error">{error}</div>}
          {message && <div className="journal-alert journal-alert-success">{message}</div>}

          <div className="journal-grid-frame">
            <div className="journal-grid-scroll">
              <table ref={tableRef} className="journal-grid">
                <colgroup>
                  {preferences.showRowNumbers && <col style={{ width: '38px' }} />}
                  {visibleColumns.map((column) => (
                    <col
                      key={column}
                      style={{ width: `${preferences.columnWidths[column]}%` }}
                    />
                  ))}
                </colgroup>

                <thead>
                  <tr>
                    {preferences.showRowNumbers && <th>#</th>}
                    {visibleColumns.map((column) => (
                      <th key={column} className={column === 'debit' || column === 'credit' ? 'amount-head' : ''}>
                        {column === 'account'
                          ? 'Account'
                          : column === 'name'
                            ? 'Name'
                            : column === 'memo'
                              ? 'Description'
                              : column === 'debit'
                                ? 'Debit'
                                : 'Credit'}
                      </th>
                    ))}
                  </tr>
                </thead>

                <tbody>
                  {rows.map((row, rowIndex) => (
                    <tr key={row.localId} className={activeRow === rowIndex ? 'active-row' : ''}>
                      {preferences.showRowNumbers && (
                        <td className="row-number">{rowIndex + 1}</td>
                      )}

                      {visibleColumns.map((column) => {
                        if (column === 'account') {
                          return (
                            <td key={column} className="lookup-cell">
                              <div className="lookup-control">
                                <input
                                  data-row={rowIndex}
                                  data-column="account"
                                  value={row.accountSearch}
                                  disabled={!editable}
                                  autoComplete="off"
                                  onFocus={() => {
                                    setActiveRow(rowIndex)
                                    setActiveColumn('account')
                                  }}
                                  onChange={(event) => void accountSearch(rowIndex, event.target.value)}
                                  onKeyDown={(event) => handleCellKeyDown(event, rowIndex, 'account')}
                                />

                                {row.accountOpen && (row.accountResults.length > 0 || row.accountSearch.trim()) && (
                                  <div className="suggestion-panel">
                                    {row.accountResults.map((account) => (
                                      <button
                                        key={account.id}
                                        type="button"
                                        onMouseDown={(event) => event.preventDefault()}
                                        onClick={() => selectAccount(rowIndex, account)}
                                      >
                                        <strong>{account.account_code}</strong>
                                        <span>{account.account_name}</span>
                                      </button>
                                    ))}
                                    {row.accountResults.length === 0 && row.accountSearch.trim() && (
                                      <button type="button" className="suggestion-add" onMouseDown={(event) => event.preventDefault()} onClick={() => setAccountQuickAddOpen(true)}>
                                        <Plus size={11} /> Add Account “{row.accountSearch.trim()}”
                                      </button>
                                    )}
                                  </div>
                                )}
                              </div>
                            </td>
                          )
                        }

                        if (column === 'name') {
                          return (
                            <td key={column} className="lookup-cell">
                              <div className="lookup-control">
                                <input
                                  data-row={rowIndex}
                                  data-column="name"
                                  value={row.nameSearch}
                                  disabled={!editable || !row.allowName}
                                  className={row.nameRequired && !row.nameId ? 'required-cell' : ''}
                                  placeholder={row.nameRequired ? 'Required' : ''}
                                  onFocus={() => {
                                    setActiveRow(rowIndex)
                                    setActiveColumn('name')
                                  }}
                                  onChange={(event) => void nameSearch(rowIndex, event.target.value)}
                                  onKeyDown={(event) => handleCellKeyDown(event, rowIndex, 'name')}
                                />

                                {row.nameOpen && (row.nameResults.length > 0 || row.nameSearch.trim()) && (
                                  <div className="suggestion-panel">
                                    {row.nameResults.map((name) => (
                                      <button
                                        key={name.id}
                                        type="button"
                                        onMouseDown={(event) => event.preventDefault()}
                                        onClick={() => selectName(rowIndex, name)}
                                      >
                                        <strong>{name.name_code}</strong>
                                        <span>{name.display_name}</span>
                                        <small>{name.name_type}</small>
                                      </button>
                                    ))}
                                    {row.nameResults.length === 0 && row.nameSearch.trim() && (
                                      <button type="button" className="suggestion-add" onMouseDown={(event) => event.preventDefault()} onClick={() => addName(rowIndex)}>
                                        <Plus size={11} /> Add Name “{row.nameSearch.trim()}”
                                      </button>
                                    )}
                                  </div>
                                )}
                              </div>
                            </td>
                          )
                        }

                        if (column === 'memo') {
                          return (
                            <td key={column}>
                              <input
                                data-row={rowIndex}
                                data-column="memo"
                                value={row.memo}
                                disabled={!editable}
                                onFocus={() => {
                                  setActiveRow(rowIndex)
                                  setActiveColumn('memo')
                                }}
                                onChange={(event) => updateRow(rowIndex, { memo: event.target.value })}
                                onKeyDown={(event) => handleCellKeyDown(event, rowIndex, 'memo')}
                              />
                            </td>
                          )
                        }

                        return (
                          <td key={column} className="amount-cell">
                            <input
                              data-row={rowIndex}
                              data-column={column}
                              value={column === 'debit' ? row.debit : row.credit}
                              disabled={!editable}
                              inputMode="decimal"
                              placeholder={preferences.amountExpressions ? 'Expression' : ''}
                              onFocus={() => {
                                setActiveRow(rowIndex)
                                setActiveColumn(column)
                              }}
                              onChange={(event) => updateAmount(rowIndex, column, event.target.value)}
                              onBlur={() => {
                                if (preferences.amountExpressions) {
                                  const source = column === 'debit' ? row.debit : row.credit
                                  if (source.trim()) {
                                    updateRow(rowIndex, {
                                      [column]: String(numeric(source)),
                                    })
                                  }
                                }
                              }}
                              onKeyDown={(event) => handleCellKeyDown(event, rowIndex, column)}
                            />
                          </td>
                        )
                      })}
                    </tr>
                  ))}
                </tbody>

                <tfoot className={preferences.stickyTotals ? 'sticky-total' : ''}>
                  <tr>
                    {preferences.showRowNumbers && <td />}
                    {visibleColumns.map((column, index) => {
                      if (column === 'debit') {
                        return (
                          <td key={column} className="total-amount">
                            {money(totals.debit, decimals, preferences.thousandsSeparator)}
                          </td>
                        )
                      }
                      if (column === 'credit') {
                        return (
                          <td key={column} className="total-amount">
                            {money(totals.credit, decimals, preferences.thousandsSeparator)}
                          </td>
                        )
                      }
                      if (index === 0) {
                        return (
                          <td key={column} className="total-label">TOTAL</td>
                        )
                      }
                      return <td key={column} />
                    })}
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <div className="journal-grid-statusbar">
            <div className="cell-navigation">
              <button
                type="button"
                disabled={activeRow == null || activeColumn == null}
                onClick={() => {
                  if (activeRow == null || activeColumn == null) return
                  focusCell(activeRow, COLUMNS.indexOf(activeColumn) - 1)
                }}
              >
                <ArrowLeft size={12} /> Previous Cell
              </button>
              <button
                type="button"
                disabled={activeRow == null || activeColumn == null}
                onClick={() => {
                  if (activeRow == null || activeColumn == null) return
                  const current = COLUMNS.indexOf(activeColumn)
                  if (current === COLUMNS.length - 1) {
                    if (activeRow === rows.length - 1) ensureRows(rows.length + 1)
                    window.setTimeout(() => focusCell(activeRow + 1, 0), 0)
                  } else {
                    focusCell(activeRow, current + 1)
                  }
                }}
              >
                Next Cell <ArrowRight size={12} />
              </button>
            </div>

            <div className="journal-grid-state">
              <span>{totals.entered} lines</span>
              <span className={totals.balanced ? 'balanced' : 'unbalanced'}>
                {totals.balanced ? 'Balanced' : 'Out of Balance'}
              </span>
              <span>
                Difference {money(totals.difference, decimals, preferences.thousandsSeparator)}
              </span>
            </div>

            <button type="button" onClick={copyFilledRows} className="copy-status-button">
              <Copy size={12} /> Copy Filled
            </button>
          </div>

          {attachments.length > 0 && (
            <div className="journal-attachments">
              <strong><Paperclip size={11} /> Attachments</strong>
              {attachments.map((attachment) => (
                <div key={attachment.id} className="attachment-chip">
                  <span>{attachment.file.name}</span>
                  <button type="button" onClick={() => downloadAttachment(attachment)}>Open</button>
                  <button type="button" onClick={() => setAttachments((current) => current.filter((item) => item.id !== attachment.id))}>
                    <X size={10} />
                  </button>
                </div>
              ))}
            </div>
          )}

          <footer className="journal-footer">
            <div className="shortcut-strip">
              Ctrl+S Save · Alt+N Save &amp; New · Ctrl+F Find · Ctrl+P Print · Ctrl+Enter Post
            </div>
            <div className="footer-actions">
              <button type="button" onClick={clearForm} disabled={!editable}>Clear</button>
              <button type="button" onClick={() => void save()} disabled={!editable || saving} className="primary">
                Save
              </button>
              <button type="button" onClick={() => void saveAndNew()} disabled={!editable || saving} className="primary">
                Save &amp; New
              </button>
            </div>
          </footer>
        </>
      )}

      {settingsOpen && (
        <div className="journal-overlay">
          <section className="settings-panel">
            <header className="panel-header">
              <div>
                <small>JOURNAL WORKSPACE</small>
                <h2>Advanced Preferences</h2>
                <p>Control the journal workstation, grid behavior, numbering, display and keyboard workflow.</p>
              </div>
              <button type="button" onClick={() => setSettingsOpen(false)}><X size={16} /></button>
            </header>

            <div className="settings-layout">
              <aside className="settings-nav">
                {([
                  ['workspace', 'Workspace'],
                  ['grid', 'Grid'],
                  ['columns', 'Columns'],
                  ['amounts', 'Amounts'],
                  ['numbering', 'Numbering'],
                  ['shortcuts', 'Shortcuts'],
                  ['printing', 'Printing'],
                ] as const).map(([key, label]) => (
                  <button
                    type="button"
                    key={key}
                    className={settingsSection === key ? 'selected' : ''}
                    onClick={() => setSettingsSection(key)}
                  >
                    {label}
                  </button>
                ))}
              </aside>

              <div className="settings-content">
                <section className={`settings-section ${settingsSection === 'workspace' || settingsSection === 'grid' ? 'settings-visible' : 'settings-hidden'}`}><h3>{settingsSection === 'grid' ? 'Grid' : 'Workspace &amp; Grid'}</h3>
                  <div className="settings-grid">
                    <label>
                      <span>Row density</span>
                      <select value={preferences.density} onChange={(event) => setPreferences((current) => ({ ...current, density: event.target.value as JournalGridPreferences['density'] }))}>
                        <option value="compact">Compact</option>
                        <option value="standard">Standard</option>
                        <option value="comfortable">Comfortable</option>
                      </select>
                    </label>
                    <label>
                      <span>Enter behavior</span>
                      <select value={preferences.enterMoves} onChange={(event) => setPreferences((current) => ({ ...current, enterMoves: event.target.value as JournalGridPreferences['enterMoves'] }))}>
                        <option value="down">Same column / next row</option>
                        <option value="next-cell">Next cell</option>
                      </select>
                    </label>
                    <label>
                      <span>Default focus</span>
                      <select value={preferences.defaultFocus} onChange={(event) => setPreferences((current) => ({ ...current, defaultFocus: event.target.value as JournalGridColumn }))}>
                        {COLUMNS.map((column) => <option key={column} value={column}>{column}</option>)}
                      </select>
                    </label>
                  </div>
                  <div className="check-grid">
                    <label><input type="checkbox" checked={preferences.autoExpandRows} onChange={(event) => setPreferences((current) => ({ ...current, autoExpandRows: event.target.checked }))} /> Auto-expand rows</label>
                    <label><input type="checkbox" checked={preferences.freezeAccount} onChange={(event) => setPreferences((current) => ({ ...current, freezeAccount: event.target.checked }))} /> Freeze Account</label>
                    <label><input type="checkbox" checked={preferences.stickyTotals} onChange={(event) => setPreferences((current) => ({ ...current, stickyTotals: event.target.checked }))} /> Keep totals visible</label>
                    <label><input type="checkbox" checked={preferences.showRowNumbers} onChange={(event) => setPreferences((current) => ({ ...current, showRowNumbers: event.target.checked }))} /> Show row numbers</label>
                    <label><input type="checkbox" checked={preferences.showKeyboardHints} onChange={(event) => setPreferences((current) => ({ ...current, showKeyboardHints: event.target.checked }))} /> Show shortcut hints</label>
                    <label><input type="checkbox" checked={preferences.rememberLayout} onChange={(event) => setPreferences((current) => ({ ...current, rememberLayout: event.target.checked }))} /> Remember layout</label>
                  </div>
                </section>

                <section className={`settings-section ${settingsSection === 'columns' ? 'settings-visible' : 'settings-hidden'}`}><h3>Columns &amp; Widths</h3>
                  {COLUMNS.map((column) => (
                    <div className="column-setting" key={column}>
                      <label>
                        <input type="checkbox" checked={preferences.visibleColumns.includes(column)} onChange={() => toggleColumn(column)} />
                        <span>{column === 'memo' ? 'Description' : column[0].toUpperCase() + column.slice(1)}</span>
                      </label>
                      <input
                        type="number"
                        min={5}
                        max={60}
                        value={preferences.columnWidths[column]}
                        onChange={(event) => setPreferences((current) => ({
                          ...current,
                          columnWidths: {
                            ...current.columnWidths,
                            [column]: Math.max(5, Math.min(60, Number(event.target.value) || current.columnWidths[column])),
                          },
                        }))}
                      />
                      <div>
                        <button type="button" onClick={() => reorderColumn(column, -1)}><ArrowUp size={10} /></button>
                        <button type="button" onClick={() => reorderColumn(column, 1)}><ArrowDown size={10} /></button>
                      </div>
                    </div>
                  ))}
                </section>

                <section className={`settings-section ${settingsSection === 'amounts' ? 'settings-visible' : 'settings-hidden'}`}><h3>Amounts</h3>
                  <div className="settings-grid">
                    <label>
                      <span>Decimals</span>
                      <input type="number" min={0} max={6} value={preferences.amountDecimals} onChange={(event) => setPreferences((current) => ({ ...current, amountDecimals: Math.max(0, Math.min(6, Number(event.target.value) || 2)) }))} />
                    </label>
                  </div>
                  <div className="check-grid">
                    <label><input type="checkbox" checked={preferences.amountExpressions} onChange={(event) => setPreferences((current) => ({ ...current, amountExpressions: event.target.checked }))} /> Allow + − × ÷ and parentheses</label>
                    <label><input type="checkbox" checked={preferences.thousandsSeparator} onChange={(event) => setPreferences((current) => ({ ...current, thousandsSeparator: event.target.checked }))} /> Thousands separator</label>
                  </div>
                  <div className="info-card">Examples: <strong>1000+250</strong>, <strong>500*4</strong>, <strong>(1000+500)/2</strong></div>
                </section>

                <section className={`settings-section ${settingsSection === 'numbering' ? 'settings-visible' : 'settings-hidden'}`}><h3>Reference Number Format</h3>
                  <div className="settings-grid">
                    <label><span>Prefix</span><input value={preferences.referenceFormat.prefix} onChange={(event) => setPreferences((current) => ({ ...current, referenceFormat: { ...current.referenceFormat, prefix: event.target.value } }))} /></label>
                    <label><span>Separator</span><input value={preferences.referenceFormat.separator} onChange={(event) => setPreferences((current) => ({ ...current, referenceFormat: { ...current.referenceFormat, separator: event.target.value } }))} /></label>
                    <label><span>Padding</span><input type="number" min={1} max={10} value={preferences.referenceFormat.numberPadding} onChange={(event) => setPreferences((current) => ({ ...current, referenceFormat: { ...current.referenceFormat, numberPadding: Math.max(1, Math.min(10, Number(event.target.value) || 4)) } }))} /></label>
                    <label><span>Date format</span><select value={preferences.referenceFormat.dateFormat} onChange={(event) => setPreferences((current) => ({ ...current, referenceFormat: { ...current.referenceFormat, dateFormat: event.target.value as JournalGridPreferences['referenceFormat']['dateFormat'] } }))}><option value="DDMMYYYY">DDMMYYYY</option><option value="MMDDYYYY">MMDDYYYY</option><option value="YYYYMMDD">YYYYMMDD</option></select></label>
                  </div>
                  <div className="check-grid">
                    <label><input type="checkbox" checked={preferences.referenceFormat.includeYear} onChange={(event) => setPreferences((current) => ({ ...current, referenceFormat: { ...current.referenceFormat, includeYear: event.target.checked } }))} /> Include year</label>
                    <label><input type="checkbox" checked={preferences.referenceFormat.includeDate} onChange={(event) => setPreferences((current) => ({ ...current, referenceFormat: { ...current.referenceFormat, includeDate: event.target.checked } }))} /> Include date</label>
                    <label><input type="checkbox" checked={preferences.showReferencePreview} onChange={(event) => setPreferences((current) => ({ ...current, showReferencePreview: event.target.checked }))} /> Show format preview</label>
                  </div>
                  <div className="format-preview">
                    <span>Preview</span>
                    <strong>{referencePreview}</strong>
                  </div>
                </section>
                {settingsSection === 'shortcuts' && (
                  <section className="settings-section settings-visible">
                    <h3>Keyboard Shortcuts</h3>
                    <div className="shortcut-reference">
                      <div><kbd>Ctrl+S</kbd><span>Save</span></div>
                      <div><kbd>Alt+N</kbd><span>Save &amp; New</span></div>
                      <div><kbd>Ctrl+F</kbd><span>Find</span></div>
                      <div><kbd>Ctrl+P</kbd><span>Print Preview</span></div>
                      <div><kbd>Ctrl+Z</kbd><span>Undo</span></div>
                      <div><kbd>Ctrl+Y</kbd><span>Redo</span></div>
                      <div><kbd>↑ ↓ ← →</kbd><span>Cell movement</span></div>
                      <div><kbd>Enter / Tab</kbd><span>Grid navigation</span></div>
                    </div>
                  </section>
                )}

                {settingsSection === 'printing' && (
                  <section className="settings-section settings-visible">
                    <h3>Printing &amp; Export</h3>
                    <div className="settings-grid">
                      <label><span>Paper</span><select value={preferences.printPaperSize} onChange={(event) => setPreferences((c) => ({ ...c, printPaperSize: event.target.value as JournalGridPreferences['printPaperSize'] }))}><option value="A4">A4</option><option value="LETTER">Letter</option></select></label>
                      <label><span>Orientation</span><select value={preferences.printOrientation} onChange={(event) => setPreferences((c) => ({ ...c, printOrientation: event.target.value as JournalGridPreferences['printOrientation'] }))}><option value="portrait">Portrait</option><option value="landscape">Landscape</option></select></label>
                      <label><span>Margins</span><select value={preferences.printMargins} onChange={(event) => setPreferences((c) => ({ ...c, printMargins: event.target.value as JournalGridPreferences['printMargins'] }))}><option value="compact">Compact</option><option value="standard">Standard</option><option value="wide">Wide</option></select></label>
                    </div>
                    <div className="check-grid">
                      <label><input type="checkbox" checked={preferences.exportIncludeHeader} onChange={(event) => setPreferences((c) => ({ ...c, exportIncludeHeader: event.target.checked }))} /> Include document/company header in export</label>
                      <label><input type="checkbox" checked={preferences.printShowCompanyDetails} onChange={(event) => setPreferences((c) => ({ ...c, printShowCompanyDetails: event.target.checked }))} /> Show company details</label>
                      <label><input type="checkbox" checked={preferences.printShowLogo} onChange={(event) => setPreferences((c) => ({ ...c, printShowLogo: event.target.checked }))} /> Show logo</label>
                      <label><input type="checkbox" checked={preferences.printShowApprovalLines} onChange={(event) => setPreferences((c) => ({ ...c, printShowApprovalLines: event.target.checked }))} /> Show approval lines</label>
                    </div>
                  </section>
                )}
              </div>
            </div>

            <footer className="panel-footer">
              <button type="button" onClick={() => setPreferences(resetJournalGridPreferences())}>Reset All</button>
              <button type="button" className="primary" onClick={() => setSettingsOpen(false)}>Done</button>
            </footer>
          </section>
        </div>
      )}

      {searchOpen && (
        <div className="journal-overlay">
          <section className="search-panel">
            <header className="panel-header">
              <div><small>TRANSACTION FINDER</small><h2>Find Journal Vouchers</h2><p>Search across journal number, date, reference, account, name, amount and description.</p></div>
              <button type="button" onClick={() => setSearchOpen(false)}><X size={16} /></button>
            </header>
            <div className="search-filters">
              <input
                className="search-main"
                autoFocus
                placeholder="Search all fields..."
                value={searchFilters.search}
                onChange={(event) => setSearchFilters((current) => ({ ...current, search: event.target.value }))}
                onKeyDown={(event) => { if (event.key === 'Enter') void searchPrevious() }}
              />
              <div className="search-grid">
                <label><span>Date From</span><input type="date" value={searchFilters.dateFrom} onChange={(event) => setSearchFilters((current) => ({ ...current, dateFrom: event.target.value }))} /></label>
                <label><span>Date To</span><input type="date" value={searchFilters.dateTo} onChange={(event) => setSearchFilters((current) => ({ ...current, dateTo: event.target.value }))} /></label>
                <label><span>Reference From</span><input value={searchFilters.referenceFrom} onChange={(event) => setSearchFilters((current) => ({ ...current, referenceFrom: event.target.value }))} /></label>
                <label><span>Reference To</span><input value={searchFilters.referenceTo} onChange={(event) => setSearchFilters((current) => ({ ...current, referenceTo: event.target.value }))} /></label>
                <label><span>Amount From</span><input value={searchFilters.amountFrom} onChange={(event) => setSearchFilters((current) => ({ ...current, amountFrom: event.target.value }))} /></label>
                <label><span>Amount To</span><input value={searchFilters.amountTo} onChange={(event) => setSearchFilters((current) => ({ ...current, amountTo: event.target.value }))} /></label>
                <label><span>Reference Type</span><select value={searchFilters.referenceType} onChange={(event) => setSearchFilters((current) => ({ ...current, referenceType: event.target.value }))}><option value="">Any</option>{documents.map((document) => <option key={document.code} value={document.code}>{document.code}</option>)}</select></label>
                <label><span>Status</span><select value={searchFilters.status} onChange={(event) => setSearchFilters((current) => ({ ...current, status: event.target.value }))}><option value="">Any</option><option value="draft">Draft</option><option value="posted">Posted</option><option value="reversed">Reversed</option><option value="void">Void</option></select></label>
              </div>
              <button type="button" className="primary" onClick={() => void searchPrevious()} disabled={searchLoading}><Search size={12} /> {searchLoading ? 'Searching...' : 'Search'}</button>
            </div>
            <div className="search-results">
              <table>
                <thead><tr><th>Journal</th><th>Date</th><th>Reference</th><th>Account</th><th>Name</th><th>Debit</th><th>Credit</th><th>Status</th></tr></thead>
                <tbody>
                  {searchResults.map((result) => (
                    <tr key={result.id} tabIndex={0} onDoubleClick={() => void openPrevious(result)} onKeyDown={(event) => { if (event.key === 'Enter') void openPrevious(result) }}>
                      <td>{result.journal_number}</td>
                      <td>{result.entry_date}</td>
                      <td>{result.reference_number ?? '—'}</td>
                      <td>{result.matched_accounts ?? result.description ?? '—'}</td>
                      <td>{result.matched_names ?? '—'}</td>
                      <td className="amount-head">{money(result.total_debit, decimals)}</td>
                      <td className="amount-head">{money(result.total_credit, decimals)}</td>
                      <td>{result.status}</td>
                    </tr>
                  ))}
                  {!searchLoading && searchResults.length === 0 && <tr><td colSpan={8} className="empty-search">No matching Journal Vouchers.</td></tr>}
                </tbody>
              </table>
            </div>
          </section>
        </div>
      )}

      {printPreviewOpen && (
        <div className="journal-overlay journal-print-overlay">
          <section className="print-window">
            <header className="panel-header no-print">
              <div><small>PRINT PREVIEW</small><h2>Journal Voucher · A4</h2></div>
              <div className="print-head-actions">
                <button type="button" className="primary" onClick={printVoucher}><Printer size={12} /> Print</button>
                <button type="button" onClick={() => setPrintPreviewOpen(false)}><X size={16} /></button>
              </div>
            </header>

            <div className={`print-stage ${preferences.printOrientation === 'landscape' ? 'landscape' : ''}`}>
              <article className="print-paper">
                <header className="print-company-header">
                  {preferences.printShowLogo && (
                    company?.logo_url ? <img className="print-logo-image" src={company.logo_url} alt="Company logo" /> : <div className="print-logo-fallback">{(company?.display_name || company?.legal_name || 'C').slice(0,1).toUpperCase()}</div>
                  )}
                  {preferences.printShowCompanyDetails && (
                    <div className="print-company-details">
                      <h1>{company?.display_name || company?.legal_name || 'Company'}</h1>
                      <strong>{company?.legal_name || ''}</strong>
                      <p>{[company?.address_line_1, company?.address_line_2, company?.city, company?.state, company?.postal_code].filter(Boolean).join(', ')}</p>
                      <p>{[company?.phone && `Tel: ${company.phone}`, company?.email && `Email: ${company.email}`, company?.website].filter(Boolean).join('  •  ')}</p>
                      <p>{[company?.registration_number && `Reg: ${company.registration_number}`, company?.tax_registration_number && `Tax: ${company.tax_registration_number}`].filter(Boolean).join('  •  ')}</p>
                    </div>
                  )}
                  <div className="print-document-heading">
                    <small>ACCOUNTING DOCUMENT</small>
                    <h2>JOURNAL VOUCHER</h2>
                    <strong>{journalNumber || journalPreview}</strong>
                  </div>
                </header>

                <div className="print-rule" />

                <div className="print-meta-grid">
                  <div><span>Date</span><strong>{entryDate}</strong></div>
                  <div><span>Journal Number</span><strong>{journalNumber || journalPreview}</strong></div>
                  <div><span>Reference</span><strong>{referenceNumber || referencePreview}</strong></div>
                  {company?.branch_accounting_enabled && <div><span>Branch</span><strong>{branches.find((branch) => branch.id === branchId)?.name || '—'}</strong></div>}
                  <div><span>Status</span><strong>{status.toUpperCase()}</strong></div>
                </div>

                <table className="print-ledger">
                  <thead><tr><th>#</th><th>Account</th><th>Name</th><th>Description</th><th className="amount-head">Debit</th><th className="amount-head">Credit</th></tr></thead>
                  <tbody>
                    {rows.filter((row) => row.accountId).map((row, index) => (
                      <tr key={row.localId}>
                        <td>{index + 1}</td>
                        <td><strong>{row.accountCode}</strong><span className="print-subtext">{row.accountName}</span></td>
                        <td>{row.nameDisplay || '—'}</td>
                        <td>{row.memo || '—'}</td>
                        <td className="amount-head">{row.debit ? money(numeric(row.debit), decimals, preferences.thousandsSeparator) : ''}</td>
                        <td className="amount-head">{row.credit ? money(numeric(row.credit), decimals, preferences.thousandsSeparator) : ''}</td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot><tr><td colSpan={4}>TOTAL</td><td className="amount-head">{money(totals.debit, decimals, preferences.thousandsSeparator)}</td><td className="amount-head">{money(totals.credit, decimals, preferences.thousandsSeparator)}</td></tr></tfoot>
                </table>

                <div className="print-balance-summary">
                  <span>Balance Difference</span>
                  <strong>{money(totals.difference, decimals, preferences.thousandsSeparator)}</strong>
                  <em>{totals.balanced ? 'BALANCED' : 'OUT OF BALANCE'}</em>
                </div>

                {preferences.printShowApprovalLines && (
                  <div className="print-approval-grid">
                    <div><span>Prepared By</span><i /></div>
                    <div><span>Reviewed By</span><i /></div>
                    <div><span>Approved By</span><i /></div>
                  </div>
                )}

                <footer className="print-footer">
                  <span>Printed {new Date().toLocaleString()}</span>
                  <span>{company?.company_code || ''}</span>
                  <strong>Elvaris</strong>
                </footer>
              </article>
            </div>
          </section>
        </div>
      )}

      {memoOpen && (
        <div className="journal-overlay">
          <section className="small-panel">
            <header className="panel-header"><div><small>MEMORIZED TRANSACTION</small><h2>Memorize Journal</h2></div><button type="button" onClick={() => setMemoOpen(false)}><X size={16} /></button></header>
            <div className="small-body"><label><span>Template Name</span><input autoFocus value={memoName} onChange={(event) => setMemoName(event.target.value)} /></label></div>
            <footer className="panel-footer"><button type="button" onClick={() => setMemoOpen(false)}>Cancel</button><button type="button" className="primary" disabled={!memoName.trim()} onClick={memorizeCurrent}>Memorize</button></footer>
          </section>
        </div>
      )}

      {quickName.open && (
        <div className="journal-overlay">
          <section className="small-panel">
            <header className="panel-header"><div><small>INLINE MASTER DATA</small><h2>Add Name</h2></div><button type="button" onClick={() => setQuickName((current) => ({ ...current, open: false }))}><X size={16} /></button></header>
            <div className="small-body form-grid">
              <label><span>Type</span><select value={quickName.nameType} onChange={(event) => setQuickName((current) => ({ ...current, nameType: event.target.value as QuickName['nameType'] }))}><option value="customer">Customer</option><option value="vendor">Vendor</option><option value="employee">Employee</option><option value="other">Other</option></select></label>
              <label><span>Name</span><input value={quickName.displayName} onChange={(event) => setQuickName((current) => ({ ...current, displayName: event.target.value }))} /></label>
              <label><span>Code</span><input value={quickName.nameCode} onChange={(event) => setQuickName((current) => ({ ...current, nameCode: event.target.value }))} /></label>
              <label><span>Legal Name</span><input value={quickName.legalName} onChange={(event) => setQuickName((current) => ({ ...current, legalName: event.target.value }))} /></label>
              <label><span>Phone</span><input value={quickName.phone} onChange={(event) => setQuickName((current) => ({ ...current, phone: event.target.value }))} /></label>
              <label><span>Email</span><input value={quickName.email} onChange={(event) => setQuickName((current) => ({ ...current, email: event.target.value }))} /></label>
            </div>
            <footer className="panel-footer"><button type="button" onClick={() => setQuickName((current) => ({ ...current, open: false }))}>Cancel</button><button type="button" className="primary" disabled={saving || !quickName.displayName.trim()} onClick={() => void saveQuickName()}><Check size={12} /> Save Name</button></footer>
          </section>
        </div>
      )}

      {accountQuickAddOpen && (
        <div className="journal-overlay">
          <section className="small-panel account-add-panel">
            <header className="panel-header"><div><small>CHART OF ACCOUNTS</small><h2>Add Account</h2></div><button type="button" onClick={() => setAccountQuickAddOpen(false)}><X size={16} /></button></header>
            <div className="small-body">
              <p className="account-add-message">The current journal service exposes Account search but not the COA creation contract. I have kept the + control real and safe rather than inventing RPC parameters that could damage the chart of accounts.</p>
              <p className="account-add-message">Once the existing <strong>create_coa_account</strong> routine signature is connected to the service, this panel can become a full inline account creator without changing the journal grid.</p>
            </div>
            <footer className="panel-footer"><button type="button" onClick={() => setAccountQuickAddOpen(false)}>Close</button></footer>
          </section>
        </div>
      )}
    </section>
  )
}

export default JournalVoucherPage

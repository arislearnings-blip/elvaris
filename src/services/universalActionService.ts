export type ExportColumn = {
  key: string
  label: string
}

export type ExportRow = Record<string, unknown>

export type PrintOptions = {
  title: string
  html: string
  autoPrint?: boolean
}

export type MemorizedView = {
  id: string
  name: string
  sheetKey: string
  state: unknown
  createdAt: string
}

const MEMORIZED_VIEWS_KEY = 'elvaris.memorizedViews.v1'

function escapeHtml(value: unknown): string {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;')
}

function downloadBlob(
  content: string,
  fileName: string,
  mimeType: string,
): void {
  const blob = new Blob([content], {
    type: mimeType,
  })

  const url = URL.createObjectURL(blob)

  const anchor = document.createElement('a')

  anchor.href = url
  anchor.download = fileName

  document.body.appendChild(anchor)

  anchor.click()

  anchor.remove()

  URL.revokeObjectURL(url)
}

export function printDocument(
  options: PrintOptions,
): void {
  const printWindow = window.open(
    '',
    '_blank',
    'noopener,noreferrer,width=1100,height=800',
  )

  if (!printWindow) {
    throw new Error(
      'Elvaris could not open the print window. Please allow pop-ups for this application.',
    )
  }

  printWindow.document.open()

  printWindow.document.write(`
<!doctype html>
<html>
<head>
  <title>${escapeHtml(options.title)}</title>

  <meta charset="utf-8">

  <style>
    @page {
      margin: 14mm;
    }

    body {
      font-family: Arial, sans-serif;
      color: #172554;
      margin: 0;
      font-size: 12px;
    }

    table {
      width: 100%;
      border-collapse: collapse;
    }

    th,
    td {
      border: 1px solid #dbe2ea;
      padding: 7px 8px;
      text-align: left;
    }

    th {
      background: #f1f5f9;
      font-weight: 700;
    }

    h1,
    h2,
    h3,
    p {
      margin-top: 0;
    }

    .print-header {
      margin-bottom: 18px;
      border-bottom: 2px solid #1d4ed8;
      padding-bottom: 10px;
    }

    .print-meta {
      color: #64748b;
      font-size: 11px;
    }

    @media print {
      .no-print {
        display: none !important;
      }
    }
  </style>
</head>

<body>

  <div class="print-header">
    <h1>${escapeHtml(options.title)}</h1>

    <div class="print-meta">
      Elvaris Enterprise Management Platform
    </div>
  </div>

  ${options.html}

</body>
</html>
`)

  printWindow.document.close()

  if (options.autoPrint !== false) {
    printWindow.addEventListener(
      'load',
      () => {
        printWindow.focus()
        printWindow.print()
      },
      { once: true },
    )
  }
}

export function printPreview(
  options: PrintOptions,
): void {
  printDocument({
    ...options,
    autoPrint: false,
  })
}

export function exportCsv(
  rows: ExportRow[],
  columns: ExportColumn[],
  fileName: string,
): void {
  const csvCell = (
    value: unknown,
  ): string => {
    const text = String(value ?? '')

    return /[",\n\r]/.test(text)
      ? `"${text.replaceAll('"', '""')}"`
      : text
  }

  const content = [
    columns
      .map((column) =>
        csvCell(column.label),
      )
      .join(','),

    ...rows.map((row) =>
      columns
        .map((column) =>
          csvCell(row[column.key]),
        )
        .join(','),
    ),
  ].join('\r\n')

  downloadBlob(
    `\ufeff${content}`,
    fileName.endsWith('.csv')
      ? fileName
      : `${fileName}.csv`,
    'text/csv;charset=utf-8',
  )
}

export function exportExcel(
  rows: ExportRow[],
  columns: ExportColumn[],
  fileName: string,
): void {
  const header = columns
    .map(
      (column) =>
        `<th>${escapeHtml(
          column.label,
        )}</th>`,
    )
    .join('')

  const body = rows
    .map(
      (row) =>
        `<tr>${columns
          .map(
            (column) =>
              `<td>${escapeHtml(
                row[column.key],
              )}</td>`,
          )
          .join('')}</tr>`,
    )
    .join('')

  const html = `
<!doctype html>

<html>

<head>
  <meta charset="utf-8">
</head>

<body>

<table>

<thead>

<tr>
  ${header}
</tr>

</thead>

<tbody>

${body}

</tbody>

</table>

</body>

</html>
`

  downloadBlob(
    `\ufeff${html}`,
    fileName.endsWith('.xls')
      ? fileName
      : `${fileName}.xls`,
    'application/vnd.ms-excel;charset=utf-8',
  )
}

export function getMemorizedViews(
  sheetKey?: string,
): MemorizedView[] {
  try {
    const raw =
      localStorage.getItem(
        MEMORIZED_VIEWS_KEY,
      )

    const views = raw
      ? (JSON.parse(raw) as MemorizedView[])
      : []

    return sheetKey
      ? views.filter(
          (view) =>
            view.sheetKey === sheetKey,
        )
      : views
  } catch {
    return []
  }
}

export function memorizeView(
  sheetKey: string,
  name: string,
  state: unknown,
): MemorizedView {
  const view: MemorizedView = {
    id: crypto.randomUUID(),

    name:
      name.trim() ||
      'Memorized View',

    sheetKey,

    state,

    createdAt:
      new Date().toISOString(),
  }

  const views =
    getMemorizedViews()

  localStorage.setItem(
    MEMORIZED_VIEWS_KEY,
    JSON.stringify([
      ...views,
      view,
    ]),
  )

  return view
}

export function deleteMemorizedView(
  id: string,
): void {
  const views =
    getMemorizedViews().filter(
      (view) =>
        view.id !== id,
    )

  localStorage.setItem(
    MEMORIZED_VIEWS_KEY,
    JSON.stringify(views),
  )
}


// ============================================================
// ELVARIS UNIVERSAL ACTION SYSTEM
// ============================================================

export type UniversalActionId =
  | 'new'
  | 'save'
  | 'saveAndNew'
  | 'edit'
  | 'duplicate'
  | 'delete'
  | 'attach'
  | 'print'
  | 'printPreview'
  | 'pdf'
  | 'excel'
  | 'csv'
  | 'memorize'
  | 'export'
  | 'refresh'
  | 'close'
  | 'cancel'
  | 'email'
  | 'share'
  | 'search'
  | 'filter'
  | 'sort'
  | 'columns'
  | 'import'
  | 'history'
  | 'void'
  | 'reverse'
  | 'approve'
  | 'reject'
  | 'post'
  | 'unpost'
  | 'lock'
  | 'unlock'
  | 'restore'
  | 'printBatch'
  | 'emailBatch'
  | 'shareLink'

export type UniversalActionDefinition = {
  id: UniversalActionId
  label: string
  icon?: string
  category:
    | 'record'
    | 'document'
    | 'data'
    | 'communication'
    | 'workflow'
    | 'navigation'
  requiresRecord?: boolean
  requiresEditMode?: boolean
  destructive?: boolean
  conditional?: boolean
}

export const UNIVERSAL_ACTIONS: Record<
  UniversalActionId,
  UniversalActionDefinition
> = {
  new: {
    id: 'new',
    label: 'New',
    category: 'record',
  },

  save: {
    id: 'save',
    label: 'Save',
    category: 'record',
    requiresEditMode: true,
  },

  saveAndNew: {
    id: 'saveAndNew',
    label: 'Save & New',
    category: 'record',
    requiresEditMode: true,
  },

  edit: {
    id: 'edit',
    label: 'Edit',
    category: 'record',
    requiresRecord: true,
  },

  duplicate: {
    id: 'duplicate',
    label: 'Duplicate',
    category: 'record',
    requiresRecord: true,
  },

  delete: {
    id: 'delete',
    label: 'Delete',
    category: 'record',
    requiresRecord: true,
    destructive: true,
  },

  attach: {
    id: 'attach',
    label: 'Attach',
    category: 'document',
    requiresRecord: true,
  },

  print: {
    id: 'print',
    label: 'Print',
    category: 'document',
    requiresRecord: true,
  },

  printPreview: {
    id: 'printPreview',
    label: 'Print Preview',
    category: 'document',
    requiresRecord: true,
  },

  pdf: {
    id: 'pdf',
    label: 'PDF',
    category: 'document',
    requiresRecord: true,
  },

  excel: {
    id: 'excel',
    label: 'Excel',
    category: 'data',
  },

  csv: {
    id: 'csv',
    label: 'CSV',
    category: 'data',
  },

  memorize: {
    id: 'memorize',
    label: 'Memorize',
    category: 'data',
  },

  export: {
    id: 'export',
    label: 'Export',
    category: 'data',
  },

  refresh: {
    id: 'refresh',
    label: 'Refresh',
    category: 'navigation',
  },

  close: {
    id: 'close',
    label: 'Close',
    category: 'navigation',
  },

  cancel: {
    id: 'cancel',
    label: 'Cancel',
    category: 'navigation',
  },

  email: {
    id: 'email',
    label: 'Email',
    category: 'communication',
    requiresRecord: true,
  },

  share: {
    id: 'share',
    label: 'Share',
    category: 'communication',
    requiresRecord: true,
  },

  search: {
    id: 'search',
    label: 'Search',
    category: 'data',
  },

  filter: {
    id: 'filter',
    label: 'Filter',
    category: 'data',
  },

  sort: {
    id: 'sort',
    label: 'Sort',
    category: 'data',
  },

  columns: {
    id: 'columns',
    label: 'Columns',
    category: 'data',
  },

  import: {
    id: 'import',
    label: 'Import',
    category: 'data',
  },

  history: {
    id: 'history',
    label: 'History',
    category: 'data',
    requiresRecord: true,
  },

  void: {
    id: 'void',
    label: 'Void',
    category: 'workflow',
    requiresRecord: true,
    destructive: true,
    conditional: true,
  },

  reverse: {
    id: 'reverse',
    label: 'Reverse',
    category: 'workflow',
    requiresRecord: true,
    destructive: true,
    conditional: true,
  },

  approve: {
    id: 'approve',
    label: 'Approve',
    category: 'workflow',
    requiresRecord: true,
    conditional: true,
  },

  reject: {
    id: 'reject',
    label: 'Reject',
    category: 'workflow',
    requiresRecord: true,
    conditional: true,
  },

  post: {
    id: 'post',
    label: 'Post',
    category: 'workflow',
    requiresRecord: true,
    conditional: true,
  },

  unpost: {
    id: 'unpost',
    label: 'Unpost',
    category: 'workflow',
    requiresRecord: true,
    conditional: true,
  },

  lock: {
    id: 'lock',
    label: 'Lock',
    category: 'workflow',
    requiresRecord: true,
    conditional: true,
  },

  unlock: {
    id: 'unlock',
    label: 'Unlock',
    category: 'workflow',
    requiresRecord: true,
    conditional: true,
  },

  restore: {
    id: 'restore',
    label: 'Restore',
    category: 'workflow',
    requiresRecord: true,
    conditional: true,
  },

  printBatch: {
    id: 'printBatch',
    label: 'Print Batch',
    category: 'document',
    conditional: true,
  },

  emailBatch: {
    id: 'emailBatch',
    label: 'Email Batch',
    category: 'communication',
    conditional: true,
  },

  shareLink: {
    id: 'shareLink',
    label: 'Share Link',
    category: 'communication',
    requiresRecord: true,
    conditional: true,
  },
}

export type SheetActionConfig = {
  sheetKey: string
  actions: UniversalActionId[]
}

export function getUniversalAction(
  actionId: UniversalActionId,
): UniversalActionDefinition {
  return UNIVERSAL_ACTIONS[actionId]
}

export function getUniversalActions(
  actionIds: UniversalActionId[],
): UniversalActionDefinition[] {
  return actionIds
    .map((id) => UNIVERSAL_ACTIONS[id])
    .filter(Boolean)
}

export function canUseUniversalAction(
  actionId: UniversalActionId,
  options: {
    hasRecord?: boolean
    isEditMode?: boolean
    disabledActions?: UniversalActionId[]
  } = {},
): boolean {
  const action = UNIVERSAL_ACTIONS[actionId]

  if (!action) {
    return false
  }

  if (options.disabledActions?.includes(actionId)) {
    return false
  }

  if (action.requiresRecord && !options.hasRecord) {
    return false
  }

  if (action.requiresEditMode && !options.isEditMode) {
    return false
  }

  return true
}

// ============================================================
// ELVARIS UNIVERSAL ACTION EXECUTION
// ============================================================

export type UniversalActionHandlers = {
  new?: () => void | Promise<void>
  save?: () => void | Promise<void>
  saveAndNew?: () => void | Promise<void>
  edit?: () => void | Promise<void>
  duplicate?: () => void | Promise<void>
  delete?: () => void | Promise<void>
  attach?: () => void | Promise<void>
  print?: () => void | Promise<void>
  printPreview?: () => void | Promise<void>
  pdf?: () => void | Promise<void>
  excel?: () => void | Promise<void>
  csv?: () => void | Promise<void>
  memorize?: () => void | Promise<void>
  export?: () => void | Promise<void>
  refresh?: () => void | Promise<void>
  close?: () => void | Promise<void>
  cancel?: () => void | Promise<void>
  email?: () => void | Promise<void>
  share?: () => void | Promise<void>
  search?: () => void | Promise<void>
  filter?: () => void | Promise<void>
  sort?: () => void | Promise<void>
  columns?: () => void | Promise<void>
  import?: () => void | Promise<void>
  history?: () => void | Promise<void>
  void?: () => void | Promise<void>
  reverse?: () => void | Promise<void>
  approve?: () => void | Promise<void>
  reject?: () => void | Promise<void>
  post?: () => void | Promise<void>
  unpost?: () => void | Promise<void>
  lock?: () => void | Promise<void>
  unlock?: () => void | Promise<void>
  restore?: () => void | Promise<void>
  printBatch?: () => void | Promise<void>
  emailBatch?: () => void | Promise<void>
  shareLink?: () => void | Promise<void>
}

export type UniversalActionContext = {
  hasRecord?: boolean
  isEditMode?: boolean
  disabledActions?: UniversalActionId[]
}

export async function executeUniversalAction(
  actionId: UniversalActionId,
  handlers: UniversalActionHandlers,
  context: UniversalActionContext = {},
): Promise<boolean> {
  if (
    !canUseUniversalAction(
      actionId,
      context,
    )
  ) {
    return false
  }

  const handler = handlers[actionId]

  if (!handler) {
    return false
  }

  await handler()

  return true
}

// ============================================================
// UNIVERSAL EXPORT HELPERS
// ============================================================

export function exportData(
  rows: ExportRow[],
  columns: ExportColumn[],
  fileName: string,
  format: 'csv' | 'excel',
): void {
  if (format === 'csv') {
    exportCsv(
      rows,
      columns,
      fileName,
    )
    return
  }

  exportExcel(
    rows,
    columns,
    fileName,
  )
}

// ============================================================
// UNIVERSAL PDF ACTION
// ============================================================

export function exportPdf(
  options: PrintOptions,
): void {
  /*
   * The browser's native print engine provides the PDF
   * destination through "Save as PDF".
   *
   * Keeping PDF generation behind the same print engine
   * means every Elvaris document uses the same print layout.
   */
  printDocument({
    ...options,
    autoPrint: true,
  })
}

// ============================================================
// UNIVERSAL EMAIL ACTION
// ============================================================

export type EmailOptions = {
  to?: string
  subject: string
  body?: string
}

export function emailDocument(
  options: EmailOptions,
): void {
  const params = new URLSearchParams()

  params.set(
    'subject',
    options.subject,
  )

  if (options.body) {
    params.set(
      'body',
      options.body,
    )
  }

  const recipient =
    options.to ?? ''

  window.location.href =
    `mailto:${encodeURIComponent(recipient)}?${params.toString()}`
}

// ============================================================
// UNIVERSAL SHARE ACTION
// ============================================================

export type ShareOptions = {
  title: string
  text?: string
  url?: string
}

export async function shareDocument(
  options: ShareOptions,
): Promise<boolean> {
  if (
    typeof navigator === 'undefined' ||
    !navigator.share
  ) {
    return false
  }

  await navigator.share({
    title: options.title,
    text: options.text,
    url: options.url,
  })

  return true
}

// ============================================================
// UNIVERSAL FILE ATTACHMENT HELPER
// ============================================================

export function openAttachmentPicker(
  input: HTMLInputElement | null,
): void {
  input?.click()
}

// ============================================================
// UNIVERSAL FILENAME NORMALIZATION
// ============================================================

export function normalizeExportFileName(
  fileName: string,
  extension: 'csv' | 'xls' | 'pdf',
): string {
  const trimmed =
    fileName.trim() ||
    'Elvaris Export'

  const withoutExtension =
    trimmed.replace(
      /\.(csv|xls|xlsx|pdf)$/i,
      '',
    )

  return `${withoutExtension}.${extension}`
}
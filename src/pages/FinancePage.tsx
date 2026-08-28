function FinancePage() {
  return (
    <section className="module-page">
      <p className="eyebrow">FINANCE</p>

      <h3>Financial Management</h3>

      <p>
        Manage the chart of accounts, journal entries, payments, receipts,
        banking, and financial reports.
      </p>

      <div className="module-grid">
        <article className="module-card">
          <h4>Chart of Accounts</h4>
          <p>Build and manage your accounting structure.</p>
        </article>

        <article className="module-card">
          <h4>Transactions</h4>
          <p>Record journal entries and financial vouchers.</p>
        </article>

        <article className="module-card">
          <h4>Banking</h4>
          <p>Manage bank accounts and reconciliation.</p>
        </article>

        <article className="module-card">
          <h4>Financial Reports</h4>
          <p>View Trial Balance, Profit & Loss, and Balance Sheet.</p>
        </article>
      </div>
    </section>
  )
}

export default FinancePage
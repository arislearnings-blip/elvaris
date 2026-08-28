function ReportsPage() {
  return (
    <section className="module-page">
      <p className="eyebrow">REPORTS</p>

      <h3>Business Reports</h3>

      <p>
        Access financial, operational, inventory, sales, purchasing, and
        manufacturing reports.
      </p>

      <div className="module-grid">
        <article className="module-card">
          <h4>Financial Reports</h4>
          <p>Trial Balance, Profit & Loss, and Balance Sheet.</p>
        </article>

        <article className="module-card">
          <h4>Inventory Reports</h4>
          <p>Stock position, movement, and valuation reports.</p>
        </article>

        <article className="module-card">
          <h4>Sales Reports</h4>
          <p>Customer, invoice, and sales performance analysis.</p>
        </article>

        <article className="module-card">
          <h4>Manufacturing Reports</h4>
          <p>Production, consumption, cost, and efficiency reports.</p>
        </article>
      </div>
    </section>
  )
}

export default ReportsPage
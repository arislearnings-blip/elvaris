function SalesPage() {
  return (
    <section className="module-page">
      <p className="eyebrow">SALES</p>

      <h3>Sales Management</h3>

      <p>
        Manage customers, quotations, sales orders, invoices, receipts, and
        sales activity.
      </p>

      <div className="module-grid">
        <article className="module-card">
          <h4>Customers</h4>
          <p>Manage customer records and balances.</p>
        </article>

        <article className="module-card">
          <h4>Quotations</h4>
          <p>Create and track customer quotations.</p>
        </article>

        <article className="module-card">
          <h4>Sales Invoices</h4>
          <p>Create and manage customer invoices.</p>
        </article>

        <article className="module-card">
          <h4>Receipts</h4>
          <p>Record and manage customer payments.</p>
        </article>
      </div>
    </section>
  )
}

export default SalesPage
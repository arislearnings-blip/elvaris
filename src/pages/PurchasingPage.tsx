function PurchasingPage() {
  return (
    <section className="module-page">
      <p className="eyebrow">PURCHASING</p>

      <h3>Purchasing Management</h3>

      <p>
        Manage vendors, purchase requests, purchase orders, bills, and supplier
        payments.
      </p>

      <div className="module-grid">
        <article className="module-card">
          <h4>Vendors</h4>
          <p>Manage vendor records and balances.</p>
        </article>

        <article className="module-card">
          <h4>Purchase Orders</h4>
          <p>Create and track purchasing commitments.</p>
        </article>

        <article className="module-card">
          <h4>Purchase Bills</h4>
          <p>Record purchases and vendor liabilities.</p>
        </article>

        <article className="module-card">
          <h4>Payments</h4>
          <p>Record and manage vendor payments.</p>
        </article>
      </div>
    </section>
  )
}

export default PurchasingPage
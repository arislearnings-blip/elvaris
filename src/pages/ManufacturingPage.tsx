function ManufacturingPage() {
  return (
    <section className="module-page">
      <p className="eyebrow">MANUFACTURING</p>

      <h3>Manufacturing Management</h3>

      <p>
        Manage bills of materials, production orders, material consumption,
        finished goods, costing, scrap, and production operations.
      </p>

      <div className="module-grid">
        <article className="module-card">
          <h4>Bill of Materials</h4>
          <p>Define materials and quantities required for production.</p>
        </article>

        <article className="module-card">
          <h4>Production Orders</h4>
          <p>Plan, release, and monitor manufacturing activity.</p>
        </article>

        <article className="module-card">
          <h4>Material Consumption</h4>
          <p>Record materials consumed during production.</p>
        </article>

        <article className="module-card">
          <h4>Production Costing</h4>
          <p>Calculate material, labor, overhead, and finished goods cost.</p>
        </article>
      </div>
    </section>
  )
}

export default ManufacturingPage
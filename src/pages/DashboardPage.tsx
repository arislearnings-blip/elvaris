function DashboardPage() {
  return (
    <>
      <section className="dashboard-intro">
        <div>
          <p className="eyebrow">
            OVERVIEW
          </p>

          <h3>
            Welcome to Elvaris
          </h3>

          <p>
            Your connected workspace for
            managing business operations,
            finance, inventory, and
            manufacturing.
          </p>
        </div>
      </section>

      <section className="stats-grid">
        <article className="stat-card">
          <span>
            Cash Position
          </span>

          <strong>—</strong>

          <small>
            Available after accounts
            are configured
          </small>
        </article>

        <article className="stat-card">
          <span>
            Inventory Value
          </span>

          <strong>—</strong>

          <small>
            Available after inventory
            is configured
          </small>
        </article>

        <article className="stat-card">
          <span>
            Production Status
          </span>

          <strong>—</strong>

          <small>
            Available after production
            is configured
          </small>
        </article>

        <article className="stat-card">
          <span>
            Business Activity
          </span>

          <strong>New</strong>

          <small>
            Your workspace is ready
          </small>
        </article>
      </section>

      <section className="dashboard-grid">
        <article className="panel">
          <div className="panel-heading">
            <div>
              <h3>
                System Setup
              </h3>

              <p>
                Complete the foundation
                of your ERP.
              </p>
            </div>
          </div>

          <div className="setup-list">
            <div className="setup-item">
              <span>01</span>

              <div>
                <strong>
                  Company
                </strong>

                <p>
                  Configure company
                  and fiscal information.
                </p>
              </div>
            </div>

            <div className="setup-item">
              <span>02</span>

              <div>
                <strong>
                  Chart of Accounts
                </strong>

                <p>
                  Create your
                  accounting structure.
                </p>
              </div>
            </div>

            <div className="setup-item">
              <span>03</span>

              <div>
                <strong>
                  Items and Inventory
                </strong>

                <p>
                  Configure materials,
                  products, and warehouses.
                </p>
              </div>
            </div>
          </div>
        </article>

        <article className="panel">
          <div className="panel-heading">
            <div>
              <h3>
                Recent Activity
              </h3>

              <p>
                Transactions will appear
                here.
              </p>
            </div>
          </div>

          <div className="empty-state">
            <div className="empty-icon">
              ◌
            </div>

            <strong>
              No activity yet
            </strong>

            <p>
              Your transactions and
              activity will appear here.
            </p>
          </div>
        </article>
      </section>
    </>
  )
}

export default DashboardPage
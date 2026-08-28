import { useState } from 'react'
import './app.css'

import Sidebar from './components/Sidebar'
import Header from './components/Header'

import DashboardPage from './pages/DashboardPage'
import FinancePage from './pages/FinancePage'
import SalesPage from './pages/SalesPage'
import PurchasingPage from './pages/PurchasingPage'
import InventoryPage from './pages/InventoryPage'
import ManufacturingPage from './pages/ManufacturingPage'
import ReportsPage from './pages/ReportsPage'
import SettingsPage from './pages/SettingsPage'

function App() {
  const [activePage, setActivePage] =
    useState('Dashboard')

  return (
    <div className="app-shell">
      <Sidebar
        activePage={activePage}
        onNavigate={setActivePage}
      />

      <div className="workspace">
        <Header
          activePage={activePage}
        />

        <main className="content">
          {activePage === 'Dashboard' && (
            <DashboardPage />
          )}

          {activePage === 'Finance' && (
            <FinancePage />
          )}

          {activePage === 'Sales' && (
            <SalesPage />
          )}

          {activePage === 'Purchasing' && (
            <PurchasingPage />
          )}

          {activePage === 'Inventory' && (
            <InventoryPage />
          )}

          {activePage === 'Manufacturing' && (
            <ManufacturingPage />
          )}

          {activePage === 'Reports' && (
            <ReportsPage />
          )}

          {activePage === 'Settings' && (
            <SettingsPage />
          )}
        </main>
      </div>
    </div>
  )
}

export default App
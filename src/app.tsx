import {
  useEffect,
  useState,
} from 'react'

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
import LoginPage from './pages/LoginPage'
import FirstRunSetupPage from './pages/FirstRunSetupPage'
import PasswordResetPage from './pages/PasswordResetPage'

import {
  useAuth,
} from './contexts/AuthContext'

import {
  supabase,
} from './lib/supabaseClient'


type SetupState =
  | 'checking'
  | 'required'
  | 'complete'
  | 'error'


function LoadingScreen({
  message,
}: {
  message: string
}) {
  return (
    <main className="login-page">
      <section className="login-card">

        <div className="login-brand">
          <div className="login-brand-icon">
            <img
              src="/newfav.png"
              alt="Elvaris"
            />
          </div>

          <div>
            <h1>
              Elvaris
            </h1>

            <p>
              Enterprise Management Platform
            </p>
          </div>
        </div>

        <p
          style={{
            margin: 0,
            color:
              'var(--text-secondary)',
            textAlign:
              'center',
          }}
        >
          {message}
        </p>

      </section>
    </main>
  )
}


function WorkspaceError({
  message,
}: {
  message: string
}) {
  return (
    <main className="login-page">
      <section className="login-card">

        <p className="eyebrow">
          WORKSPACE ERROR
        </p>

        <h2>
          Unable to verify company setup
        </h2>

        <p
          style={{
            marginTop: '12px',
            color:
              'var(--color-danger-600)',
            lineHeight:
              '1.6',
          }}
        >
          {message}
        </p>

      </section>
    </main>
  )
}


function App() {
  const {
    session,
    loading: authLoading,
    recoveryMode,
    exitRecoveryMode,
  } =
    useAuth()


  const [
    setupState,
    setSetupState,
  ] =
    useState<SetupState>(
      'checking',
    )


  const [
    setupError,
    setSetupError,
  ] =
    useState<string | null>(
      null,
    )


  const [
    activePage,
    setActivePage,
  ] =
    useState(
      'Dashboard',
    )


  useEffect(() => {
    let mounted = true


    async function checkInitialSetup() {
      if (!session) {
        if (mounted) {
          setSetupState(
            'complete',
          )

          setSetupError(
            null,
          )
        }

        return
      }


      if (mounted) {
        setSetupState(
          'checking',
        )

        setSetupError(
          null,
        )
      }


      try {
        const {
          data,
          error,
        } =
          await supabase.rpc(
            'is_initial_setup_required',
          )


        if (error) {
          throw error
        }


        if (!mounted) {
          return
        }


        setSetupState(
          data === true
            ? 'required'
            : 'complete',
        )

      } catch (error) {
        if (!mounted) {
          return
        }


        setSetupState(
          'error',
        )


        setSetupError(
          error instanceof Error
            ? error.message
            : 'Unable to verify initial company setup.',
        )
      }
    }


    checkInitialSetup()


    return () => {
      mounted = false
    }
  }, [
    session,
  ])


  function handleSetupCompleted() {
    setSetupState(
      'complete',
    )

    setSetupError(
      null,
    )

    setActivePage(
      'Dashboard',
    )
  }


  if (authLoading) {
    return (
      <LoadingScreen
        message="Loading secure workspace..."
      />
    )
  }


  /*
   * Recovery sessions are handled before the
   * normal workspace path.
   */
  if (
    recoveryMode
  ) {
    return (
      <PasswordResetPage
        onCompleted={
          exitRecoveryMode
        }
      />
    )
  }


  if (!session) {
    return (
      <LoginPage />
    )
  }


  if (
    setupState ===
    'checking'
  ) {
    return (
      <LoadingScreen
        message="Checking Elvaris workspace..."
      />
    )
  }


  if (
    setupState ===
    'error'
  ) {
    return (
      <WorkspaceError
        message={
          setupError ??
          'Unable to verify initial company setup.'
        }
      />
    )
  }


  if (
    setupState ===
    'required'
  ) {
    return (
      <FirstRunSetupPage
        onCompleted={
          handleSetupCompleted
        }
      />
    )
  }


  return (
    <div className="app-shell">

      <Sidebar
        activePage={
          activePage
        }
        onNavigate={
          setActivePage
        }
      />

      <div className="workspace">

        <Header
          activePage={
            activePage
          }
        />

        <main className="content">

          {activePage ===
            'Dashboard' && (
            <DashboardPage />
          )}

          {activePage ===
            'Finance' && (
            <FinancePage />
          )}

          {activePage ===
            'Sales' && (
            <SalesPage />
          )}

          {activePage ===
            'Purchasing' && (
            <PurchasingPage />
          )}

          {activePage ===
            'Inventory' && (
            <InventoryPage />
          )}

          {activePage ===
            'Manufacturing' && (
            <ManufacturingPage />
          )}

          {activePage ===
            'Reports' && (
            <ReportsPage />
          )}

          {activePage ===
            'Settings' && (
            <SettingsPage />
          )}

        </main>

      </div>

    </div>
  )
}


export default App
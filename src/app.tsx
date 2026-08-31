import {
  useEffect,
  useState,
} from 'react'

import './app.css'

import Sidebar, {
  type WorkspacePage,
} from './components/Sidebar'

import Header from './components/Header'

import DashboardPage from './pages/DashboardPage'
import FinancePage from './pages/FinancePage'
import JournalVoucherPage from './pages/JournalVoucherPage'
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


const WORKSPACE_STORAGE_KEY =
  'elvaris.workspace.active-pages'

const FAVORITES_STORAGE_KEY =
  'elvaris.workspace.favorites'


const PAGE_NAMES = [
  'Dashboard',
  'Finance',
  'Journal Voucher',
  'Sales',
  'Purchasing',
  'Inventory',
  'Manufacturing',
  'Reports',
  'Settings',
] as const


type PageName =
  typeof PAGE_NAMES[number]


function makePageId(
  page: string,
) {
  return `page:${page}`
}


function defaultWorkspacePages():
  WorkspacePage[] {
  return [
    {
      id:
        makePageId(
          'Dashboard',
        ),
      page:
        'Dashboard',
      title:
        'Dashboard',
    },
  ]
}


function loadWorkspacePages():
  WorkspacePage[] {
  try {
    const raw =
      localStorage.getItem(
        WORKSPACE_STORAGE_KEY,
      )


    if (
      !raw
    ) {
      return defaultWorkspacePages()
    }


    const parsed =
      JSON.parse(
        raw,
      )


    if (
      !Array.isArray(
        parsed,
      )
    ) {
      return defaultWorkspacePages()
    }


    const valid =
      parsed.filter(
        (
          item,
        ): item is WorkspacePage =>
          Boolean(
            item &&
            typeof item ===
              'object' &&
            typeof item.id ===
              'string' &&
            typeof item.page ===
              'string' &&
            typeof item.title ===
              'string',
          ),
      )


    return valid.length >
      0
      ? valid
      : defaultWorkspacePages()
  } catch {
    return defaultWorkspacePages()
  }
}


function loadFavorites():
  string[] {
  try {
    const raw =
      localStorage.getItem(
        FAVORITES_STORAGE_KEY,
      )


    if (
      !raw
    ) {
      return []
    }


    const parsed =
      JSON.parse(
        raw,
      )


    if (
      !Array.isArray(
        parsed,
      )
    ) {
      return []
    }


    return parsed.filter(
      (
        item,
      ): item is string =>
        typeof item ===
        'string',
    )
  } catch {
    return []
  }
}


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
            margin:
              0,
            color:
              'var(--text-secondary)',
            textAlign:
              'center',
          }}
        >
          {
            message
          }
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
            marginTop:
              '12px',
            color:
              'var(--color-danger-600)',
            lineHeight:
              '1.6',
          }}
        >
          {
            message
          }
        </p>

      </section>

    </main>
  )
}


function App() {
  const {
    session,
    loading:
      authLoading,
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
    useState<PageName>(
      'Dashboard',
    )


  const [
    activePages,
    setActivePages,
  ] =
    useState<WorkspacePage[]>(
      () =>
        loadWorkspacePages(),
    )


  const [
    favorites,
    setFavorites,
  ] =
    useState<string[]>(
      () =>
        loadFavorites(),
    )


  useEffect(
    () => {
      localStorage.setItem(
        WORKSPACE_STORAGE_KEY,
        JSON.stringify(
          activePages,
        ),
      )
    },
    [
      activePages,
    ],
  )


  useEffect(
    () => {
      localStorage.setItem(
        FAVORITES_STORAGE_KEY,
        JSON.stringify(
          favorites,
        ),
      )
    },
    [
      favorites,
    ],
  )


  useEffect(
    () => {
      /*
       * Make sure Dashboard exists in
       * the workspace after application
       * initialization.
       */
      setActivePages(
        (
          current,
        ) => {
          if (
            current.some(
              (
                page,
              ) =>
                page.page ===
                'Dashboard',
            )
          ) {
            return current
          }


          return [
            {
              id:
                makePageId(
                  'Dashboard',
                ),
              page:
                'Dashboard',
              title:
                'Dashboard',
            },
            ...current,
          ]
        },
      )
    },
    [],
  )


  useEffect(
    () => {
      let mounted = true


      async function checkInitialSetup() {
        if (
          !session
        ) {
          if (
            mounted
          ) {
            setSetupState(
              'complete',
            )

            setSetupError(
              null,
            )
          }

          return
        }


        if (
          mounted
        ) {
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


          if (
            error
          ) {
            throw error
          }


          if (
            !mounted
          ) {
            return
          }


          setSetupState(
            data === true
              ? 'required'
              : 'complete',
          )
        } catch (
          error
        ) {
          if (
            !mounted
          ) {
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


      void checkInitialSetup()


      return () => {
        mounted =
          false
      }
    },
    [
      session,
    ],
  )


  function openPage(
    page: string,
  ) {
    const pageName =
      page as PageName


    setActivePages(
      (
        current,
      ) => {
        const existing =
          current.find(
            (
              item,
            ) =>
              item.page ===
              pageName,
          )


        if (
          existing
        ) {
          return [
            existing,
            ...current.filter(
              (
                item,
              ) =>
                item.id !==
                existing.id,
            ),
          ]
        }


        return [
          {
            id:
              makePageId(
                pageName,
              ),
            page:
              pageName,
            title:
              pageName,
          },
          ...current,
        ]
      },
    )


    setActivePage(
      pageName,
    )
  }


  function activatePage(
    pageId: string,
  ) {
    const page =
      activePages.find(
        (
          item,
        ) =>
          item.id ===
          pageId,
      )


    if (
      !page
    ) {
      return
    }


    setActivePage(
      page.page as PageName,
    )


    setActivePages(
      (
        current,
      ) => {
        const currentPage =
          current.find(
            (
              item,
            ) =>
              item.id ===
              pageId,
          )


        if (
          !currentPage
        ) {
          return current
        }


        return [
          currentPage,
          ...current.filter(
            (
              item,
            ) =>
              item.id !==
              pageId,
          ),
        ]
      },
    )
  }


  function closePage(
    pageId: string,
  ) {
    setActivePages(
      (
        current,
      ) => {
        const index =
          current.findIndex(
            (
              item,
            ) =>
              item.id ===
              pageId,
          )


        if (
          index <
          0
        ) {
          return current
        }


        const next =
          current.filter(
            (
              item,
            ) =>
              item.id !==
              pageId,
          )


        /*
         * If the closed page was active,
         * switch to the nearest remaining
         * open page.
         */
        const closingPage =
          current[index]


        if (
          closingPage.page ===
          activePage
        ) {
          const fallback =
            next[
              Math.max(
                0,
                index -
                  1,
              )
            ] ??
            next[0]


          if (
            fallback
          ) {
            setActivePage(
              fallback.page as PageName,
            )
          }
        }


        /*
         * Never leave the workspace with
         * zero pages.
         */
        if (
          next.length ===
          0
        ) {
          const dashboard =
            {
              id:
                makePageId(
                  'Dashboard',
                ),
              page:
                'Dashboard',
              title:
                'Dashboard',
            }


          setActivePage(
            'Dashboard',
          )


          return [
            dashboard,
          ]
        }


        return next
      },
    )
  }


  function toggleFavorite(
    page: string,
  ) {
    setFavorites(
      (
        current,
      ) =>
        current.includes(
          page,
        )
          ? current.filter(
              (
                item,
              ) =>
                item !==
                page,
            )
          : [
              ...current,
              page,
            ],
    )
  }


  function handleSetupCompleted() {
    setSetupState(
      'complete',
    )

    setSetupError(
      null,
    )

    openPage(
      'Dashboard',
    )
  }


  if (
    authLoading
  ) {
    return (
      <LoadingScreen
        message="Loading secure workspace..."
      />
    )
  }


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


  if (
    !session
  ) {
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
          openPage
        }

        activePages={
          activePages
        }

        onActivatePage={
          activatePage
        }

        onClosePage={
          closePage
        }

        favorites={
          favorites
        }

        onToggleFavorite={
          toggleFavorite
        }
      />


      <div className="workspace">

        <Header
          activePage={
            activePage
          }
        />


        <main
          className="content"
          style={{
            minWidth:
              0,
            minHeight:
              0,
            overflow:
              'hidden',
            position:
              'relative',
          }}
        >

          {/* =================================================
              KEEP ALL OPEN PAGES MOUNTED.
              Only the active page is visible.
              This prevents in-process form data
              from disappearing when switching pages.
          ================================================= */}

          {activePages.map(
            (
              page,
            ) => (
              <div
                key={
                  page.id
                }
                style={{
                  display:
                    activePage ===
                    page.page
                      ? 'block'
                      : 'none',
                  width:
                    '100%',
                  height:
                    '100%',
                  minWidth:
                    0,
                  minHeight:
                    0,
                }}
              >

                {page.page ===
                  'Dashboard' && (
                  <DashboardPage />
                )}

                {page.page ===
                  'Finance' && (
                  <FinancePage />
                )}

                {page.page ===
                  'Journal Voucher' && (
                  <JournalVoucherPage />
                )}

                {page.page ===
                  'Sales' && (
                  <SalesPage />
                )}

                {page.page ===
                  'Purchasing' && (
                  <PurchasingPage />
                )}

                {page.page ===
                  'Inventory' && (
                  <InventoryPage />
                )}

                {page.page ===
                  'Manufacturing' && (
                  <ManufacturingPage />
                )}

                {page.page ===
                  'Reports' && (
                  <ReportsPage />
                )}

                {page.page ===
                  'Settings' && (
                  <SettingsPage />
                )}

              </div>
            ),
          )}

        </main>

      </div>

    </div>
  )
}


export default App
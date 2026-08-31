import {
  LayoutDashboard,
  WalletCards,
  ReceiptText,
  ShoppingCart,
  Package,
  Factory,
  BarChart3,
  Settings,
  LogOut,
  Star,
  Clock3,
  Home,
  X,
} from 'lucide-react'

import {
  useAuth,
} from '../contexts/AuthContext'

import {
  useEffect,
  useMemo,
  useState,
} from 'react'


export type WorkspacePage = {
  id: string
  page: string
  title: string
}


type SidebarProps = {
  activePage: string

  onNavigate: (
    page: string,
  ) => void

  activePages: WorkspacePage[]

  onActivatePage: (
    pageId: string,
  ) => void

  onClosePage: (
    pageId: string,
  ) => void

  favorites: string[]

  onToggleFavorite: (
    page: string,
  ) => void
}


type NavigationItem = {
  label: string
  icon: typeof LayoutDashboard
}


const navigationItems:
  NavigationItem[] = [
    {
      label: 'Dashboard',
      icon: LayoutDashboard,
    },

    {
      label: 'Finance',
      icon: WalletCards,
    },

    {
      label: 'Journal Voucher',
      icon: ReceiptText,
    },

    {
      label: 'Sales',
      icon: ShoppingCart,
    },

    {
      label: 'Purchasing',
      icon: ShoppingCart,
    },

    {
      label: 'Inventory',
      icon: Package,
    },

    {
      label: 'Manufacturing',
      icon: Factory,
    },

    {
      label: 'Reports',
      icon: BarChart3,
    },

    {
      label: 'Settings',
      icon: Settings,
    },
  ]


function getInitials(
  name: string,
) {
  const words =
    name
      .trim()
      .split(/\s+/)
      .filter(Boolean)


  if (
    words.length === 0
  ) {
    return 'U'
  }


  if (
    words.length === 1
  ) {
    return words[0]
      .slice(
        0,
        2,
      )
      .toUpperCase()
  }


  return (
    words[0][0] +
    words[
      words.length - 1
    ][0]
  ).toUpperCase()
}


function Sidebar({
  activePage,
  onNavigate,
  activePages,
  onActivatePage,
  onClosePage,
  favorites,
  onToggleFavorite,
}: SidebarProps) {
  const {
    user,
    logout,
    authError,
  } = useAuth()


  const [
    panel,
    setPanel,
  ] =
    useState<
      | 'home'
      | 'favorites'
      | 'active'
    >('home')


  const [
    currentSearch,
    setCurrentSearch,
  ] =
    useState('')


  const displayName =
    user?.user_metadata?.full_name ??
    user?.user_metadata?.name ??
    user?.email ??
    'Administrator'


  const email =
    user?.email ??
    'No email available'


  const initials =
    getInitials(
      displayName,
    )


  useEffect(
    () => {
      if (
        !activePage
      ) {
        return
      }


      if (
        activePages.some(
          (
            item,
          ) =>
            item.page ===
            activePage,
        )
      ) {
        return
      }
    },
    [
      activePage,
      activePages,
    ],
  )


  const filteredNavigation =
    useMemo(
      () => {
        const query =
          currentSearch
            .trim()
            .toLowerCase()


        if (
          !query
        ) {
          return navigationItems
        }


        return navigationItems.filter(
          (
            item,
          ) =>
            item.label
              .toLowerCase()
              .includes(
                query,
              ),
        )
      },
      [
        currentSearch,
      ],
    )


  const favoriteItems =
    useMemo(
      () =>
        navigationItems.filter(
          (
            item,
          ) =>
            favorites.includes(
              item.label,
            ),
        ),
      [
        favorites,
      ],
    )


  async function handleLogout() {
    try {
      await logout()
    } catch (
      error
    ) {
      console.error(
        'Elvaris sign out failed:',
        error,
      )
    }
  }


  function handleNavigation(
    page: string,
  ) {
    onNavigate(
      page,
    )

    setPanel(
      'home',
    )
  }


  return (
    <aside className="sidebar">

      <div className="brand">

        <div className="brand-icon">

          <img
            src="/newfav.png"
            alt="Elvaris"
          />

        </div>


        <div className="brand-content">

          <h1>
            Elvaris
          </h1>

          <span>
            Enterprise Management Platform
          </span>

        </div>

      </div>


      {/* ====================================================
          GLOBAL WORKSPACE SWITCHER
      ==================================================== */}

      <div
        style={{
          padding:
            '8px 9px',
          borderBottom:
            '1px solid var(--border-color, rgba(127,127,127,.16))',
        }}
      >

        <div
          style={{
            display:
              'grid',
            gridTemplateColumns:
              'repeat(3, 1fr)',
            gap:
              '4px',
          }}
        >

          <button
            type="button"
            onClick={() =>
              setPanel(
                'home',
              )
            }
            style={{
              minHeight:
                '38px',
              display:
                'flex',
              flexDirection:
                'column',
              alignItems:
                'center',
              justifyContent:
                'center',
              gap:
                '3px',
              border:
                '1px solid transparent',
              borderRadius:
                '5px',
              background:
                panel ===
                'home'
                  ? 'rgba(59,130,246,.10)'
                  : 'transparent',
              color:
                panel ===
                'home'
                  ? '#2563eb'
                  : 'inherit',
              cursor:
                'pointer',
              fontSize:
                '8px',
              fontWeight:
                700,
            }}
          >

            <Home
              size={15}
            />

            <span>
              Home
            </span>

          </button>


          <button
            type="button"
            onClick={() =>
              setPanel(
                'favorites',
              )
            }
            style={{
              minHeight:
                '38px',
              position:
                'relative',
              display:
                'flex',
              flexDirection:
                'column',
              alignItems:
                'center',
              justifyContent:
                'center',
              gap:
                '3px',
              border:
                '1px solid transparent',
              borderRadius:
                '5px',
              background:
                panel ===
                'favorites'
                  ? 'rgba(212,167,44,.10)'
                  : 'transparent',
              color:
                panel ===
                'favorites'
                  ? '#a87900'
                  : 'inherit',
              cursor:
                'pointer',
              fontSize:
                '8px',
              fontWeight:
                700,
            }}
          >

            <Star
              size={15}
              fill={
                favorites.length >
                0
                  ? 'currentColor'
                  : 'none'
              }
            />

            <span>
              Favorites
            </span>

            {favorites.length >
              0 && (
              <span
                style={{
                  position:
                    'absolute',
                  top:
                    '2px',
                  right:
                    '5px',
                  minWidth:
                    '13px',
                  height:
                    '13px',
                  display:
                    'grid',
                  placeItems:
                    'center',
                  borderRadius:
                    '50%',
                  background:
                    '#d4a72c',
                  color:
                    '#fff',
                  fontSize:
                    '7px',
                  fontWeight:
                    800,
                }}
              >
                {
                  favorites.length
                }
              </span>
            )}

          </button>


          <button
            type="button"
            onClick={() =>
              setPanel(
                'active',
              )
            }
            style={{
              minHeight:
                '38px',
              position:
                'relative',
              display:
                'flex',
              flexDirection:
                'column',
              alignItems:
                'center',
              justifyContent:
                'center',
              gap:
                '3px',
              border:
                '1px solid transparent',
              borderRadius:
                '5px',
              background:
                panel ===
                'active'
                  ? 'rgba(59,130,246,.10)'
                  : 'transparent',
              color:
                panel ===
                'active'
                  ? '#2563eb'
                  : 'inherit',
              cursor:
                'pointer',
              fontSize:
                '8px',
              fontWeight:
                700,
            }}
          >

            <Clock3
              size={15}
            />

            <span>
              Active Pages
            </span>

            {activePages.length >
              0 && (
              <span
                style={{
                  position:
                    'absolute',
                  top:
                    '2px',
                  right:
                    '5px',
                  minWidth:
                    '13px',
                  height:
                    '13px',
                  display:
                    'grid',
                  placeItems:
                    'center',
                  borderRadius:
                    '50%',
                  background:
                    '#2563eb',
                  color:
                    '#fff',
                  fontSize:
                    '7px',
                  fontWeight:
                    800,
                }}
              >
                {
                  activePages.length
                }
              </span>
            )}

          </button>

        </div>

      </div>


      {/* ====================================================
          HOME
      ==================================================== */}

      {panel ===
        'home' && (
        <>

          <div
            style={{
              padding:
                '8px 9px 4px',
            }}
          >

            <input
              type="search"
              value={
                currentSearch
              }
              placeholder="Search modules..."
              onChange={(
                event,
              ) =>
                setCurrentSearch(
                  event.target
                    .value,
                )
              }
              style={{
                width:
                  '100%',
                height:
                  '30px',
                padding:
                  '0 9px',
                border:
                  '1px solid var(--border-color, rgba(127,127,127,.18))',
                borderRadius:
                  '5px',
                background:
                  'var(--input-bg, rgba(127,127,127,.06))',
                color:
                  'inherit',
                fontSize:
                  '10px',
                outline:
                  'none',
                boxSizing:
                  'border-box',
              }}
            />

          </div>


          <nav className="navigation">

            <span className="navigation-label">
              WORKSPACE
            </span>


            {filteredNavigation.map(
              (
                item,
              ) => {
                const Icon =
                  item.icon

                const isActive =
                  activePage ===
                  item.label

                const isFavorite =
                  favorites.includes(
                    item.label,
                  )


                return (
                  <div
                    key={
                      item.label
                    }
                    style={{
                      display:
                        'flex',
                      width:
                        '100%',
                      alignItems:
                        'center',
                    }}
                  >

                    <button
                      type="button"
                      className={
                        `nav-item ${
                          isActive
                            ? 'active'
                            : ''
                        }`
                      }
                      onClick={() =>
                        handleNavigation(
                          item.label,
                        )
                      }
                      style={{
                        flex:
                          1,
                        minWidth:
                          0,
                      }}
                    >

                      <Icon
                        size={19}
                        strokeWidth={
                          isActive
                            ? 2.1
                            : 1.8
                        }
                      />

                      <span className="nav-item-label">
                        {
                          item.label
                        }
                      </span>

                    </button>


                    <button
                      type="button"
                      title={
                        isFavorite
                          ? 'Remove from Favorites'
                          : 'Add to Favorites'
                      }
                      onClick={() =>
                        onToggleFavorite(
                          item.label,
                        )
                      }
                      style={{
                        width:
                          '30px',
                        height:
                          '34px',
                        display:
                          'grid',
                        placeItems:
                          'center',
                        border:
                          '0',
                        background:
                          'transparent',
                        color:
                          isFavorite
                            ? '#d4a72c'
                            : 'rgba(127,127,127,.48)',
                        cursor:
                          'pointer',
                        flex:
                          '0 0 30px',
                      }}
                    >

                      <Star
                        size={13}
                        fill={
                          isFavorite
                            ? 'currentColor'
                            : 'none'
                        }
                      />

                    </button>

                  </div>
                )
              },
            )}

          </nav>

        </>
      )}


      {/* ====================================================
          FAVORITES
      ==================================================== */}

      {panel ===
        'favorites' && (
        <nav
          className="navigation"
          style={{
            overflowY:
              'auto',
          }}
        >

          <span className="navigation-label">
            FAVORITES
          </span>


          {favoriteItems.length ===
          0 ? (
            <div
              style={{
                padding:
                  '24px 12px',
                textAlign:
                  'center',
                opacity:
                  .65,
              }}
            >

              <Star
                size={22}
                style={{
                  margin:
                    '0 auto 8px',
                }}
              />

              <div
                style={{
                  fontSize:
                    '10px',
                  fontWeight:
                    700,
                }}
              >
                No favorites yet
              </div>

              <div
                style={{
                  marginTop:
                    '4px',
                  fontSize:
                    '8px',
                  lineHeight:
                    1.4,
                }}
              >
                Use the star beside any
                module to add it here.
              </div>

            </div>
          ) : (
            favoriteItems.map(
              (
                item,
              ) => {
                const Icon =
                  item.icon

                return (
                  <div
                    key={
                      item.label
                    }
                    style={{
                      display:
                        'flex',
                      alignItems:
                        'center',
                      width:
                        '100%',
                    }}
                  >

                    <button
                      type="button"
                      className={
                        `nav-item ${
                          activePage ===
                          item.label
                            ? 'active'
                            : ''
                        }`
                      }
                      onClick={() =>
                        handleNavigation(
                          item.label,
                        )
                      }
                      style={{
                        flex:
                          1,
                        minWidth:
                          0,
                      }}
                    >

                      <Icon
                        size={18}
                      />

                      <span className="nav-item-label">
                        {
                          item.label
                        }
                      </span>

                    </button>


                    <button
                      type="button"
                      title="Remove favorite"
                      onClick={() =>
                        onToggleFavorite(
                          item.label,
                        )
                      }
                      style={{
                        width:
                          '30px',
                        height:
                          '34px',
                        display:
                          'grid',
                        placeItems:
                          'center',
                        border:
                          '0',
                        background:
                          'transparent',
                        color:
                          '#d4a72c',
                        cursor:
                          'pointer',
                      }}
                    >

                      <Star
                        size={13}
                        fill="currentColor"
                      />

                    </button>

                  </div>
                )
              },
            )
          )}

        </nav>
      )}


      {/* ====================================================
          ACTIVE PAGES
      ==================================================== */}

      {panel ===
        'active' && (
        <nav
          className="navigation"
          style={{
            overflowY:
              'auto',
          }}
        >

          <div
            style={{
              display:
                'flex',
              alignItems:
                'center',
              justifyContent:
                'space-between',
              marginBottom:
                '4px',
            }}
          >

            <span className="navigation-label">
              ACTIVE PAGES
            </span>

            <span
              style={{
                minWidth:
                  '17px',
                height:
                  '17px',
                display:
                  'grid',
                placeItems:
                  'center',
                borderRadius:
                  '50%',
                background:
                  'rgba(59,130,246,.10)',
                color:
                  '#2563eb',
                fontSize:
                  '8px',
                fontWeight:
                  800,
              }}
            >
              {
                activePages.length
              }
            </span>

          </div>


          {activePages.length ===
          0 ? (
            <div
              style={{
                padding:
                  '24px 12px',
                textAlign:
                  'center',
                opacity:
                  .65,
              }}
            >

              <Clock3
                size={22}
                style={{
                  margin:
                    '0 auto 8px',
                }}
              />

              <div
                style={{
                  fontSize:
                    '10px',
                  fontWeight:
                    700,
                }}
              >
                No active pages
              </div>

              <div
                style={{
                  marginTop:
                    '4px',
                  fontSize:
                    '8px',
                  lineHeight:
                    1.4,
                }}
              >
                Pages currently open in
                the workspace appear here.
              </div>

            </div>
          ) : (
            activePages.map(
              (
                item,
              ) => {
                const navItem =
                  navigationItems.find(
                    (
                      value,
                    ) =>
                      value.label ===
                      item.page,
                  )

                const Icon =
                  navItem?.icon ??
                  ReceiptText

                const isActive =
                  activePage ===
                  item.page


                return (
                  <div
                    key={
                      item.id
                    }
                    style={{
                      display:
                        'flex',
                      alignItems:
                        'center',
                      width:
                        '100%',
                      marginBottom:
                        '2px',
                      borderRadius:
                        '4px',
                      background:
                        isActive
                          ? 'rgba(59,130,246,.08)'
                          : 'transparent',
                    }}
                  >

                    <button
                      type="button"
                      onClick={() =>
                        onActivatePage(
                          item.id,
                        )
                      }
                      style={{
                        flex:
                          1,
                        minWidth:
                          0,
                        height:
                          '34px',
                        display:
                          'flex',
                        alignItems:
                          'center',
                        gap:
                          '8px',
                        padding:
                          '0 8px',
                        border:
                          '0',
                        background:
                          'transparent',
                        color:
                          isActive
                            ? '#2563eb'
                            : 'inherit',
                        textAlign:
                          'left',
                        cursor:
                          'pointer',
                      }}
                    >

                      <Icon
                        size={17}
                      />

                      <span
                        style={{
                          minWidth:
                            0,
                          flex:
                            1,
                          overflow:
                            'hidden',
                          textOverflow:
                            'ellipsis',
                          whiteSpace:
                            'nowrap',
                          fontSize:
                            '9px',
                          fontWeight:
                            isActive
                              ? 700
                              : 600,
                        }}
                      >
                        {
                          item.title
                        }
                      </span>

                    </button>


                    <button
                      type="button"
                      title="Close page"
                      onClick={() =>
                        onClosePage(
                          item.id,
                        )
                      }
                      style={{
                        width:
                          '28px',
                        height:
                          '30px',
                        display:
                          'grid',
                        placeItems:
                          'center',
                        border:
                          '0',
                        background:
                          'transparent',
                        color:
                          'inherit',
                        opacity:
                          .55,
                        cursor:
                          'pointer',
                        flex:
                          '0 0 28px',
                      }}
                    >

                      <X
                        size={11}
                      />

                    </button>

                  </div>
                )
              },
            )
          )}

        </nav>
      )}


      {/* ====================================================
          FOOTER
      ==================================================== */}

      <div className="sidebar-footer">

        {authError && (
          <div
            className="sidebar-auth-error"
            role="alert"
          >
            {
              authError
            }
          </div>
        )}


        <div className="user-card">

          <div
            className="user-avatar"
            aria-hidden="true"
          >
            {
              initials
            }
          </div>


          <div className="user-card-content">

            <strong
              title={
                displayName
              }
            >
              {
                displayName
              }
            </strong>


            <span
              title={
                email
              }
            >
              {
                email
              }
            </span>

          </div>

        </div>


        <button
          type="button"
          className="nav-item sidebar-signout"
          onClick={
            handleLogout
          }
        >

          <LogOut
            size={18}
            strokeWidth={1.8}
          />

          <span className="nav-item-label">
            Sign Out
          </span>

        </button>

      </div>

    </aside>
  )
}


export default Sidebar
import {
  LayoutDashboard,
  WalletCards,
  ShoppingCart,
  Package,
  Factory,
  BarChart3,
  Settings,
  LogOut,
} from 'lucide-react'

import {
  useAuth,
} from '../contexts/AuthContext'


type SidebarProps = {
  activePage: string
  onNavigate: (
    page: string,
  ) => void
}


const navigationItems = [
  {
    label: 'Dashboard',
    icon: LayoutDashboard,
  },
  {
    label: 'Finance',
    icon: WalletCards,
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
      .slice(0, 2)
      .toUpperCase()
  }


  return (
    words[0][0] +
    words[words.length - 1][0]
  ).toUpperCase()
}


function Sidebar({
  activePage,
  onNavigate,
}: SidebarProps) {
  const {
    user,
    logout,
    authError,
  } = useAuth()


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


  async function handleLogout() {
    try {
      await logout()
    } catch (error) {
      console.error(
        'Elvaris sign out failed:',
        error,
      )
    }
  }


  return (
    <aside className="sidebar">

      {/* ====================================================
          BRAND
      ==================================================== */}

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
          NAVIGATION
      ==================================================== */}

      <nav className="navigation">

        <span className="navigation-label">
          WORKSPACE
        </span>

        {navigationItems.map(
          ({
            label,
            icon: Icon,
          }) => (
            <button
              key={label}
              type="button"
              className={
                `nav-item ${
                  activePage === label
                    ? 'active'
                    : ''
                }`
              }
              onClick={() =>
                onNavigate(
                  label,
                )
              }
            >
              <Icon
                size={19}
                strokeWidth={
                  activePage === label
                    ? 2.1
                    : 1.8
                }
                aria-hidden="true"
              />

              <span className="nav-item-label">
                {label}
              </span>
            </button>
          ),
        )}

      </nav>


      {/* ====================================================
          SIDEBAR FOOTER
      ==================================================== */}

      <div className="sidebar-footer">

        {/* Authentication error, if logout fails */}
        {authError && (
          <div
            className="sidebar-auth-error"
            role="alert"
          >
            {authError}
          </div>
        )}


        <div className="user-card">

          <div
            className="user-avatar"
            aria-hidden="true"
          >
            {initials}
          </div>


          <div className="user-card-content">

            <strong
              title={displayName}
            >
              {displayName}
            </strong>

            <span
              title={email}
            >
              {email}
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
            aria-hidden="true"
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
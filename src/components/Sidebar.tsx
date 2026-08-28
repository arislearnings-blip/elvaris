import {
  BarChart3,
  Boxes,
  ClipboardList,
  Factory,
  FileText,
  LayoutDashboard,
  Settings,
  ShoppingCart,
} from 'lucide-react'

type NavigationItem = {
  label: string
  icon: typeof LayoutDashboard
}

const navigationItems: NavigationItem[] = [
  {
    label: 'Dashboard',
    icon: LayoutDashboard,
  },
  {
    label: 'Finance',
    icon: BarChart3,
  },
  {
    label: 'Sales',
    icon: FileText,
  },
  {
    label: 'Purchasing',
    icon: ShoppingCart,
  },
  {
    label: 'Inventory',
    icon: Boxes,
  },
  {
    label: 'Manufacturing',
    icon: Factory,
  },
  {
    label: 'Reports',
    icon: ClipboardList,
  },
]

type SidebarProps = {
  activePage: string
  onNavigate: (page: string) => void
}

function Sidebar({
  activePage,
  onNavigate,
}: SidebarProps) {
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
          <h1>Elvaris</h1>
          <span>Enterprise Platform</span>
        </div>
      </div>

      <nav
        className="navigation"
        aria-label="Main navigation"
      >
        <p className="navigation-label">
          WORKSPACE
        </p>

        {navigationItems.map(
          ({ label, icon: Icon }) => (
            <button
              key={label}
              type="button"
              title={label}
              className={`nav-item ${
                activePage === label
                  ? 'active'
                  : ''
              }`}
              onClick={() =>
                onNavigate(label)
              }
            >
              <Icon
                size={18}
                strokeWidth={1.8}
                aria-hidden="true"
              />

              <span className="nav-item-label">
                {label}
              </span>
            </button>
          ),
        )}
      </nav>

      <div className="sidebar-footer">
        <button
          type="button"
          title="Settings"
          className={`nav-item ${
            activePage === 'Settings'
              ? 'active'
              : ''
          }`}
          onClick={() =>
            onNavigate('Settings')
          }
        >
          <Settings
            size={18}
            strokeWidth={1.8}
            aria-hidden="true"
          />

          <span className="nav-item-label">
            Settings
          </span>
        </button>

        <div className="user-card">
          <div className="user-avatar">
            A
          </div>

          <div className="user-card-content">
            <strong>
              Administrator
            </strong>

            <span>
              Elvaris Workspace
            </span>
          </div>
        </div>
      </div>
    </aside>
  )
}

export default Sidebar
import {
  Bell,
  Search,
} from 'lucide-react'

type HeaderProps = {
  activePage: string
}

function Header({
  activePage,
}: HeaderProps) {
  return (
    <header className="header">
      <div>
        <p className="breadcrumb">
          WORKSPACE /{' '}
          {activePage.toUpperCase()}
        </p>

        <h2>{activePage}</h2>
      </div>

      <div className="header-actions">
        <button
          type="button"
          className="search-button"
          aria-label="Search Elvaris"
        >
          <span className="search-content">
            <Search
              size={16}
              strokeWidth={1.8}
              aria-hidden="true"
            />

            <span>
              Search Elvaris
            </span>
          </span>

          <kbd>Ctrl K</kbd>
        </button>

        <button
          type="button"
          className="icon-button"
          aria-label="Notifications"
        >
          <Bell
            size={18}
            strokeWidth={1.8}
          />
        </button>
      </div>
    </header>
  )
}

export default Header
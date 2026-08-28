import {
  PackagePlus,
} from 'lucide-react'

import {
  Button,
  SearchInput,
} from '../components/ui'

import {
  useMemo,
  useState,
} from 'react'

type ItemRecord = {
  code: string
  name: string
  category: string
  type: string
  status: 'Active' | 'Inactive'
}

const sampleItems: ItemRecord[] = [
  {
    code: 'RM-001',
    name: 'Steel Billet',
    category: 'Raw Material',
    type: 'Inventory',
    status: 'Active',
  },
  {
    code: 'RM-002',
    name: 'Steel Scrap',
    category: 'Raw Material',
    type: 'Inventory',
    status: 'Active',
  },
  {
    code: 'FG-001',
    name: 'Steel Bar 10mm',
    category: 'Finished Goods',
    type: 'Inventory',
    status: 'Active',
  },
  {
    code: 'FG-002',
    name: 'Steel Bar 12mm',
    category: 'Finished Goods',
    type: 'Inventory',
    status: 'Active',
  },
]

function InventoryPage() {
  const [search, setSearch] =
    useState('')

  const filteredItems =
    useMemo(() => {
      const query =
        search
          .trim()
          .toLowerCase()

      if (!query) {
        return sampleItems
      }

      return sampleItems.filter(
        (item) =>
          item.code
            .toLowerCase()
            .includes(query) ||
          item.name
            .toLowerCase()
            .includes(query) ||
          item.category
            .toLowerCase()
            .includes(query) ||
          item.type
            .toLowerCase()
            .includes(query),
      )
    }, [search])

  return (
    <section className="module-page">
      <div className="page-title-row">
        <div>
          <p className="eyebrow">
            INVENTORY
          </p>

          <h3>
            Items
          </h3>

          <p>
            Manage materials, products,
            services, and other inventory
            records.
          </p>
        </div>

        <div className="page-actions">
          <Button
            variant="primary"
            type="button"
          >
            <PackagePlus
              size={16}
              strokeWidth={1.8}
              aria-hidden="true"
            />

            New Item
          </Button>
        </div>
      </div>

      <section className="list-card">
        <div className="list-toolbar">
          <SearchInput
            value={search}
            onChange={(event) =>
              setSearch(
                event.target.value,
              )
            }
            onClear={() =>
              setSearch('')
            }
            placeholder="Search items by code, name, category..."
            aria-label="Search items"
            containerClassName="list-search"
          />
        </div>

        <div className="item-list">
          {filteredItems.map(
            (item) => (
              <div
                className="item-row"
                key={item.code}
              >
                <div>
                  <strong>
                    {item.name}
                  </strong>

                  <span>
                    {item.code}
                  </span>
                </div>

                <span>
                  {item.category}
                </span>

                <span>
                  {item.type}
                </span>

                <span
                  className="item-status"
                >
                  {item.status}
                </span>
              </div>
            ),
          )}

          {filteredItems.length ===
            0 && (
            <div className="list-empty">
              <strong>
                No items found
              </strong>

              <p>
                Try a different search
                term.
              </p>
            </div>
          )}
        </div>
      </section>
    </section>
  )
}

export default InventoryPage
import {
  Save,
} from 'lucide-react'

import {
  Button,
  Card,
  Checkbox,
  Input,
  Select,
  Textarea,
} from '../components/ui'

const currencyOptions = [
  {
    value: 'PKR',
    label: 'PKR — Pakistani Rupee',
  },
  {
    value: 'USD',
    label: 'USD — US Dollar',
  },
  {
    value: 'AED',
    label: 'AED — UAE Dirham',
  },
]

const fiscalMonthOptions = [
  {
    value: '01',
    label: 'January',
  },
  {
    value: '04',
    label: 'April',
  },
  {
    value: '07',
    label: 'July',
  },
  {
    value: '10',
    label: 'October',
  },
]

function SettingsPage() {
  return (
    <section className="module-page">
      <div className="page-title-row">
        <div>
          <p className="eyebrow">
            SETTINGS
          </p>

          <h3>
            System Settings
          </h3>

          <p>
            Configure the core operating
            environment of your Elvaris
            workspace.
          </p>
        </div>

        <div className="page-actions">
          <Button
            variant="primary"
            type="button"
          >
            <Save
              size={16}
              strokeWidth={1.8}
              aria-hidden="true"
            />

            Save Changes
          </Button>
        </div>
      </div>

      <div className="settings-sections">
        {/* Company Information */}
        <Card
          title="Company Information"
          description="Basic company information used throughout Elvaris."
          padding="none"
        >
          <div className="settings-form-grid">
            <Input
              id="company-name"
              label="Company Name"
              required
              placeholder="Enter company name"
              helpText="The official business name used on documents."
            />

            <Input
              id="company-code"
              label="Company Code"
              required
              placeholder="e.g. MAIN"
              helpText="A short unique identifier for the company."
            />

            <Input
              id="company-email"
              label="Email Address"
              type="email"
              placeholder="company@example.com"
            />

            <Input
              id="company-phone"
              label="Phone Number"
              type="tel"
              placeholder="+92 xxx xxxxxxx"
            />

            <Textarea
              id="company-address"
              label="Company Address"
              placeholder="Enter the registered company address"
              helpText="This address can be used on invoices, bills, and official documents."
              rows={4}
              className="settings-field-full"
            />
          </div>
        </Card>

        {/* Fiscal Configuration */}
        <Card
          title="Fiscal Configuration"
          description="Define the initial financial environment of the company."
          padding="none"
        >
          <div className="settings-form-grid">
            <Input
              id="fiscal-year"
              label="Fiscal Year"
              required
              type="number"
              placeholder="e.g. 2026"
              min={1900}
              max={2200}
            />

            <Select
              id="base-currency"
              label="Base Currency"
              required
              placeholder="Select currency"
              options={currencyOptions}
              helpText="The primary currency used for the company."
            />

            <Select
              id="fiscal-year-start"
              label="Fiscal Year Start"
              required
              placeholder="Select starting month"
              options={fiscalMonthOptions}
              helpText="The month in which the fiscal year begins."
            />

            <Input
              id="decimal-places"
              label="Decimal Places"
              type="number"
              defaultValue="2"
              min={0}
              max={6}
              helpText="Number of decimal places used for financial values."
            />

            <Checkbox
              id="company-active"
              label="Company Active"
              description="Allow this company to be used for new transactions."
              defaultChecked
              className="settings-field-full"
            />

            <Checkbox
              id="allow-negative-stock"
              label="Allow Negative Inventory"
              description="Permit inventory quantities to fall below zero."
              className="settings-field-full"
            />
          </div>
        </Card>
      </div>
    </section>
  )
}

export default SettingsPage
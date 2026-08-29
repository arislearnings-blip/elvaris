import {
  useEffect,
  useState,
} from 'react'

import {
  Building2,
  CheckCircle2,
  MapPin,
} from 'lucide-react'

import {
  supabase,
} from '../lib/supabaseClient'

import {
  useAuth,
} from '../contexts/AuthContext'


type LookupRow = {
  id: string
  name: string
}


type Currency = LookupRow & {
  code: string
}


type CompanyForm = {
  companyCode: string
  legalName: string
  displayName: string
  countryId: string
  baseCurrencyId: string
  timeZoneId: string
  branchCode: string
  branchName: string
}


type FirstRunSetupPageProps = {
  onCompleted: () => void
}


function FirstRunSetupPage({
  onCompleted,
}: FirstRunSetupPageProps) {
  const {
    user,
  } = useAuth()


  const [
    countries,
    setCountries,
  ] = useState<LookupRow[]>([])


  const [
    currencies,
    setCurrencies,
  ] = useState<Currency[]>([])


  const [
    timeZones,
    setTimeZones,
  ] = useState<LookupRow[]>([])


  const [
    loadingLookups,
    setLoadingLookups,
  ] = useState(true)


  const [
    submitting,
    setSubmitting,
  ] = useState(false)


  const [
    error,
    setError,
  ] = useState<string | null>(null)


  const [
    completed,
    setCompleted,
  ] = useState(false)


  const [
    form,
    setForm,
  ] = useState<CompanyForm>({
    companyCode: '',
    legalName: '',
    displayName: '',
    countryId: '',
    baseCurrencyId: '',
    timeZoneId: '',
    branchCode: 'MAIN',
    branchName: 'Main Branch',
  })


  useEffect(() => {
    async function loadLookups() {
      setLoadingLookups(true)
      setError(null)

      try {
        const [
          countriesResult,
          currenciesResult,
          timeZonesResult,
        ] =
          await Promise.all([
            supabase
              .from('countries')
              .select(
                'id, name',
              )
              .eq(
                'is_active',
                true,
              )
              .order(
                'name',
              ),

            supabase
              .from('currencies')
              .select(
                'id, name, code',
              )
              .eq(
                'is_active',
                true,
              )
              .order(
                'code',
              ),

            supabase
              .from('time_zones')
              .select(
                'id, name',
              )
              .eq(
                'is_active',
                true,
              )
              .order(
                'name',
              ),
          ])


        if (
          countriesResult.error
        ) {
          throw countriesResult.error
        }


        if (
          currenciesResult.error
        ) {
          throw currenciesResult.error
        }


        if (
          timeZonesResult.error
        ) {
          throw timeZonesResult.error
        }


        setCountries(
          countriesResult.data ?? [],
        )

        setCurrencies(
          currenciesResult.data ?? [],
        )

        setTimeZones(
          timeZonesResult.data ?? [],
        )

      } catch (lookupError) {
        setError(
          lookupError instanceof Error
            ? lookupError.message
            : 'Unable to load setup data.',
        )
      } finally {
        setLoadingLookups(false)
      }
    }


    loadLookups()
  }, [])


  function updateField(
    field: keyof CompanyForm,
    value: string,
  ) {
    setForm(
      (current) => ({
        ...current,
        [field]: value,
      }),
    )
  }


  async function handleSubmit(
    event: React.FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault()

    setError(null)


    if (!user) {
      setError(
        'Your session has expired. Please sign in again.',
      )
      return
    }


    if (
      !form.companyCode.trim() ||
      !form.legalName.trim() ||
      !form.branchCode.trim() ||
      !form.branchName.trim()
    ) {
      setError(
        'Please complete all required fields.',
      )
      return
    }


    if (
      !form.baseCurrencyId
    ) {
      setError(
        'Please select a base currency.',
      )
      return
    }


    setSubmitting(true)


    try {
      const {
        data,
        error:
          bootstrapError,
      } =
        await supabase.rpc(
          'bootstrap_first_company',
          {
            p_company_code:
              form.companyCode.trim(),

            p_legal_name:
              form.legalName.trim(),

            p_display_name:
              form.displayName.trim(),

            p_country_id:
              form.countryId || null,

            p_base_currency_id:
              form.baseCurrencyId,

            p_time_zone_id:
              form.timeZoneId || null,

            p_branch_code:
              form.branchCode.trim(),

            p_branch_name:
              form.branchName.trim(),
          },
        )


      if (bootstrapError) {
        throw bootstrapError
      }


      if (
        !data ||
        !Array.isArray(data) ||
        data.length === 0
      ) {
        throw new Error(
          'Company setup completed without returning the created records.',
        )
      }


      setCompleted(true)

    } catch (bootstrapError) {
      setError(
        bootstrapError instanceof Error
          ? bootstrapError.message
          : 'Unable to complete initial company setup.',
      )
    } finally {
      setSubmitting(false)
    }
  }


  function handleContinue() {
    onCompleted()
  }


  if (completed) {
    return (
      <main className="first-run-page">
        <section className="first-run-card first-run-success">
          <div className="first-run-success-icon">
            <CheckCircle2
              size={34}
              strokeWidth={1.8}
            />
          </div>

          <p className="eyebrow">
            SETUP COMPLETE
          </p>

          <h1>
            Your Elvaris workspace is ready
          </h1>

          <p>
            Your company, main branch,
            administrator role, and access
            permissions have been configured.
          </p>

          <button
            type="button"
            className="login-submit"
            onClick={
              handleContinue
            }
          >
            Open Elvaris Workspace
          </button>
        </section>
      </main>
    )
  }


  return (
    <main className="first-run-page">
      <section className="first-run-card">

        <div className="first-run-brand">
          <div className="first-run-brand-icon">
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


        <div className="first-run-heading">
          <p className="eyebrow">
            FIRST-TIME SETUP
          </p>

          <h2>
            Set up your company
          </h2>

          <p>
            This is the initial configuration
            for your Elvaris environment.
            The first user becomes the system
            administrator.
          </p>
        </div>


        {error && (
          <div
            className="login-error"
            role="alert"
          >
            {error}
          </div>
        )}


        {loadingLookups ? (
          <div className="first-run-loading">
            Loading system master data...
          </div>
        ) : (
          <form
            className="first-run-form"
            onSubmit={
              handleSubmit
            }
          >

            <div className="first-run-section">
              <div className="first-run-section-heading">
                <Building2
                  size={19}
                  strokeWidth={1.8}
                />

                <div>
                  <h3>
                    Company
                  </h3>

                  <p>
                    Your primary legal business
                    entity.
                  </p>
                </div>
              </div>


              <div className="first-run-grid">

                <div className="login-field">
                  <label htmlFor="company-code">
                    Company Code
                    <span>*</span>
                  </label>

                  <input
                    id="company-code"
                    className="elvaris-input"
                    value={
                      form.companyCode
                    }
                    onChange={(
                      event,
                    ) =>
                      updateField(
                        'companyCode',
                        event.target.value,
                      )
                    }
                    placeholder="e.g. MOA"
                    maxLength={30}
                    required
                  />
                </div>


                <div className="login-field">
                  <label htmlFor="legal-name">
                    Legal Name
                    <span>*</span>
                  </label>

                  <input
                    id="legal-name"
                    className="elvaris-input"
                    value={
                      form.legalName
                    }
                    onChange={(
                      event,
                    ) =>
                      updateField(
                        'legalName',
                        event.target.value,
                      )
                    }
                    placeholder="Registered company name"
                    required
                  />
                </div>


                <div className="login-field first-run-full">
                  <label htmlFor="display-name">
                    Display Name
                  </label>

                  <input
                    id="display-name"
                    className="elvaris-input"
                    value={
                      form.displayName
                    }
                    onChange={(
                      event,
                    ) =>
                      updateField(
                        'displayName',
                        event.target.value,
                      )
                    }
                    placeholder="Name shown throughout Elvaris"
                  />
                </div>


                <div className="login-field">
                  <label htmlFor="country">
                    Country
                  </label>

                  <select
                    id="country"
                    className="elvaris-select"
                    value={
                      form.countryId
                    }
                    onChange={(
                      event,
                    ) =>
                      updateField(
                        'countryId',
                        event.target.value,
                      )
                    }
                  >
                    <option value="">
                      Select country
                    </option>

                    {countries.map(
                      (country) => (
                        <option
                          key={
                            country.id
                          }
                          value={
                            country.id
                          }
                        >
                          {country.name}
                        </option>
                      ),
                    )}
                  </select>
                </div>


                <div className="login-field">
                  <label htmlFor="base-currency">
                    Base Currency
                    <span>*</span>
                  </label>

                  <select
                    id="base-currency"
                    className="elvaris-select"
                    value={
                      form.baseCurrencyId
                    }
                    onChange={(
                      event,
                    ) =>
                      updateField(
                        'baseCurrencyId',
                        event.target.value,
                      )
                    }
                    required
                  >
                    <option value="">
                      Select currency
                    </option>

                    {currencies.map(
                      (currency) => (
                        <option
                          key={
                            currency.id
                          }
                          value={
                            currency.id
                          }
                        >
                          {currency.code} —{' '}
                          {currency.name}
                        </option>
                      ),
                    )}
                  </select>
                </div>


                <div className="login-field first-run-full">
                  <label htmlFor="time-zone">
                    Time Zone
                  </label>

                  <select
                    id="time-zone"
                    className="elvaris-select"
                    value={
                      form.timeZoneId
                    }
                    onChange={(
                      event,
                    ) =>
                      updateField(
                        'timeZoneId',
                        event.target.value,
                      )
                    }
                  >
                    <option value="">
                      Select time zone
                    </option>

                    {timeZones.map(
                      (timeZone) => (
                        <option
                          key={
                            timeZone.id
                          }
                          value={
                            timeZone.id
                          }
                        >
                          {timeZone.name}
                        </option>
                      ),
                    )}
                  </select>
                </div>

              </div>
            </div>


            <div className="first-run-section">
              <div className="first-run-section-heading">
                <MapPin
                  size={19}
                  strokeWidth={1.8}
                />

                <div>
                  <h3>
                    First Branch
                  </h3>

                  <p>
                    Your initial operating
                    location.
                  </p>
                </div>
              </div>


              <div className="first-run-grid">

                <div className="login-field">
                  <label htmlFor="branch-code">
                    Branch Code
                    <span>*</span>
                  </label>

                  <input
                    id="branch-code"
                    className="elvaris-input"
                    value={
                      form.branchCode
                    }
                    onChange={(
                      event,
                    ) =>
                      updateField(
                        'branchCode',
                        event.target.value,
                      )
                    }
                    placeholder="MAIN"
                    maxLength={30}
                    required
                  />
                </div>


                <div className="login-field">
                  <label htmlFor="branch-name">
                    Branch Name
                    <span>*</span>
                  </label>

                  <input
                    id="branch-name"
                    className="elvaris-input"
                    value={
                      form.branchName
                    }
                    onChange={(
                      event,
                    ) =>
                      updateField(
                        'branchName',
                        event.target.value,
                      )
                    }
                    placeholder="Main Branch"
                    required
                  />
                </div>

              </div>
            </div>


            <div className="first-run-actions">
              <p>
                Signed in as{' '}
                <strong>
                  {user?.email ?? 'authenticated user'}
                </strong>
              </p>

              <button
                type="submit"
                className="login-submit"
                disabled={
                  submitting
                }
              >
                {submitting
                  ? 'Creating workspace...'
                  : 'Create Elvaris Workspace'}
              </button>
            </div>

          </form>
        )}

      </section>
    </main>
  )
}


export default FirstRunSetupPage
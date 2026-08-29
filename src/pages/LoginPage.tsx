import {
  useState,
} from 'react'

import type {
  FormEvent,
} from 'react'

import {
  LockKeyhole,
  Mail,
} from 'lucide-react'

import {
  useAuth,
} from '../contexts/AuthContext'


function LoginPage() {
  const {
    login,
    authError,
  } = useAuth()


  const [
    email,
    setEmail,
  ] = useState('')


  const [
    password,
    setPassword,
  ] = useState('')


  const [
    submitting,
    setSubmitting,
  ] = useState(false)


  async function handleSubmit(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault()

    setSubmitting(true)

    try {
      await login(
        email,
        password,
      )
    } catch {
      /*
       * AuthContext stores the
       * authentication error.
       */
    } finally {
      setSubmitting(false)
    }
  }


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


        <div className="login-heading">
          <p className="eyebrow">
            SECURE ACCESS
          </p>

          <h2>
            Sign in to Elvaris
          </h2>

          <p>
            Enter your authorized
            credentials to continue
            to the workspace.
          </p>
        </div>


        <form
          className="login-form"
          onSubmit={
            handleSubmit
          }
        >

          <div className="login-field">
            <label
              htmlFor="login-email"
            >
              Email Address
              <span aria-hidden="true">
                *
              </span>
            </label>

            <div className="login-input-wrapper">
              <Mail
                size={17}
                strokeWidth={1.8}
                aria-hidden="true"
              />

              <input
                id="login-email"
                type="email"
                value={email}
                onChange={(
                  event,
                ) =>
                  setEmail(
                    event.target.value,
                  )
                }
                placeholder="you@example.com"
                autoComplete="email"
                required
              />
            </div>
          </div>


          <div className="login-field">
            <label
              htmlFor="login-password"
            >
              Password
              <span aria-hidden="true">
                *
              </span>
            </label>

            <div className="login-input-wrapper">
              <LockKeyhole
                size={17}
                strokeWidth={1.8}
                aria-hidden="true"
              />

              <input
                id="login-password"
                type="password"
                value={password}
                onChange={(
                  event,
                ) =>
                  setPassword(
                    event.target.value,
                  )
                }
                placeholder="Enter your password"
                autoComplete="current-password"
                required
              />
            </div>
          </div>


          {authError && (
            <div
              className="login-error"
              role="alert"
            >
              {authError}
            </div>
          )}


          <button
            type="submit"
            className="login-submit"
            disabled={
              submitting
            }
          >
            {submitting
              ? 'Signing in...'
              : 'Sign In'}
          </button>

        </form>


        <p className="login-footer">
          Access is controlled by
          your Elvaris user account,
          roles, permissions, company,
          and branch assignments.
        </p>

      </section>
    </main>
  )
}


export default LoginPage
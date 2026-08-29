import {
  useState,
} from 'react'

import type {
  FormEvent,
} from 'react'

import {
  Eye,
  EyeOff,
  LockKeyhole,
  Mail,
} from 'lucide-react'

import {
  useAuth,
} from '../contexts/AuthContext'

import {
  sendPasswordResetEmail,
} from '../services/authService'


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
    showPassword,
    setShowPassword,
  ] = useState(false)


  const [
    submitting,
    setSubmitting,
  ] = useState(false)


  const [
    forgotMode,
    setForgotMode,
  ] = useState(false)


  const [
    resetMessage,
    setResetMessage,
  ] = useState<string | null>(
    null,
  )


  async function handleSubmit(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault()

    setResetMessage(null)
    setSubmitting(true)

    try {
      await login(
        email.trim(),
        password,
      )
    } catch {
      /*
       * AuthContext already stores
       * and displays the authentication error.
       */
    } finally {
      setSubmitting(false)
    }
  }


  async function handleForgotPassword() {
    setResetMessage(null)


    const normalizedEmail =
      email.trim()


    if (!normalizedEmail) {
      setResetMessage(
        'Enter your email address first.',
      )
      return
    }


    setSubmitting(true)


    try {
      await sendPasswordResetEmail(
        normalizedEmail,
      )


      setResetMessage(
        'If an account exists for this email address, a password reset link has been sent.',
      )

    } catch (error) {
      setResetMessage(
        error instanceof Error
          ? error.message
          : 'Unable to send the password reset request.',
      )
    } finally {
      setSubmitting(false)
    }
  }


  function openForgotPassword() {
    setResetMessage(null)
    setForgotMode(true)
  }


  function backToSignIn() {
    setResetMessage(null)
    setForgotMode(false)
  }


  return (
    <main className="login-page">
      <section className="login-card">

        {/* ==================================================
            BRAND
        ================================================== */}

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


        {/* ==================================================
            HEADING
        ================================================== */}

        <div className="login-heading">

          <p className="eyebrow">
            {forgotMode
              ? 'PASSWORD RECOVERY'
              : 'SECURE ACCESS'}
          </p>

          <h2>
            {forgotMode
              ? 'Reset your password'
              : 'Sign in to Elvaris'}
          </h2>

          <p>
            {forgotMode
              ? 'Enter your Elvaris account email and we will send you a secure password reset link.'
              : 'Enter your authorized credentials to continue to the workspace.'}
          </p>

        </div>


        {/* ==================================================
            SIGN IN
        ================================================== */}

        {!forgotMode && (
          <form
            className="login-form"
            onSubmit={
              handleSubmit
            }
          >

            {/* Email */}

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


            {/* Password */}

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
                  type={
                    showPassword
                      ? 'text'
                      : 'password'
                  }
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


                <button
                  type="button"
                  className="login-password-toggle"
                  aria-label={
                    showPassword
                      ? 'Hide password'
                      : 'Show password'
                  }
                  title={
                    showPassword
                      ? 'Hide password'
                      : 'Show password'
                  }
                  onClick={() =>
                    setShowPassword(
                      (
                        current,
                      ) =>
                        !current,
                    )
                  }
                >

                  {showPassword ? (
                    <EyeOff
                      size={17}
                      strokeWidth={1.8}
                      aria-hidden="true"
                    />
                  ) : (
                    <Eye
                      size={17}
                      strokeWidth={1.8}
                      aria-hidden="true"
                    />
                  )}

                </button>

              </div>

            </div>


            {/* Authentication error */}

            {authError && (
              <div
                className="login-error"
                role="alert"
              >
                {authError}
              </div>
            )}


            {/* Sign in */}

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


            {/* Forgot password */}

            <button
              type="button"
              className="login-link-button"
              onClick={
                openForgotPassword
              }
              disabled={
                submitting
              }
            >
              Forgot password?
            </button>

          </form>
        )}


        {/* ==================================================
            PASSWORD RECOVERY
        ================================================== */}

        {forgotMode && (
          <div className="login-form">

            {/* Email */}

            <div className="login-field">

              <label
                htmlFor="reset-email"
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
                  id="reset-email"
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
                  disabled={
                    submitting
                  }
                />

              </div>

            </div>


            {/* Recovery message */}

            {resetMessage && (
              <div
                className={
                  resetMessage.startsWith(
                    'If an account exists',
                  )
                    ? 'login-info'
                    : 'login-error'
                }
                role="status"
              >
                {resetMessage}
              </div>
            )}


            {/* Send reset link */}

            <button
              type="button"
              className="login-submit"
              onClick={
                handleForgotPassword
              }
              disabled={
                submitting
              }
            >
              {submitting
                ? 'Sending...'
                : 'Send Reset Link'}
            </button>


            {/* Back */}

            <button
              type="button"
              className="login-link-button"
              onClick={
                backToSignIn
              }
              disabled={
                submitting
              }
            >
              Back to sign in
            </button>

          </div>
        )}


        {/* ==================================================
            FOOTER
        ================================================== */}

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
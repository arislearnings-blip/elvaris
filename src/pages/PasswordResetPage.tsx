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
} from 'lucide-react'

import {
  supabase,
} from '../lib/supabaseClient'


type PasswordResetPageProps = {
  onCompleted: () => void
}


function PasswordResetPage({
  onCompleted,
}: PasswordResetPageProps) {
  const [
    password,
    setPassword,
  ] = useState('')


  const [
    confirmPassword,
    setConfirmPassword,
  ] = useState('')


  const [
    showPassword,
    setShowPassword,
  ] = useState(false)


  const [
    showConfirmPassword,
    setShowConfirmPassword,
  ] = useState(false)


  const [
    submitting,
    setSubmitting,
  ] = useState(false)


  const [
    error,
    setError,
  ] = useState<string | null>(
    null,
  )


  const [
    success,
    setSuccess,
  ] = useState(false)


  async function handleSubmit(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault()

    setError(null)


    if (
      password.length < 8
    ) {
      setError(
        'Password must contain at least 8 characters.',
      )
      return
    }


    if (
      password !==
      confirmPassword
    ) {
      setError(
        'The passwords do not match.',
      )
      return
    }


    setSubmitting(true)


    try {
      const {
        error:
          updateError,
      } =
        await supabase.auth.updateUser({
          password,
        })


      if (updateError) {
        throw updateError
      }


      setSuccess(true)

    } catch (updateError) {
      setError(
        updateError instanceof Error
          ? updateError.message
          : 'Unable to update your password.',
      )
    } finally {
      setSubmitting(false)
    }
  }


  if (success) {
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
              PASSWORD UPDATED
            </p>

            <h2>
              Your password has been changed
            </h2>

            <p>
              Your Elvaris account password
              was updated successfully.
            </p>
          </div>


          <button
            type="button"
            className="login-submit"
            onClick={onCompleted}
          >
            Continue to Elvaris
          </button>

        </section>
      </main>
    )
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
            SECURE PASSWORD RESET
          </p>

          <h2>
            Create a new password
          </h2>

          <p>
            Choose a new password for
            your Elvaris account.
          </p>
        </div>


        <form
          className="login-form"
          onSubmit={
            handleSubmit
          }
        >

          <div className="login-field">
            <label htmlFor="new-password">
              New Password
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
                id="new-password"
                type={
                  showPassword
                    ? 'text'
                    : 'password'
                }
                value={
                  password
                }
                onChange={(
                  event,
                ) =>
                  setPassword(
                    event.target.value,
                  )
                }
                placeholder="Enter new password"
                autoComplete="new-password"
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
                onClick={() =>
                  setShowPassword(
                    (current) =>
                      !current,
                  )
                }
              >
                {showPassword ? (
                  <EyeOff
                    size={17}
                    strokeWidth={1.8}
                  />
                ) : (
                  <Eye
                    size={17}
                    strokeWidth={1.8}
                  />
                )}
              </button>
            </div>
          </div>


          <div className="login-field">
            <label htmlFor="confirm-password">
              Confirm Password
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
                id="confirm-password"
                type={
                  showConfirmPassword
                    ? 'text'
                    : 'password'
                }
                value={
                  confirmPassword
                }
                onChange={(
                  event,
                ) =>
                  setConfirmPassword(
                    event.target.value,
                  )
                }
                placeholder="Re-enter new password"
                autoComplete="new-password"
                required
              />

              <button
                type="button"
                className="login-password-toggle"
                aria-label={
                  showConfirmPassword
                    ? 'Hide password'
                    : 'Show password'
                }
                onClick={() =>
                  setShowConfirmPassword(
                    (current) =>
                      !current,
                  )
                }
              >
                {showConfirmPassword ? (
                  <EyeOff
                    size={17}
                    strokeWidth={1.8}
                  />
                ) : (
                  <Eye
                    size={17}
                    strokeWidth={1.8}
                  />
                )}
              </button>
            </div>
          </div>


          {error && (
            <div
              className="login-error"
              role="alert"
            >
              {error}
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
              ? 'Updating password...'
              : 'Update Password'}
          </button>

        </form>

      </section>
    </main>
  )
}


export default PasswordResetPage
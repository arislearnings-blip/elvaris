import type {
  InputHTMLAttributes,
} from 'react'

type InputProps =
  InputHTMLAttributes<HTMLInputElement> & {
    label?: string
    required?: boolean
    helpText?: string
    error?: string
  }

function Input({
  label,
  required = false,
  helpText,
  error,
  id,
  className = '',
  disabled,
  ...props
}: InputProps) {
  const inputId =
    id ??
    `elvaris-input-${Math.random()
      .toString(36)
      .slice(2, 9)}`

  const helpTextId =
    helpText
      ? `${inputId}-help`
      : undefined

  const errorId =
    error
      ? `${inputId}-error`
      : undefined

  const describedBy =
    [
      helpTextId,
      errorId,
    ]
      .filter(Boolean)
      .join(' ') || undefined

  return (
    <div className="elvaris-field">
      {label && (
        <label
          htmlFor={inputId}
          className="elvaris-field__label"
        >
          <span>{label}</span>

          {required && (
            <span
              className="elvaris-field__required"
              aria-hidden="true"
            >
              *
            </span>
          )}
        </label>
      )}

      <input
        {...props}
        id={inputId}
        disabled={disabled}
        aria-invalid={
          error ? true : undefined
        }
        aria-describedby={
          describedBy
        }
        className={`elvaris-input ${
          error
            ? 'elvaris-input--error'
            : ''
        } ${className}`.trim()}
      />

      {helpText && !error && (
        <p
          id={helpTextId}
          className="elvaris-field__help"
        >
          {helpText}
        </p>
      )}

      {error && (
        <p
          id={errorId}
          className="elvaris-field__error"
          role="alert"
        >
          {error}
        </p>
      )}
    </div>
  )
}

export default Input
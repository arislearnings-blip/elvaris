import type {
  TextareaHTMLAttributes,
} from 'react'

type TextareaProps =
  TextareaHTMLAttributes<HTMLTextAreaElement> & {
    label?: string
    required?: boolean
    helpText?: string
    error?: string
  }

function Textarea({
  label,
  required = false,
  helpText,
  error,
  id,
  className = '',
  disabled,
  ...props
}: TextareaProps) {
  const textareaId =
    id ?? 'elvaris-textarea'

  const helpTextId =
    helpText
      ? `${textareaId}-help`
      : undefined

  const errorId =
    error
      ? `${textareaId}-error`
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
          htmlFor={textareaId}
          className="elvaris-field__label"
        >
          <span>
            {label}
          </span>

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

      <textarea
        {...props}
        id={textareaId}
        disabled={disabled}
        aria-invalid={
          error
            ? true
            : undefined
        }
        aria-describedby={
          describedBy
        }
        className={`elvaris-textarea ${
          error
            ? 'elvaris-textarea--error'
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

export default Textarea
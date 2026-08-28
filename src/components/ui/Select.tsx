import type {
  SelectHTMLAttributes,
} from 'react'

export type SelectOption = {
  value: string
  label: string
  disabled?: boolean
}

type SelectProps =
  SelectHTMLAttributes<HTMLSelectElement> & {
    label?: string
    required?: boolean
    helpText?: string
    error?: string
    options: SelectOption[]
    placeholder?: string
  }

function Select({
  label,
  required = false,
  helpText,
  error,
  options,
  placeholder,
  id,
  className = '',
  disabled,
  ...props
}: SelectProps) {
  const selectId =
    id ?? 'elvaris-select'

  const helpTextId =
    helpText
      ? `${selectId}-help`
      : undefined

  const errorId =
    error
      ? `${selectId}-error`
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
          htmlFor={selectId}
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

      <div
        className={`elvaris-select-wrapper ${
          error
            ? 'elvaris-select-wrapper--error'
            : ''
        }`}
      >
        <select
          {...props}
          id={selectId}
          disabled={disabled}
          aria-invalid={
            error
              ? true
              : undefined
          }
          aria-describedby={
            describedBy
          }
          className={`elvaris-select ${
            className
          }`.trim()}
        >
          {placeholder && (
            <option
              value=""
              disabled
            >
              {placeholder}
            </option>
          )}

          {options.map(
            (option) => (
              <option
                key={option.value}
                value={option.value}
                disabled={
                  option.disabled
                }
              >
                {option.label}
              </option>
            ),
          )}
        </select>
      </div>

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

export default Select
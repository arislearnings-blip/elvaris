import type {
  ChangeEvent,
  InputHTMLAttributes,
} from 'react'

type CheckboxProps = Omit<
  InputHTMLAttributes<HTMLInputElement>,
  'type'
> & {
  label: string
  description?: string
  error?: string
}

function Checkbox({
  label,
  description,
  error,
  id,
  disabled,
  className = '',
  ...props
}: CheckboxProps) {
  const checkboxId =
    id ?? 'elvaris-checkbox'

  const descriptionId =
    description
      ? `${checkboxId}-description`
      : undefined

  const errorId =
    error
      ? `${checkboxId}-error`
      : undefined

  const describedBy =
    [
      descriptionId,
      errorId,
    ]
      .filter(Boolean)
      .join(' ') || undefined

  const handleChange = (
    event: ChangeEvent<HTMLInputElement>,
  ) => {
    props.onChange?.(event)
  }

  return (
    <div
      className={`elvaris-checkbox-field ${
        error
          ? 'elvaris-checkbox-field--error'
          : ''
      } ${className}`.trim()}
    >
      <label
        htmlFor={checkboxId}
        className="elvaris-checkbox"
      >
        <input
          {...props}
          type="checkbox"
          id={checkboxId}
          disabled={disabled}
          aria-invalid={
            error
              ? true
              : undefined
          }
          aria-describedby={
            describedBy
          }
          onChange={handleChange}
        />

        <span
          className="elvaris-checkbox__control"
          aria-hidden="true"
        >
          <svg
            viewBox="0 0 16 16"
            fill="none"
          >
            <path
              d="M3.25 8.25 6.5 11.5 12.75 4.75"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </span>

        <span className="elvaris-checkbox__content">
          <span className="elvaris-checkbox__label">
            {label}
          </span>

          {description && (
            <span
              id={descriptionId}
              className="elvaris-checkbox__description"
            >
              {description}
            </span>
          )}
        </span>
      </label>

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

export default Checkbox
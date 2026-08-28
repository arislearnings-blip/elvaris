import type {
  ButtonHTMLAttributes,
  ReactNode,
} from 'react'

export type ButtonVariant =
  | 'primary'
  | 'secondary'
  | 'danger'
  | 'ghost'
  | 'success'
  | 'warning'

export type ButtonSize =
  | 'sm'
  | 'md'
  | 'lg'

type ButtonProps =
  ButtonHTMLAttributes<HTMLButtonElement> & {
    children: ReactNode
    variant?: ButtonVariant
    size?: ButtonSize
    loading?: boolean
    fullWidth?: boolean
  }

function Button({
  children,
  variant = 'primary',
  size = 'md',
  loading = false,
  fullWidth = false,
  className = '',
  disabled,
  ...props
}: ButtonProps) {
  const classes = [
    'elvaris-button',
    `elvaris-button--${variant}`,
    `elvaris-button--${size}`,
    fullWidth
      ? 'elvaris-button--full-width'
      : '',
    className,
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <button
      {...props}
      className={classes}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
    >
      {loading ? (
        <>
          <span
            className="elvaris-button__spinner"
            aria-hidden="true"
          />

          <span>
            Processing...
          </span>
        </>
      ) : (
        children
      )}
    </button>
  )
}

export default Button
import type {
  HTMLAttributes,
  ReactNode,
} from 'react'

type CardProps =
  HTMLAttributes<HTMLElement> & {
    children: ReactNode
    title?: string
    description?: string
    headerContent?: ReactNode
    footerContent?: ReactNode
    padding?: 'none' | 'sm' | 'md' | 'lg'
  }

function Card({
  children,
  title,
  description,
  headerContent,
  footerContent,
  padding = 'md',
  className = '',
  ...props
}: CardProps) {
  const classes = [
    'elvaris-card',
    `elvaris-card--padding-${padding}`,
    className,
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <section
      {...props}
      className={classes}
    >
      {(title ||
        description ||
        headerContent) && (
        <div className="elvaris-card__header">
          <div className="elvaris-card__heading">
            {title && (
              <h3 className="elvaris-card__title">
                {title}
              </h3>
            )}

            {description && (
              <p className="elvaris-card__description">
                {description}
              </p>
            )}
          </div>

          {headerContent && (
            <div className="elvaris-card__header-content">
              {headerContent}
            </div>
          )}
        </div>
      )}

      <div className="elvaris-card__body">
        {children}
      </div>

      {footerContent && (
        <div className="elvaris-card__footer">
          {footerContent}
        </div>
      )}
    </section>
  )
}

export default Card
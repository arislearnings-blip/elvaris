import {
  Search,
  X,
} from 'lucide-react'

import type {
  InputHTMLAttributes,
  ReactNode,
} from 'react'

type SearchInputProps =
  Omit<
    InputHTMLAttributes<HTMLInputElement>,
    'type'
  > & {
    value: string
    onClear?: () => void
    containerClassName?: string
    startContent?: ReactNode
  }

function SearchInput({
  value,
  onClear,
  placeholder = 'Search...',
  disabled = false,
  className = '',
  containerClassName = '',
  startContent,
  id,
  ...props
}: SearchInputProps) {
  const inputId =
    id ?? 'elvaris-search'

  const hasValue =
    value.length > 0

  return (
    <div
      className={`elvaris-search ${
        containerClassName
      }`.trim()}
    >
      <div className="elvaris-search__icon">
        {startContent ?? (
          <Search
            size={17}
            strokeWidth={1.8}
            aria-hidden="true"
          />
        )}
      </div>

      <input
        {...props}
        id={inputId}
        type="search"
        value={value}
        placeholder={placeholder}
        disabled={disabled}
        className={`elvaris-search__input ${
          className
        }`.trim()}
        aria-label={
          props['aria-label'] ??
          'Search'
        }
      />

      {hasValue &&
        !disabled &&
        onClear && (
          <button
            type="button"
            className="elvaris-search__clear"
            onClick={onClear}
            aria-label="Clear search"
          >
            <X
              size={15}
              strokeWidth={1.8}
              aria-hidden="true"
            />
          </button>
        )}
    </div>
  )
}

export default SearchInput
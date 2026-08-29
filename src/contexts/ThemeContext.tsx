import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react'

export type Theme =
  | 'light'
  | 'dark'
  | 'contrast'

type ThemeContextValue = {
  theme: Theme
  setTheme: (theme: Theme) => void
}

const ThemeContext =
  createContext<
    ThemeContextValue | undefined
  >(undefined)

const STORAGE_KEY =
  'elvaris-theme'

function getInitialTheme(): Theme {
  const stored =
    window.localStorage.getItem(
      STORAGE_KEY,
    )

  if (
    stored === 'dark' ||
    stored === 'contrast' ||
    stored === 'light'
  ) {
    return stored
  }

  return 'light'
}

function applyTheme(
  theme: Theme,
) {
  document.documentElement.setAttribute(
    'data-theme',
    theme,
  )
}

export function ThemeProvider({
  children,
}: {
  children: React.ReactNode
}) {
  const [
    theme,
    setThemeState,
  ] =
    useState<Theme>(
      getInitialTheme,
    )

  useEffect(() => {
    applyTheme(theme)

    window.localStorage.setItem(
      STORAGE_KEY,
      theme,
    )
  }, [theme])

  const value =
    useMemo(
      () => ({
        theme,

        setTheme: (
          nextTheme: Theme,
        ) => {
          setThemeState(
            nextTheme,
          )
        },
      }),
      [theme],
    )

  return (
    <ThemeContext.Provider
      value={value}
    >
      {children}
    </ThemeContext.Provider>
  )
}

export function useTheme() {
  const context =
    useContext(
      ThemeContext,
    )

  if (!context) {
    throw new Error(
      'useTheme must be used inside a ThemeProvider.',
    )
  }

  return context
}
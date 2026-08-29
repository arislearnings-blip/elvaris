import {
  StrictMode,
} from 'react'

import {
  createRoot,
} from 'react-dom/client'

import './index.css'

import App from './app.tsx'

import {
  AuthProvider,
} from './contexts/AuthContext'

import {
  ThemeProvider,
} from './contexts/ThemeContext'

createRoot(
  document.getElementById(
    'root',
  )!,
).render(
  <StrictMode>
    <ThemeProvider>
      <AuthProvider>
        <App />
      </AuthProvider>
    </ThemeProvider>
  </StrictMode>,
)
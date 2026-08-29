import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react'

import type {
  Session,
  User,
} from '@supabase/supabase-js'

import {
  supabase,
} from '../lib/supabaseClient'

import {
  ensureUserProfile,
  signIn,
  signOut,
} from '../services/authService'


type AuthContextValue = {
  user: User | null
  session: Session | null
  loading: boolean
  authError: string | null
  recoveryMode: boolean

  login: (
    email: string,
    password: string,
  ) => Promise<void>

  logout: () => Promise<void>

  exitRecoveryMode: () => void
}


const AuthContext =
  createContext<
    AuthContextValue | undefined
  >(undefined)


export function AuthProvider({
  children,
}: {
  children: React.ReactNode
}) {
  const [
    session,
    setSession,
  ] =
    useState<Session | null>(null)


  const [
    loading,
    setLoading,
  ] =
    useState(true)


  const [
    authError,
    setAuthError,
  ] =
    useState<string | null>(
      null,
    )


  const [
    recoveryMode,
    setRecoveryMode,
  ] =
    useState(false)


  useEffect(() => {
    let mounted = true


    async function initializeAuth() {
      try {
        const {
          data,
          error,
        } =
          await supabase.auth.getSession()


        if (error) {
          throw error
        }


        if (!mounted) {
          return
        }


        const currentSession =
          data.session


        if (currentSession) {
          try {
            await ensureUserProfile()
          } catch (profileError) {
            await supabase.auth.signOut()

            throw profileError
          }
        }


        setSession(
          currentSession,
        )

      } catch (error) {
        if (mounted) {
          setSession(null)

          setAuthError(
            error instanceof Error
              ? error.message
              : 'Unable to initialize authentication.',
          )
        }
      } finally {
        if (mounted) {
          setLoading(false)
        }
      }
    }


    initializeAuth()


    const {
      data:
        authListener,
    } =
      supabase.auth.onAuthStateChange(
        async (
          event,
          newSession,
        ) => {
          if (!mounted) {
            return
          }


          setSession(
            newSession,
          )


          /*
           * Supabase sends this event after
           * a password recovery link establishes
           * a recovery session.
           */
          if (
            event ===
            'PASSWORD_RECOVERY'
          ) {
            setRecoveryMode(
              true,
            )

            setAuthError(
              null,
            )

            return
          }


          /*
           * For normal authentication events,
           * ensure the Elvaris application profile
           * exists.
           */
          if (
            newSession
          ) {
            try {
              await ensureUserProfile()

              if (mounted) {
                setAuthError(
                  null,
                )
              }
            } catch (error) {
              await supabase.auth.signOut()

              if (mounted) {
                setSession(null)

                setAuthError(
                  error instanceof Error
                    ? error.message
                    : 'Unable to initialize the Elvaris user profile.',
                )
              }
            }
          }
        },
      )


    return () => {
      mounted = false

      authListener.subscription.unsubscribe()
    }
  }, [])


  async function login(
    email: string,
    password: string,
  ) {
    setAuthError(null)
    setRecoveryMode(false)


    try {
      await signIn(
        email.trim(),
        password,
      )
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : 'Unable to sign in.'


      setAuthError(
        message,
      )

      throw error
    }
  }


  async function logout() {
    setAuthError(null)
    setRecoveryMode(false)

    await signOut()

    setSession(null)
  }


  function exitRecoveryMode() {
    setRecoveryMode(false)

    /*
     * Remove the recovery query parameter
     * from the browser URL.
     */
    window.history.replaceState(
      {},
      document.title,
      window.location.pathname,
    )
  }


  const value =
    useMemo(
      () => ({
        user:
          session?.user ?? null,

        session,

        loading,

        authError,

        recoveryMode,

        login,

        logout,

        exitRecoveryMode,
      }),
      [
        session,
        loading,
        authError,
        recoveryMode,
      ],
    )


  return (
    <AuthContext.Provider
      value={value}
    >
      {children}
    </AuthContext.Provider>
  )
}


export function useAuth() {
  const context =
    useContext(
      AuthContext,
    )


  if (!context) {
    throw new Error(
      'useAuth must be used inside an AuthProvider.',
    )
  }


  return context
}
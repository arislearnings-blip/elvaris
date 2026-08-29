import type {
  Session,
  User,
} from '@supabase/supabase-js'

import {
  supabase,
} from '../lib/supabaseClient'


export type AuthResult = {
  user: User
  session: Session
}


export async function signIn(
  email: string,
  password: string,
): Promise<AuthResult> {
  const {
    data,
    error,
  } =
    await supabase.auth.signInWithPassword({
      email,
      password,
    })

  if (error) {
    throw new Error(
      error.message,
    )
  }

  if (
    !data.user ||
    !data.session
  ) {
    throw new Error(
      'Authentication succeeded but no user session was returned.',
    )
  }

  /*
   * Create or retrieve the corresponding
   * Elvaris user profile.
   */
  const {
    error:
      profileError,
  } =
    await supabase.rpc(
      'ensure_current_user_profile',
    )

  if (profileError) {
    /*
     * Sign out if the Elvaris application
     * profile cannot be initialized.
     */
    await supabase.auth.signOut()

    throw new Error(
      `Elvaris profile initialization failed: ${profileError.message}`,
    )
  }

  return {
    user: data.user,
    session: data.session,
  }
}


export async function signOut(): Promise<void> {
  const {
    error,
  } =
    await supabase.auth.signOut()

  if (error) {
    throw new Error(
      error.message,
    )
  }
}


export async function getSession(): Promise<Session | null> {
  const {
    data,
    error,
  } =
    await supabase.auth.getSession()

  if (error) {
    throw new Error(
      error.message,
    )
  }

  return data.session
}


export async function ensureUserProfile(): Promise<string> {
  const {
    data,
    error,
  } =
    await supabase.rpc(
      'ensure_current_user_profile',
    )

  if (error) {
    throw new Error(
      error.message,
    )
  }

  if (!data) {
    throw new Error(
      'Elvaris user profile could not be initialized.',
    )
  }

  return data as string
}
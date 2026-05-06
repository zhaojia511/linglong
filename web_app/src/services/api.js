import { supabase } from './supabaseClient'
export { sessionService, personService, readinessService } from './db'

export const authService = {
  login: async (email, password) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    return { user: data.user, session: data.session }
  },

  register: async (email, password, name) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { name } },
    })
    if (error) throw error
    return { user: data.user, session: data.session }
  },

  resetPassword: async (email) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    if (error) throw error
    return { message: 'Password reset email sent successfully' }
  },

  updatePassword: async (newPassword) => {
    const { data, error } = await supabase.auth.updateUser({ password: newPassword })
    if (error) throw error
    return data
  },

  logout: async () => {
    await supabase.auth.signOut()
  },

  getCurrentUser: async () => {
    const { data } = await supabase.auth.getUser()
    return data.user || null
  },

  isAuthenticated: async () => {
    const { data } = await supabase.auth.getSession()
    return !!data.session?.access_token
  },
}

export default {}

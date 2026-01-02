import axios from 'axios'
import { supabase } from './supabaseClient'

const API_BASE_URL = '/api'

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Inject Supabase access token into backend requests
api.interceptors.request.use(async (config) => {
  const { data } = await supabase.auth.getSession()
  const token = data.session?.access_token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

export const authService = {
  login: async (email, password) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    return { user: data.user, session: data.session }
  },

  register: async (email, password, name) => {
    // signUp returns a session if email confirmation disabled; otherwise user only
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
      redirectTo: `${window.location.origin}/reset-password`
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

export const sessionService = {
  getSessions: async (params = {}) => {
    const response = await api.get('/sessions', { params });
    return response.data;
  },

  getSession: async (id) => {
    const response = await api.get(`/sessions/${id}`);
    return response.data;
  },

  getStats: async (params = {}) => {
    const response = await api.get('/sessions/stats/summary', { params });
    return response.data;
  },

  deleteSession: async (id) => {
    const response = await api.delete(`/sessions/${id}`);
    return response.data;
  },
};

export const personService = {
  getPersons: async () => {
    const response = await api.get('/persons');
    return response.data;
  },

  getPerson: async (id) => {
    const response = await api.get(`/persons/${id}`);
    return response.data;
  },
};

export default api;

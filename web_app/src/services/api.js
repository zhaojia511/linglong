import axios from 'axios'
import { supabase } from './supabaseClient'

// Determine API base URL based on environment
const getAPIBaseURL = () => {
  // Check for environment variable first (for production)
  if (import.meta.env.VITE_API_BASE_URL) {
    return import.meta.env.VITE_API_BASE_URL
  }
  
  // Fallback for development
  if (typeof window !== 'undefined' && window.location.hostname === 'localhost') {
    return 'http://localhost:3000/api'
  }
  
  // Default to relative path (proxy setup needed)
  return '/api'
}

const API_BASE_URL = getAPIBaseURL()

console.log('API Base URL:', API_BASE_URL) // For debugging

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
  } else {
    console.warn('No auth token available')
  }
  return config
})

// Add response error logging
api.interceptors.response.use(
  response => response,
  error => {
    console.error('API Error:', {
      status: error.response?.status,
      statusText: error.response?.statusText,
      url: error.config?.url,
      method: error.config?.method,
      data: error.response?.data,
      message: error.message
    })
    return Promise.reject(error)
  }
)

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
      redirectTo: 'https://linglong-test.pages.dev/reset-password'
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

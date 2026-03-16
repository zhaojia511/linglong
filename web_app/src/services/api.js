import axios from 'axios'
import { supabase } from './supabaseClient'
// Use Node helper for tests, Vite helper otherwise
const isTest = typeof process !== 'undefined' && process.env && process.env.NODE_ENV === 'test';
const { getEnvVar } = isTest
  ? require('./envHelperNode.js')
  : require('./envHelperVite.js');


// Determine API base URL based on environment (Vite or Jest/node)
const API_BASE_URL = getEnvVar('VITE_API_BASE_URL', '/api')

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
    let query = supabase.from('training_sessions').select('*').order('start_time', { ascending: false })
    
    if (params.limit) {
      query = query.limit(params.limit)
    }
    
    const { data, error } = await query
    if (error) throw error
    
    // Transform snake_case to camelCase for frontend
    return (data || []).map(item => ({
      id: item.id,
      personId: item.person_id,
      title: item.title,
      trainingType: item.training_type,
      startTime: item.start_time,
      endTime: item.end_time,
      duration: item.duration,
      avgHeartRate: item.avg_heart_rate,
      maxHeartRate: item.max_heart_rate,
      minHeartRate: item.min_heart_rate,
      calories: item.calories,
      heartRateData: Array.isArray(item.heart_rate_data) ? item.heart_rate_data : [],
      notes: item.notes,
      synced: item.synced,
      createdAt: item.created_at,
      updatedAt: item.updated_at,
    }))
  },

  getSession: async (id) => {
    const { data, error } = await supabase
      .from('training_sessions')
      .select('*')
      .eq('id', id)
      .single()
    if (error) throw error
    
    // Transform snake_case to camelCase for frontend
    if (data) {
      // Parse and transform heart rate data
      let heartRateData = []
      if (data.heart_rate_data) {
        const rawData = typeof data.heart_rate_data === 'string' 
          ? JSON.parse(data.heart_rate_data) 
          : data.heart_rate_data
        
        if (Array.isArray(rawData)) {
          heartRateData = rawData.map(point => ({
            timestamp: point.timestamp,
            heartRate: point.heartRate || point.heart_rate,
            deviceId: point.deviceId || point.device_id,
          }))
        }
      }
      
      return {
        id: data.id,
        personId: data.person_id,
        title: data.title,
        trainingType: data.training_type,
        startTime: data.start_time,
        endTime: data.end_time,
        duration: data.duration,
        avgHeartRate: data.avg_heart_rate,
        maxHeartRate: data.max_heart_rate,
        minHeartRate: data.min_heart_rate,
        calories: data.calories,
        heartRateData: heartRateData,
        notes: data.notes,
        synced: data.synced,
        createdAt: data.created_at,
        updatedAt: data.updated_at,
      }
    }
    return data
  },

  getStats: async (params = {}) => {
    const { data: sessions, error } = await supabase
      .from('training_sessions')
      .select('*')
    
    if (error) throw error
    
    if (!sessions || sessions.length === 0) {
      return {
        totalSessions: 0,
        totalDuration: 0,
        avgHeartRate: 0,
        totalCalories: 0,
        trainingTypes: {}
      }
    }
    
    const totalSessions = sessions.length
    const totalDuration = sessions.reduce((sum, s) => sum + (s.duration || 0), 0)
    const avgHeartRate = Math.round(
      sessions.reduce((sum, s) => sum + (s.avg_heart_rate || 0), 0) / totalSessions
    )
    const totalCalories = sessions.reduce((sum, s) => sum + (s.calories || 0), 0)
    
    const trainingTypes = {}
    sessions.forEach(s => {
      const type = s.training_type || 'Unknown'
      trainingTypes[type] = (trainingTypes[type] || 0) + 1
    })
    
    return {
      totalSessions,
      totalDuration,
      avgHeartRate,
      totalCalories,
      trainingTypes
    }
  },

  deleteSession: async (id) => {
    const { error } = await supabase
      .from('training_sessions')
      .delete()
      .eq('id', id)
    if (error) throw error
    return { success: true }
  },
};

export const personService = {
  getPersons: async () => {
    const { data, error } = await supabase
      .from('persons')
      .select('*')
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  getPerson: async (id) => {
    const { data, error } = await supabase
      .from('persons')
      .select('*')
      .eq('id', id)
      .single()
    if (error) throw error
    return data
  },
};

export default api;

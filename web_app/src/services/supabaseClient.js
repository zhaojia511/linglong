import { createClient } from '@supabase/supabase-js'
// Use Node helper for tests, Vite helper otherwise
const isTest = typeof process !== 'undefined' && process.env && process.env.NODE_ENV === 'test';
const { getEnvVar } = isTest
  ? require('./envHelperNode.js')
  : require('./envHelperVite.js');

const supabaseUrl = getEnvVar('VITE_SUPABASE_URL')
const supabaseAnonKey = getEnvVar('VITE_SUPABASE_ANON_KEY')

if (!supabaseUrl || !supabaseAnonKey) {
  // Fail fast so local dev notices missing env
  throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// envHelper.js
// Helper to get environment variables in both Vite (import.meta.env) and Jest/node (process.env)
export function getEnvVar(key, fallback = undefined) {
  // If running in Vite/browser, use import.meta.env (guarded by __VITE__ flag)
  if (typeof __VITE__ !== 'undefined' && __VITE__ && typeof import.meta !== 'undefined' && import.meta.env && key in import.meta.env) {
    return import.meta.env[key]
  }
  // Otherwise, use process.env (Node/Jest)
  if (typeof process !== 'undefined' && process.env && key in process.env) {
    return process.env[key]
  }
  return fallback
}

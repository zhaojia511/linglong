// Vite/browser environment variable helper
export function getEnvVar(key, fallback = undefined) {
  if (typeof import.meta !== 'undefined' && import.meta.env && key in import.meta.env) {
    return import.meta.env[key]
  }
  return fallback
}

// Node/Jest environment variable helper
export function getEnvVar(key, fallback = undefined) {
  if (typeof process !== 'undefined' && process.env && key in process.env) {
    return process.env[key]
  }
  return fallback
}

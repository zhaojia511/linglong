export const ZONE_DEFINITIONS = [
  { zone: 1, name: 'Recovery',          minPct: 0.50, maxPct: 0.60, color: '#6c757d' },
  { zone: 2, name: 'Aerobic Base',      minPct: 0.60, maxPct: 0.70, color: '#28a745' },
  { zone: 3, name: 'Aerobic Endurance', minPct: 0.70, maxPct: 0.80, color: '#17a2b8' },
  { zone: 4, name: 'Threshold',         minPct: 0.80, maxPct: 0.90, color: '#ffc107' },
  { zone: 5, name: 'Anaerobic',         minPct: 0.90, maxPct: 1.00, color: '#dc3545' },
]

/**
 * Calculate HR zone boundaries for a given max heart rate.
 * @param {number} maxHR - Maximum heart rate in bpm
 * @returns {Array} Zone definitions with absolute bpm ranges
 */
export function getZoneBoundaries(maxHR) {
  if (!maxHR || maxHR < 100) return []
  return ZONE_DEFINITIONS.map(z => ({
    ...z,
    minBpm: Math.round(z.minPct * maxHR),
    maxBpm: Math.round(z.maxPct * maxHR),
    label: `Zone ${z.zone}: ${z.name}`,
    range: `${Math.round(z.minPct * maxHR)}–${Math.round(z.maxPct * maxHR)} bpm`,
  }))
}

/**
 * Determine which zone a given heart rate falls in.
 * @param {number} hr - Heart rate in bpm
 * @param {number} maxHR - Maximum heart rate in bpm
 * @returns {Object|null} Zone definition or null if outside all zones
 */
export function getZoneForHR(hr, maxHR) {
  if (!hr || !maxHR) return null
  const pct = hr / maxHR
  return ZONE_DEFINITIONS.find(z => pct >= z.minPct && pct < z.maxPct) || ZONE_DEFINITIONS[4]
}

/**
 * Calculate time spent in each zone from an array of HR data points.
 * @param {Array} hrData - Array of { heartRate: number } objects
 * @param {number} maxHR - Maximum heart rate in bpm
 * @returns {Array} Zone breakdown with time counts (each point = 1 unit of time)
 */
export function calcZoneDistribution(hrData, maxHR) {
  if (!hrData?.length || !maxHR) return []

  const counts = Object.fromEntries(ZONE_DEFINITIONS.map(z => [z.zone, 0]))
  hrData.forEach(point => {
    const zone = getZoneForHR(point.heartRate, maxHR)
    if (zone) counts[zone.zone]++
  })

  const total = hrData.length
  return ZONE_DEFINITIONS.map(z => ({
    ...z,
    count: counts[z.zone],
    percentage: total > 0 ? Math.round((counts[z.zone] / total) * 100) : 0,
  }))
}

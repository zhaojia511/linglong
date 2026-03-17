/**
 * Training load, recovery, and advanced analytics utilities.
 *
 * TRIMP (Training Impulse) — Bannister model:
 *   TRIMP = duration_min × avgHR_ratio × e^(b × avgHR_ratio)
 *   where avgHR_ratio = (avgHR - restHR) / (maxHR - restHR)
 *   b = 1.92 for male, 1.67 for female
 *
 * Recovery time estimate based on TRIMP load.
 * VO2 max estimation using Uth-Sørensen-Overgaard-Pedersen formula.
 */

/**
 * Calculate TRIMP for a single session.
 * @param {object} p - { avgHR, durationSeconds, maxHR, restingHR, gender }
 * @returns {number} TRIMP score
 */
export function calcTRIMP({ avgHR, durationSeconds, maxHR, restingHR, gender }) {
  if (!avgHR || !maxHR || !restingHR || maxHR <= restingHR) return 0
  const durationMin = durationSeconds / 60
  const hrRatio = (avgHR - restingHR) / (maxHR - restingHR)
  if (hrRatio <= 0 || hrRatio > 1) return 0
  const b = gender === 'female' ? 1.67 : 1.92
  return durationMin * hrRatio * Math.exp(b * hrRatio)
}

/**
 * Estimate recovery time in hours based on TRIMP.
 * Rough guideline:
 *   TRIMP < 50  → light session → ~12h recovery
 *   TRIMP < 100 → moderate → ~24h
 *   TRIMP < 150 → hard → ~36h
 *   TRIMP < 200 → very hard → ~48h
 *   TRIMP >= 200 → extreme → ~72h
 */
export function estimateRecoveryHours(trimp) {
  if (trimp < 50) return 12
  if (trimp < 100) return 24
  if (trimp < 150) return 36
  if (trimp < 200) return 48
  return 72
}

/**
 * Classify session intensity from TRIMP.
 */
export function sessionIntensity(trimp) {
  if (trimp < 50) return 'Light'
  if (trimp < 100) return 'Moderate'
  if (trimp < 150) return 'Hard'
  if (trimp < 200) return 'Very Hard'
  return 'Extreme'
}

/**
 * Estimate VO2 max using Uth-Sørensen formula:
 *   VO2max = 15 × (maxHR / restingHR)
 * Requires resting HR and max HR.
 * @returns {number} VO2 max in ml/kg/min
 */
export function estimateVO2Max(maxHR, restingHR) {
  if (!maxHR || !restingHR || restingHR <= 0) return null
  return 15 * (maxHR / restingHR)
}

/**
 * Classify VO2 max fitness level by age and gender.
 * Based on ACSM norms.
 */
export function vo2MaxCategory(vo2max, age, gender) {
  if (!vo2max) return null

  // Simplified thresholds (male / female) for common age groups
  const norms = {
    male: [
      { max: 29, poor: 35, fair: 42, good: 50, excellent: 56 },
      { max: 39, poor: 33, fair: 40, good: 47, excellent: 53 },
      { max: 49, poor: 31, fair: 37, good: 44, excellent: 50 },
      { max: 59, poor: 29, fair: 35, good: 41, excellent: 47 },
      { max: 99, poor: 26, fair: 31, good: 37, excellent: 43 },
    ],
    female: [
      { max: 29, poor: 28, fair: 35, good: 42, excellent: 48 },
      { max: 39, poor: 26, fair: 33, good: 39, excellent: 45 },
      { max: 49, poor: 24, fair: 30, good: 36, excellent: 42 },
      { max: 59, poor: 22, fair: 28, good: 33, excellent: 39 },
      { max: 99, poor: 20, fair: 25, good: 30, excellent: 36 },
    ],
  }

  const g = gender === 'female' ? 'female' : 'male'
  const row = norms[g].find((r) => age <= r.max) ?? norms[g][norms[g].length - 1]

  if (vo2max < row.poor) return 'Poor'
  if (vo2max < row.fair) return 'Fair'
  if (vo2max < row.good) return 'Good'
  if (vo2max < row.excellent) return 'Excellent'
  return 'Superior'
}

/**
 * Calculate cumulative training load (ATL, CTL, TSB) over a list of sessions.
 * Uses standard 7-day ATL and 42-day CTL exponential moving averages.
 *
 * @param {Array} sessions - sorted ascending by date, each with { date: Date, trimp: number }
 * @returns {Array} same sessions with added { atl, ctl, tsb } fields
 *   ATL = Acute Training Load (fatigue), 7-day EMA
 *   CTL = Chronic Training Load (fitness), 42-day EMA
 *   TSB = Training Stress Balance = CTL - ATL (form)
 */
export function calcTrainingBalance(sessions) {
  const K_ATL = 1 - Math.exp(-1 / 7)
  const K_CTL = 1 - Math.exp(-1 / 42)

  let atl = 0
  let ctl = 0

  return sessions.map((s) => {
    atl = atl + K_ATL * (s.trimp - atl)
    ctl = ctl + K_CTL * (s.trimp - ctl)
    const tsb = ctl - atl
    return { ...s, atl: Math.round(atl * 10) / 10, ctl: Math.round(ctl * 10) / 10, tsb: Math.round(tsb * 10) / 10 }
  })
}

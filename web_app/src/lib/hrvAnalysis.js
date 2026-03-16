/**
 * HRV (Heart Rate Variability) analysis from RR intervals (in milliseconds).
 */

/** Filter out physiologically impossible RR intervals and artifacts. */
function filterArtifacts(rrIntervals) {
  // Step 1: Remove out-of-range (300ms=200bpm to 2000ms=30bpm)
  const rangeFiltered = rrIntervals.filter((rr) => rr >= 300 && rr <= 2000);
  if (rangeFiltered.length < 3) return rangeFiltered;

  // Step 2: Remove intervals deviating >50% from local median (window=5)
  const result = [];
  for (let i = 0; i < rangeFiltered.length; i++) {
    const start = Math.max(0, i - 2);
    const end = Math.min(rangeFiltered.length, i + 3);
    const window = rangeFiltered.slice(start, end).sort((a, b) => a - b);
    const median = window[Math.floor(window.length / 2)];
    const deviation = Math.abs(rangeFiltered[i] - median) / median;
    if (deviation <= 0.5) {
      result.push(rangeFiltered[i]);
    }
  }
  return result;
}

/** SDNN — Standard deviation of NN intervals. Overall HRV indicator. */
export function sdnn(rrIntervals) {
  const filtered = filterArtifacts(rrIntervals);
  if (filtered.length < 2) return 0;
  const mean = filtered.reduce((a, b) => a + b, 0) / filtered.length;
  const variance =
    filtered.reduce((sum, rr) => sum + (rr - mean) ** 2, 0) /
    (filtered.length - 1);
  return Math.sqrt(variance);
}

/** RMSSD — Root mean square of successive differences. Vagal/parasympathetic metric. */
export function rmssd(rrIntervals) {
  const filtered = filterArtifacts(rrIntervals);
  if (filtered.length < 2) return 0;
  let sumSqDiff = 0;
  for (let i = 1; i < filtered.length; i++) {
    sumSqDiff += (filtered[i] - filtered[i - 1]) ** 2;
  }
  return Math.sqrt(sumSqDiff / (filtered.length - 1));
}

/** pNN50 — Percentage of successive intervals differing by >50ms. */
export function pnn50(rrIntervals) {
  const filtered = filterArtifacts(rrIntervals);
  if (filtered.length < 2) return 0;
  let count = 0;
  for (let i = 1; i < filtered.length; i++) {
    if (Math.abs(filtered[i] - filtered[i - 1]) > 50) count++;
  }
  return (count / (filtered.length - 1)) * 100;
}

/** Mean RR interval in ms. */
export function meanRR(rrIntervals) {
  const filtered = filterArtifacts(rrIntervals);
  if (filtered.length === 0) return 0;
  return filtered.reduce((a, b) => a + b, 0) / filtered.length;
}

/** Stress level estimate based on RMSSD. */
export function stressLevel(rmssdValue) {
  if (rmssdValue >= 50) return 'Low';
  if (rmssdValue >= 30) return 'Moderate';
  if (rmssdValue >= 15) return 'High';
  return 'Very High';
}

/** Compute all HRV metrics at once. */
export function analyzeHRV(rrIntervals) {
  const rmssdVal = rmssd(rrIntervals);
  return {
    sdnn: sdnn(rrIntervals),
    rmssd: rmssdVal,
    pnn50: pnn50(rrIntervals),
    meanRR: meanRR(rrIntervals),
    stressLevel: stressLevel(rmssdVal),
    validIntervals: filterArtifacts(rrIntervals).length,
    totalIntervals: rrIntervals.length,
  };
}

/**
 * Heart rate data processing: trimming, noise filtering, stats recalculation.
 * HR data points: { timestamp: string (ISO), heartRate: number, deviceId?: string }
 */

/**
 * Trim warmup and cooldown from HR data.
 * @param {Array} data - HR data points with timestamp and heartRate
 * @param {number} warmupSeconds - Seconds to trim from start
 * @param {number} cooldownSeconds - Seconds to trim from end
 */
export function trimHRData(data, warmupSeconds = 0, cooldownSeconds = 0) {
  if (!data.length) return data;

  const sorted = [...data].sort(
    (a, b) => new Date(a.timestamp) - new Date(b.timestamp)
  );
  const start = new Date(sorted[0].timestamp).getTime() + warmupSeconds * 1000;
  const end =
    new Date(sorted[sorted.length - 1].timestamp).getTime() -
    cooldownSeconds * 1000;

  if (start >= end) return data;

  return sorted.filter((d) => {
    const t = new Date(d.timestamp).getTime();
    return t >= start && t <= end;
  });
}

/**
 * Auto-detect warmup: find when HR first stabilizes (±10% of rolling avg for 30s).
 * Returns seconds to trim.
 */
export function detectWarmup(data, windowSize = 30) {
  if (data.length < windowSize) return 0;

  const sorted = [...data].sort(
    (a, b) => new Date(a.timestamp) - new Date(b.timestamp)
  );

  for (let i = windowSize; i < sorted.length; i++) {
    const window = sorted.slice(i - windowSize, i);
    const avgHr =
      window.reduce((s, d) => s + d.heartRate, 0) / windowSize;

    const stable = window.every(
      (d) => Math.abs(d.heartRate - avgHr) / avgHr <= 0.1
    );

    if (stable) {
      return Math.round(
        (new Date(sorted[i - windowSize].timestamp) -
          new Date(sorted[0].timestamp)) /
          1000
      );
    }
  }
  return 0;
}

/**
 * Auto-detect cooldown: find where HR starts consistently dropping at end.
 * Returns seconds to trim from end.
 */
export function detectCooldown(data, windowSize = 30) {
  if (data.length < windowSize) return 0;

  const sorted = [...data].sort(
    (a, b) => new Date(a.timestamp) - new Date(b.timestamp)
  );

  for (let i = sorted.length - windowSize; i > Math.floor(sorted.length / 2); i--) {
    const window = sorted.slice(i, i + windowSize);
    const hrs = window.map((d) => d.heartRate);

    let drops = 0;
    for (let j = 1; j < hrs.length; j++) {
      if (hrs[j] <= hrs[j - 1]) drops++;
    }

    if (drops / (hrs.length - 1) < 0.6) {
      return Math.round(
        (new Date(sorted[sorted.length - 1].timestamp) -
          new Date(sorted[i + windowSize].timestamp)) /
          1000
      );
    }
  }
  return 0;
}

/**
 * Remove noise spikes: replace values deviating >25% from local median.
 */
export function filterNoise(data, windowSize = 5, threshold = 0.25) {
  if (data.length < windowSize) return data;

  const sorted = [...data].sort(
    (a, b) => new Date(a.timestamp) - new Date(b.timestamp)
  );

  return sorted.map((point, i) => {
    const start = Math.max(0, i - Math.floor(windowSize / 2));
    const end = Math.min(sorted.length, i + Math.floor(windowSize / 2) + 1);
    const window = sorted
      .slice(start, end)
      .map((d) => d.heartRate)
      .sort((a, b) => a - b);
    const median = window[Math.floor(window.length / 2)];
    const deviation = Math.abs(point.heartRate - median) / median;

    if (deviation > threshold) {
      return { ...point, heartRate: median };
    }
    return point;
  });
}

/**
 * Recalculate session stats from (possibly trimmed/filtered) HR data.
 */
export function calcStats(data) {
  if (!data.length) return { avgHR: 0, maxHR: 0, minHR: 0, durationSeconds: 0 };

  const hrs = data.map((d) => d.heartRate);
  const sorted = [...data].sort(
    (a, b) => new Date(a.timestamp) - new Date(b.timestamp)
  );

  return {
    avgHR: Math.round(hrs.reduce((a, b) => a + b, 0) / hrs.length),
    maxHR: Math.max(...hrs),
    minHR: Math.min(...hrs),
    durationSeconds: Math.round(
      (new Date(sorted[sorted.length - 1].timestamp) -
        new Date(sorted[0].timestamp)) /
        1000
    ),
  };
}

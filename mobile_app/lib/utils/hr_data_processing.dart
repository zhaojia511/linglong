import '../models/training_session.dart';

/// Heart rate data processing utilities:
/// trimming, noise filtering, and signal cleanup.
class HrDataProcessing {
  /// Trim warmup and cooldown from HR data.
  /// [warmupSeconds] — seconds to trim from start.
  /// [cooldownSeconds] — seconds to trim from end.
  static List<HeartRateData> trim(
    List<HeartRateData> data, {
    int warmupSeconds = 0,
    int cooldownSeconds = 0,
  }) {
    if (data.isEmpty) return data;

    final sorted = List<HeartRateData>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final sessionStart = sorted.first.timestamp;
    final sessionEnd = sorted.last.timestamp;

    final trimStart = sessionStart.add(Duration(seconds: warmupSeconds));
    final trimEnd = sessionEnd.subtract(Duration(seconds: cooldownSeconds));

    if (trimStart.isAfter(trimEnd)) return data; // trim would remove everything

    return sorted
        .where((d) =>
            !d.timestamp.isBefore(trimStart) && !d.timestamp.isAfter(trimEnd))
        .toList();
  }

  /// Auto-detect warmup period: find when HR first stabilizes
  /// (stays within ±10% of rolling average for 30+ seconds).
  /// Returns the number of seconds to trim.
  static int detectWarmup(List<HeartRateData> data, {int windowSize = 30}) {
    if (data.length < windowSize) return 0;

    final sorted = List<HeartRateData>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Compute rolling average HR
    for (int i = windowSize; i < sorted.length; i++) {
      final window = sorted.sublist(i - windowSize, i);
      final avgHr =
          window.map((d) => d.heartRate).reduce((a, b) => a + b) / windowSize;

      // Check if all values in window are within ±10% of average
      final stable = window.every(
        (d) => (d.heartRate - avgHr).abs() / avgHr <= 0.10,
      );

      if (stable) {
        return sorted[i - windowSize]
            .timestamp
            .difference(sorted.first.timestamp)
            .inSeconds;
      }
    }

    return 0; // No clear warmup detected
  }

  /// Auto-detect cooldown: find where HR starts consistently dropping
  /// in the last portion of the session.
  /// Returns the number of seconds to trim from the end.
  static int detectCooldown(List<HeartRateData> data, {int windowSize = 30}) {
    if (data.length < windowSize) return 0;

    final sorted = List<HeartRateData>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Look from the end backwards for where HR starts dropping
    for (int i = sorted.length - windowSize; i > sorted.length ~/ 2; i--) {
      final window = sorted.sublist(i, i + windowSize);
      final hrs = window.map((d) => d.heartRate).toList();

      // Check if HR is consistently decreasing (>60% of pairs are dropping)
      int drops = 0;
      for (int j = 1; j < hrs.length; j++) {
        if (hrs[j] <= hrs[j - 1]) drops++;
      }

      if (drops / (hrs.length - 1) < 0.6) {
        // This is where HR was still stable — cooldown starts after this
        return sorted.last.timestamp
            .difference(sorted[i + windowSize].timestamp)
            .inSeconds;
      }
    }

    return 0;
  }

  /// Remove noise spikes from HR data.
  /// Replaces values that deviate >25% from local median with the median.
  static List<HeartRateData> filterNoise(
    List<HeartRateData> data, {
    int windowSize = 5,
    double threshold = 0.25,
  }) {
    if (data.length < windowSize) return data;

    final sorted = List<HeartRateData>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final result = <HeartRateData>[];

    for (int i = 0; i < sorted.length; i++) {
      final start = (i - windowSize ~/ 2).clamp(0, sorted.length - 1);
      final end = (i + windowSize ~/ 2 + 1).clamp(0, sorted.length);
      final window =
          sorted.sublist(start, end).map((d) => d.heartRate).toList()..sort();
      final median = window[window.length ~/ 2];
      final deviation = (sorted[i].heartRate - median).abs() / median;

      if (deviation > threshold) {
        // Replace with median
        result.add(HeartRateData(
          timestamp: sorted[i].timestamp,
          heartRate: median,
          deviceId: sorted[i].deviceId,
        ));
      } else {
        result.add(sorted[i]);
      }
    }

    return result;
  }

  /// Recalculate session stats from (possibly trimmed/filtered) HR data.
  static SessionStats calcStats(List<HeartRateData> data) {
    if (data.isEmpty) {
      return const SessionStats(
          avgHR: 0, maxHR: 0, minHR: 0, durationSeconds: 0);
    }

    final hrs = data.map((d) => d.heartRate).toList();
    final sorted = List<HeartRateData>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return SessionStats(
      avgHR: hrs.reduce((a, b) => a + b) ~/ hrs.length,
      maxHR: hrs.reduce((a, b) => a > b ? a : b),
      minHR: hrs.reduce((a, b) => a < b ? a : b),
      durationSeconds:
          sorted.last.timestamp.difference(sorted.first.timestamp).inSeconds,
    );
  }
}

class SessionStats {
  final int avgHR;
  final int maxHR;
  final int minHR;
  final int durationSeconds;

  const SessionStats({
    required this.avgHR,
    required this.maxHR,
    required this.minHR,
    required this.durationSeconds,
  });
}

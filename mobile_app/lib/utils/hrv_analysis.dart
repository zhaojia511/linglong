import 'dart:math';

/// HRV (Heart Rate Variability) analysis from RR intervals.
/// All RR intervals are expected in milliseconds.
class HrvAnalysis {
  /// SDNN — Standard deviation of all NN (RR) intervals.
  /// Reflects overall HRV. Higher = more variability = better recovery.
  static double sdnn(List<int> rrIntervals) {
    if (rrIntervals.length < 2) return 0;
    final filtered = _filterArtifacts(rrIntervals);
    if (filtered.length < 2) return 0;

    final mean = filtered.reduce((a, b) => a + b) / filtered.length;
    final variance =
        filtered.map((rr) => pow(rr - mean, 2)).reduce((a, b) => a + b) /
            (filtered.length - 1);
    return sqrt(variance);
  }

  /// RMSSD — Root mean square of successive differences.
  /// Primary parasympathetic (vagal) HRV metric.
  static double rmssd(List<int> rrIntervals) {
    if (rrIntervals.length < 2) return 0;
    final filtered = _filterArtifacts(rrIntervals);
    if (filtered.length < 2) return 0;

    double sumSquaredDiffs = 0;
    for (int i = 1; i < filtered.length; i++) {
      final diff = filtered[i] - filtered[i - 1];
      sumSquaredDiffs += diff * diff;
    }
    return sqrt(sumSquaredDiffs / (filtered.length - 1));
  }

  /// pNN50 — Percentage of successive RR intervals differing by >50ms.
  /// Another parasympathetic metric. Higher = more relaxed.
  static double pnn50(List<int> rrIntervals) {
    if (rrIntervals.length < 2) return 0;
    final filtered = _filterArtifacts(rrIntervals);
    if (filtered.length < 2) return 0;

    int count = 0;
    for (int i = 1; i < filtered.length; i++) {
      if ((filtered[i] - filtered[i - 1]).abs() > 50) {
        count++;
      }
    }
    return (count / (filtered.length - 1)) * 100;
  }

  /// Mean RR interval in ms.
  static double meanRR(List<int> rrIntervals) {
    if (rrIntervals.isEmpty) return 0;
    final filtered = _filterArtifacts(rrIntervals);
    if (filtered.isEmpty) return 0;
    return filtered.reduce((a, b) => a + b) / filtered.length;
  }

  /// Compute all HRV metrics at once.
  static HrvResult analyze(List<int> rrIntervals) {
    final filtered = _filterArtifacts(rrIntervals);
    final rmssdVal = rmssd(filtered);
    final sdnnVal = sdnn(filtered);
    // SD1 = short-term variability (parasympathetic). SD2 = long-term.
    final sd1 = rmssdVal / sqrt(2);
    final sd2Val = sdnnVal * sdnnVal * 2 - sd1 * sd1;
    final sd2 = sd2Val > 0 ? sqrt(sd2Val) : 0.0;
    return HrvResult(
      sdnn: sdnnVal,
      rmssd: rmssdVal,
      pnn50: pnn50(filtered),
      meanRR: meanRR(filtered),
      sd1: sd1,
      sd2: sd2,
      validIntervals: filtered.length,
      totalIntervals: rrIntervals.length,
      filteredRR: filtered,
    );
  }

  /// Rolling RMSSD over time using a sliding window of [windowSize] intervals.
  /// Returns a list of (intervalIndex, rmssd) pairs.
  static List<({int index, double rmssd})> rollingRmssd(
      List<int> rrIntervals, {int windowSize = 30}) {
    final filtered = _filterArtifacts(rrIntervals);
    if (filtered.length < windowSize) return [];
    final result = <({int index, double rmssd})>[];
    for (int i = windowSize; i <= filtered.length; i++) {
      final window = filtered.sublist(i - windowSize, i);
      result.add((index: i, rmssd: rmssd(window)));
    }
    return result;
  }

  /// Filter out physiologically impossible RR intervals.
  /// Valid range: 300ms (200bpm) to 2000ms (30bpm).
  /// Also removes intervals that differ >50% from the running median (artifacts).
  static List<int> _filterArtifacts(List<int> rrIntervals) {
    // Step 1: Remove out-of-range values
    final rangeFiltered =
        rrIntervals.where((rr) => rr >= 300 && rr <= 2000).toList();
    if (rangeFiltered.length < 3) return rangeFiltered;

    // Step 2: Remove intervals that deviate >50% from local median (window=5)
    final result = <int>[];
    for (int i = 0; i < rangeFiltered.length; i++) {
      final windowStart = max(0, i - 2);
      final windowEnd = min(rangeFiltered.length, i + 3);
      final window = rangeFiltered.sublist(windowStart, windowEnd)..sort();
      final median = window[window.length ~/ 2];
      final deviation = (rangeFiltered[i] - median).abs() / median;
      if (deviation <= 0.5) {
        result.add(rangeFiltered[i]);
      }
    }
    return result;
  }
}

class HrvResult {
  final double sdnn;
  final double rmssd;
  final double pnn50;
  final double meanRR;
  final double sd1;  // Poincaré short-term variability (parasympathetic)
  final double sd2;  // Poincaré long-term variability
  final int validIntervals;
  final int totalIntervals;
  final List<int> filteredRR; // cleaned RR intervals for plotting

  const HrvResult({
    required this.sdnn,
    required this.rmssd,
    required this.pnn50,
    required this.meanRR,
    required this.sd1,
    required this.sd2,
    required this.validIntervals,
    required this.totalIntervals,
    required this.filteredRR,
  });

  /// Estimated stress level based on RMSSD.
  /// Low RMSSD = high stress, High RMSSD = low stress.
  String get stressLevel {
    if (rmssd >= 50) return 'Low';
    if (rmssd >= 30) return 'Moderate';
    if (rmssd >= 15) return 'High';
    return 'Very High';
  }

  Map<String, dynamic> toJson() => {
        'sdnn': sdnn.toStringAsFixed(1),
        'rmssd': rmssd.toStringAsFixed(1),
        'pnn50': pnn50.toStringAsFixed(1),
        'meanRR': meanRR.toStringAsFixed(1),
        'sd1': sd1.toStringAsFixed(1),
        'sd2': sd2.toStringAsFixed(1),
        'stressLevel': stressLevel,
        'validIntervals': validIntervals,
        'totalIntervals': totalIntervals,
      };
}

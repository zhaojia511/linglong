import 'dart:math';

/// Training load, recovery, and advanced analytics.
///
/// TRIMP (Training Impulse) — Bannister model:
///   TRIMP = duration_min × hrRatio × e^(b × hrRatio)
///   hrRatio = (avgHR - restHR) / (maxHR - restHR)
///   b = 1.92 male, 1.67 female
class TrainingLoad {
  /// Calculate TRIMP for a session.
  static double trimp({
    required int avgHR,
    required int durationSeconds,
    required int maxHR,
    required int restingHR,
    required String gender,
  }) {
    if (maxHR <= restingHR) return 0;
    final durationMin = durationSeconds / 60.0;
    final hrRatio = (avgHR - restingHR) / (maxHR - restingHR);
    if (hrRatio <= 0 || hrRatio > 1) return 0;
    final b = gender.toLowerCase() == 'female' ? 1.67 : 1.92;
    return durationMin * hrRatio * exp(b * hrRatio);
  }

  /// Estimate recovery time in hours from TRIMP score.
  static int recoveryHours(double trimp) {
    if (trimp < 50) return 12;
    if (trimp < 100) return 24;
    if (trimp < 150) return 36;
    if (trimp < 200) return 48;
    return 72;
  }

  /// Classify session intensity from TRIMP.
  static String intensity(double trimp) {
    if (trimp < 50) return 'Light';
    if (trimp < 100) return 'Moderate';
    if (trimp < 150) return 'Hard';
    if (trimp < 200) return 'Very Hard';
    return 'Extreme';
  }

  /// Estimate VO2 max using Uth-Sørensen formula:
  ///   VO2max = 15 × (maxHR / restHR)
  static double? estimateVO2Max(int? maxHR, int? restingHR) {
    if (maxHR == null || restingHR == null || restingHR <= 0) return null;
    return 15.0 * maxHR / restingHR;
  }

  /// Classify VO2 max by age and gender using ACSM norms.
  static String? vo2MaxCategory(double? vo2max, int age, String gender) {
    if (vo2max == null) return null;

    final isFemale = gender.toLowerCase() == 'female';
    late int poor, fair, good, excellent;

    if (!isFemale) {
      if (age <= 29) { poor = 35; fair = 42; good = 50; excellent = 56; }
      else if (age <= 39) { poor = 33; fair = 40; good = 47; excellent = 53; }
      else if (age <= 49) { poor = 31; fair = 37; good = 44; excellent = 50; }
      else if (age <= 59) { poor = 29; fair = 35; good = 41; excellent = 47; }
      else { poor = 26; fair = 31; good = 37; excellent = 43; }
    } else {
      if (age <= 29) { poor = 28; fair = 35; good = 42; excellent = 48; }
      else if (age <= 39) { poor = 26; fair = 33; good = 39; excellent = 45; }
      else if (age <= 49) { poor = 24; fair = 30; good = 36; excellent = 42; }
      else if (age <= 59) { poor = 22; fair = 28; good = 33; excellent = 39; }
      else { poor = 20; fair = 25; good = 30; excellent = 36; }
    }

    if (vo2max < poor) return 'Poor';
    if (vo2max < fair) return 'Fair';
    if (vo2max < good) return 'Good';
    if (vo2max < excellent) return 'Excellent';
    return 'Superior';
  }
}

/// Result of a single session's training load analysis.
class TrainingLoadResult {
  final double trimp;
  final String intensity;
  final int recoveryHours;
  final double? vo2max;
  final String? vo2maxCategory;

  const TrainingLoadResult({
    required this.trimp,
    required this.intensity,
    required this.recoveryHours,
    this.vo2max,
    this.vo2maxCategory,
  });
}

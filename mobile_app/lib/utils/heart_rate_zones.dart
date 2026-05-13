
import '../models/person.dart';

/// Utility class for calculating personalized heart rate zones
class HeartRateZones {
  /// Heart rate zone definitions
  static const zoneNames = ['Recovery', 'Aerobic', 'Tempo', 'Threshold', 'Anaerobic'];
  static const zoneColors = [
    0xFF4FC3F7,
    0xFF66BB6A,
    0xFFFDD835,
    0xFFFF7043,
    0xFFE53935,
  ];

  /// Default resting heart rate when no measurement available
  static const int defaultRestingHeartRate = 60;

  /// Get effective max heart rate for a person (user value or calculated)
  static int getEffectiveMaxHeartRate(Person person) {
    return person.maxHeartRate ?? calculateMaxHeartRate(person.age);
  }

  /// Get effective resting heart rate for a person (user value or default)
  static int getEffectiveRestingHeartRate(Person person) {
    return person.restingHeartRate ?? defaultRestingHeartRate;
  }

  /// Calculate maximum heart rate using the standard formula (220 - age)
  static int calculateMaxHeartRate(int age) {
    return 220 - age;
  }

  /// Calculate heart rate reserve (HRR) = Max HR - Resting HR
  static int calculateHeartRateReserve(int maxHeartRate, int restingHeartRate) {
    return maxHeartRate - restingHeartRate;
  }

  /// Get the heart rate range (min, max) for a specific zone
  /// Uses the Karvonen method: Resting HR + (HRR * percentage)
  static (int, int) getZoneRange(int zoneIndex, int maxHeartRate, int restingHeartRate) {
    final hrr = calculateHeartRateReserve(maxHeartRate, restingHeartRate);

    switch (zoneIndex) {
      case 0: // Recovery: <65% of HRR
        return (0, (restingHeartRate + hrr * 0.65).round());
      case 1: // Aerobic: 65-75% of HRR
        return ((restingHeartRate + hrr * 0.65).round(), (restingHeartRate + hrr * 0.75).round());
      case 2: // Tempo: 75-85% of HRR
        return ((restingHeartRate + hrr * 0.75).round(), (restingHeartRate + hrr * 0.85).round());
      case 3: // Threshold: 85-95% of HRR
        return ((restingHeartRate + hrr * 0.85).round(), (restingHeartRate + hrr * 0.95).round());
      case 4: // Anaerobic: >95% of HRR
        return ((restingHeartRate + hrr * 0.95).round(), maxHeartRate);
      default:
        return (0, maxHeartRate);
    }
  }

  /// Get the zone index for a given heart rate
  static int getZoneIndex(int heartRate, int maxHeartRate, int restingHeartRate) {
    final hrr = calculateHeartRateReserve(maxHeartRate, restingHeartRate);
    final percentage = (heartRate - restingHeartRate) / hrr;

    if (percentage < 0.65) return 0;
    if (percentage < 0.75) return 1;
    if (percentage < 0.85) return 2;
    if (percentage < 0.95) return 3;
    return 4;
  }

  /// Get zone label with percentage range
  static String getZoneLabel(int zoneIndex, int maxHeartRate, int restingHeartRate) {
    final (minHr, maxHr) = getZoneRange(zoneIndex, maxHeartRate, restingHeartRate);
    return '${zoneNames[zoneIndex]} ($minHr-$maxHr)';
  }

  /// Get zone range as a string for display
  static String getZoneRangeString(int zoneIndex, int maxHeartRate, int restingHeartRate) {
    final (minHr, maxHr) = getZoneRange(zoneIndex, maxHeartRate, restingHeartRate);
    if (zoneIndex == 0) {
      return '<$maxHr';
    } else if (zoneIndex == 4) {
      return '≥$minHr';
    }
    return '$minHr-$maxHr';
  }

  // --- Person-based convenience methods ---

  static (int, int) getZoneRangeForPerson(int zoneIndex, Person person) {
    return getZoneRange(
      zoneIndex,
      getEffectiveMaxHeartRate(person),
      getEffectiveRestingHeartRate(person),
    );
  }

  static int getZoneIndexForPerson(int heartRate, Person person) {
    return getZoneIndex(
      heartRate,
      getEffectiveMaxHeartRate(person),
      getEffectiveRestingHeartRate(person),
    );
  }

  static String getZoneLabelForPerson(int zoneIndex, Person person) {
    return getZoneLabel(
      zoneIndex,
      getEffectiveMaxHeartRate(person),
      getEffectiveRestingHeartRate(person),
    );
  }

  static String getZoneRangeStringForPerson(int zoneIndex, Person person) {
    return getZoneRangeString(
      zoneIndex,
      getEffectiveMaxHeartRate(person),
      getEffectiveRestingHeartRate(person),
    );
  }
}

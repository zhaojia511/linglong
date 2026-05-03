class DailyHrvSnapshot {
  final String id;
  final String personId;
  final DateTime timestamp;
  final double rmssd;
  final double sdnn;
  final double meanRR;
  final num? restingHR;
  final int sampleCount;

  DailyHrvSnapshot({
    required this.id,
    required this.personId,
    required this.timestamp,
    required this.rmssd,
    required this.sdnn,
    required this.meanRR,
    this.restingHR,
    required this.sampleCount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'personId': personId,
    'timestamp': timestamp.toIso8601String(),
    'rmssd': rmssd,
    'sdnn': sdnn,
    'meanRR': meanRR,
    'restingHR': restingHR,
    'sampleCount': sampleCount,
  };

  factory DailyHrvSnapshot.fromJson(Map<String, dynamic> json) =>
      DailyHrvSnapshot(
        id: json['id'],
        personId: json['personId'],
        timestamp: DateTime.parse(json['timestamp']),
        rmssd: (json['rmssd'] as num).toDouble(),
        sdnn: (json['sdnn'] as num).toDouble(),
        meanRR: (json['meanRR'] as num).toDouble(),
        restingHR: json['restingHR'] != null
            ? (json['restingHR'] as num).toDouble()
            : null,
        sampleCount: json['sampleCount'],
      );
}

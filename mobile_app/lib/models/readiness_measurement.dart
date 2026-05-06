class ReadinessMeasurement {
  final String id;
  final String personId;
  final String deviceId;
  final DateTime measuredAt;
  final int durationSec;
  final List<int> rrIntervals;
  final double rmssd;
  final double sdnn;
  final double pnn50;
  final double meanRR;
  final double sd1;
  final double sd2;
  final int? restingHR;
  final double qualityPct;
  final double? readinessPct;
  final int? feelingScore;
  final bool synced;

  const ReadinessMeasurement({
    required this.id,
    required this.personId,
    required this.deviceId,
    required this.measuredAt,
    required this.durationSec,
    required this.rrIntervals,
    required this.rmssd,
    required this.sdnn,
    required this.pnn50,
    required this.meanRR,
    required this.sd1,
    required this.sd2,
    this.restingHR,
    required this.qualityPct,
    this.readinessPct,
    this.feelingScore,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'deviceId': deviceId,
        'measuredAt': measuredAt.toIso8601String(),
        'durationSec': durationSec,
        'rrIntervals': rrIntervals,
        'rmssd': rmssd,
        'sdnn': sdnn,
        'pnn50': pnn50,
        'meanRR': meanRR,
        'sd1': sd1,
        'sd2': sd2,
        'restingHR': restingHR,
        'qualityPct': qualityPct,
        'readinessPct': readinessPct,
        'feelingScore': feelingScore,
        'synced': synced,
      };

  ReadinessMeasurement copyWith({bool? synced}) {
    return ReadinessMeasurement(
      id: id,
      personId: personId,
      deviceId: deviceId,
      measuredAt: measuredAt,
      durationSec: durationSec,
      rrIntervals: rrIntervals,
      rmssd: rmssd,
      sdnn: sdnn,
      pnn50: pnn50,
      meanRR: meanRR,
      sd1: sd1,
      sd2: sd2,
      restingHR: restingHR,
      qualityPct: qualityPct,
      readinessPct: readinessPct,
      feelingScore: feelingScore,
      synced: synced ?? this.synced,
    );
  }

  factory ReadinessMeasurement.fromJson(Map<String, dynamic> json) {
    return ReadinessMeasurement(
      id: json['id'] as String,
      personId: json['personId'] as String,
      deviceId: json['deviceId'] as String,
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      durationSec: json['durationSec'] as int? ?? 0,
      rrIntervals: (json['rrIntervals'] as List<dynamic>? ?? const [])
          .map((value) => (value as num).toInt())
          .toList(),
      rmssd: (json['rmssd'] as num).toDouble(),
      sdnn: (json['sdnn'] as num).toDouble(),
      pnn50: (json['pnn50'] as num?)?.toDouble() ?? 0,
      meanRR: (json['meanRR'] as num).toDouble(),
      sd1: (json['sd1'] as num?)?.toDouble() ?? 0,
      sd2: (json['sd2'] as num?)?.toDouble() ?? 0,
      restingHR: (json['restingHR'] as num?)?.toInt(),
      qualityPct: (json['qualityPct'] as num?)?.toDouble() ?? 0,
      readinessPct: (json['readinessPct'] as num?)?.toDouble(),
      feelingScore: (json['feelingScore'] as num?)?.toInt(),
      synced: json['synced'] as bool? ?? false,
    );
  }
}

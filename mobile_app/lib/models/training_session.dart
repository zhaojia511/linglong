import 'package:hive/hive.dart';

part 'training_session.g.dart';

@HiveType(typeId: 1)
class TrainingSession extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String personId;
  
  @HiveField(2)
  String title;
  
  @HiveField(3)
  DateTime startTime;
  
  @HiveField(4)
  DateTime? endTime;
  
  @HiveField(5)
  int duration; // seconds
  
  @HiveField(6)
  double? distance; // meters
  
  @HiveField(7)
  int? avgHeartRate;
  
  @HiveField(8)
  int? maxHeartRate;
  
  @HiveField(9)
  int? minHeartRate;
  
  @HiveField(10)
  double? calories;
  
  @HiveField(11)
  String trainingType; // running, cycling, gym, etc.
  
  @HiveField(12)
  List<HeartRateData> heartRateData;
  
  @HiveField(13)
  bool synced;
  
  @HiveField(14)
  String? notes;

  TrainingSession({
    required this.id,
    required this.personId,
    required this.title,
    required this.startTime,
    this.endTime,
    required this.duration,
    this.distance,
    this.avgHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.calories,
    required this.trainingType,
    required this.heartRateData,
    this.synced = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'personId': personId,
    'title': title,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'duration': duration,
    'distance': distance,
    'avgHeartRate': avgHeartRate,
    'maxHeartRate': maxHeartRate,
    'minHeartRate': minHeartRate,
    'calories': calories,
    'trainingType': trainingType,
    'heartRateData': heartRateData.map((e) => e.toJson()).toList(),
    'synced': synced,
    'notes': notes,
  };

  factory TrainingSession.fromJson(Map<String, dynamic> json) => TrainingSession(
    id: json['id'],
    personId: json['personId'],
    title: json['title'],
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    duration: json['duration'],
    distance: json['distance']?.toDouble(),
    avgHeartRate: json['avgHeartRate'],
    maxHeartRate: json['maxHeartRate'],
    minHeartRate: json['minHeartRate'],
    calories: json['calories']?.toDouble(),
    trainingType: json['trainingType'],
    heartRateData: (json['heartRateData'] as List)
        .map((e) => HeartRateData.fromJson(e))
        .toList(),
    synced: json['synced'] ?? false,
    notes: json['notes'],
  );
}

@HiveType(typeId: 2)
class HeartRateData extends HiveObject {
  @HiveField(0)
  DateTime timestamp;
  
  @HiveField(1)
  int heartRate;
  
  @HiveField(2)
  String? deviceId;

  HeartRateData({
    required this.timestamp,
    required this.heartRate,
    this.deviceId,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'heartRate': heartRate,
    'deviceId': deviceId,
  };

  factory HeartRateData.fromJson(Map<String, dynamic> json) => HeartRateData(
    timestamp: DateTime.parse(json['timestamp']),
    heartRate: json['heartRate'],
    deviceId: json['deviceId'],
  );
}

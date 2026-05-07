import 'package:flutter/foundation.dart';

// Data point for heart rate with timestamp
class HeartRateDataPoint {
  final DateTime timestamp;
  final double value;

  HeartRateDataPoint({
    required this.timestamp,
    required this.value,
  });
}

class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();
  SessionService._internal();

  final Map<String, List<HeartRateDataPoint>> _heartRateHistoryByDevice = {};
  final Map<String, List<int>> _zoneSecondsByDevice = {};
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  void startRecording() {
    _isRecording = true;
    _heartRateHistoryByDevice.clear();
    _zoneSecondsByDevice.clear();
    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    notifyListeners();
  }

  List<HeartRateDataPoint>? getHistoryForDevice(String deviceId) {
    return _heartRateHistoryByDevice[deviceId];
  }

  List<int>? getZoneSecondsForDevice(String deviceId) {
    return _zoneSecondsByDevice[deviceId];
  }

  void addHeartRateData(String deviceId, HeartRateDataPoint data) {
    _heartRateHistoryByDevice.putIfAbsent(deviceId, () => []);
    final history = _heartRateHistoryByDevice[deviceId]!;
    history.add(data);
    if (history.length > 60) history.removeAt(0);
    notifyListeners();
  }

  void addZoneSecond(String deviceId, int zoneIndex) {
    _zoneSecondsByDevice.putIfAbsent(deviceId, () => [0, 0, 0, 0, 0]);
    _zoneSecondsByDevice[deviceId]![zoneIndex]++;
    notifyListeners();
  }

  void clear() {
    _heartRateHistoryByDevice.clear();
    _zoneSecondsByDevice.clear();
    notifyListeners();
  }

  static int getZoneIndex(int heartRate) {
    if (heartRate < 120) return 0;
    if (heartRate < 150) return 1;
    if (heartRate < 170) return 2;
    if (heartRate < 190) return 3;
    return 4;
  }
}

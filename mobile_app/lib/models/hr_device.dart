class HRDevice {
  final String id;
  final String name;
  final String address;
  final int rssi;
  bool isConnected;
  int? currentHeartRate;
  int? batteryLevel;
  List<int>? rrIntervals; // RR intervals in milliseconds (for HRV analysis)
  bool supportsHRV; // Flag to track if device supports HRV

  HRDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.rssi,
    this.isConnected = false,
    this.currentHeartRate,
    this.batteryLevel,
    this.rrIntervals,
    this.supportsHRV = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'rssi': rssi,
    'isConnected': isConnected,
    'currentHeartRate': currentHeartRate,
    'batteryLevel': batteryLevel,
    'rrIntervals': rrIntervals,
    'supportsHRV': supportsHRV,
  };

  factory HRDevice.fromJson(Map<String, dynamic> json) => HRDevice(
    id: json['id'],
    name: json['name'],
    address: json['address'],
    rssi: json['rssi'],
    isConnected: json['isConnected'] ?? false,
    currentHeartRate: json['currentHeartRate'],
    batteryLevel: json['batteryLevel'],
    rrIntervals: json['rrIntervals'] != null ? List<int>.from(json['rrIntervals']) : null,
    supportsHRV: json['supportsHRV'] ?? false,
  );
}

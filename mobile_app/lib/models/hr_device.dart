class HRDevice {
  final String id;
  final String name;
  final String address;
  final int rssi;
  bool isConnected;
  int? currentHeartRate;
  int? batteryLevel;

  HRDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.rssi,
    this.isConnected = false,
    this.currentHeartRate,
    this.batteryLevel,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'rssi': rssi,
    'isConnected': isConnected,
    'currentHeartRate': currentHeartRate,
    'batteryLevel': batteryLevel,
  };

  factory HRDevice.fromJson(Map<String, dynamic> json) => HRDevice(
    id: json['id'],
    name: json['name'],
    address: json['address'],
    rssi: json['rssi'],
    isConnected: json['isConnected'] ?? false,
    currentHeartRate: json['currentHeartRate'],
    batteryLevel: json['batteryLevel'],
  );
}

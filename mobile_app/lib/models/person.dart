import 'package:hive/hive.dart';

part 'person.g.dart';

@HiveType(typeId: 0)
class Person extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  int age;
  
  @HiveField(3)
  String gender;
  
  @HiveField(4)
  double weight; // kg
  
  @HiveField(5)
  double height; // cm
  
  @HiveField(6)
  int? maxHeartRate;
  
  @HiveField(7)
  int? restingHeartRate;
  
  @HiveField(8)
  DateTime createdAt;
  
  @HiveField(9)
  DateTime updatedAt;

  Person({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.weight,
    required this.height,
    this.maxHeartRate,
    this.restingHeartRate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'gender': gender,
    'weight': weight,
    'height': height,
    'maxHeartRate': maxHeartRate,
    'restingHeartRate': restingHeartRate,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'],
    name: json['name'],
    age: json['age'],
    gender: json['gender'],
    weight: json['weight'].toDouble(),
    height: json['height'].toDouble(),
    maxHeartRate: json['maxHeartRate'],
    restingHeartRate: json['restingHeartRate'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}

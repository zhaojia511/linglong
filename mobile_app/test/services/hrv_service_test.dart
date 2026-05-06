import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:linglong_hr_monitor/models/daily_hrv_snapshot.dart';
import 'package:linglong_hr_monitor/models/readiness_measurement.dart';
import 'package:linglong_hr_monitor/services/hrv_service.dart';
import 'package:linglong_hr_monitor/services/supabase_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeSupabaseRepository implements SupabaseRepository {
  final List<Map<String, dynamic>> uploadedMeasurements = [];
  List<Map<String, dynamic>> cloudMeasurements = [];
  Object? uploadError;
  Object? fetchError;

  @override
  Future<void> upsertReadinessMeasurement(
      Map<String, dynamic> measurement) async {
    if (uploadError != null) throw uploadError!;
    uploadedMeasurements.add(Map<String, dynamic>.from(measurement));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchReadinessMeasurements() async {
    if (fetchError != null) throw fetchError!;
    return cloudMeasurements
        .map((measurement) => Map<String, dynamic>.from(measurement))
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HrvService service;
  Box<String>? snapshotBox;
  Box<String>? readinessBox;
  var boxCounter = 0;

  Future<void> openBoxes() async {
    boxCounter += 1;
    snapshotBox = await Hive.openBox<String>('hrv_snapshots_test_$boxCounter');
    readinessBox =
        await Hive.openBox<String>('readiness_measurements_test_$boxCounter');
    service.setTestBoxes(
      snapshotBox: snapshotBox!,
      readinessBox: readinessBox!,
    );
  }

  tearDown(() async {
    await snapshotBox?.deleteFromDisk();
    await readinessBox?.deleteFromDisk();
    snapshotBox = null;
    readinessBox = null;
  });

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hrv_service_test');
    Hive.init(tempDir.path);
    service = HrvService.instance;
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('saveReadinessSnapshot persists a dedicated readiness measurement',
      () async {
    await openBoxes();
    final rrIntervals = List<int>.generate(
      30,
      (index) => 880 + ((index % 4) * 20),
    );

    await service.saveReadinessSnapshot(
      personId: 'athlete-1',
      deviceId: 'sensor-1',
      rrIntervals: rrIntervals,
      durationSec: 180,
      restingHR: 52,
      feelingScore: 4,
    );

    final measurements = service.getReadinessMeasurements('athlete-1');

    expect(measurements, hasLength(1));
    expect(measurements.single.deviceId, 'sensor-1');
    expect(measurements.single.durationSec, 180);
    expect(measurements.single.restingHR, 52);
    expect(measurements.single.feelingScore, 4);
    expect(measurements.single.qualityPct, 100);
    expect(measurements.single.rrIntervals, hasLength(30));
  });

  test('getBaseline prefers dedicated readiness measurements over snapshots',
      () async {
    await openBoxes();

    for (final rmssd in [10.0, 20.0, 30.0]) {
      final measurement = ReadinessMeasurement(
        id: 'm-$rmssd',
        personId: 'athlete-1',
        deviceId: 'sensor-1',
        measuredAt: DateTime.now(),
        durationSec: 180,
        rrIntervals: const [900, 910, 920],
        rmssd: rmssd,
        sdnn: 12,
        pnn50: 5,
        meanRR: 910,
        sd1: 8,
        sd2: 14,
        restingHR: 55,
        qualityPct: 100,
      );
      await readinessBox!.put(measurement.id, jsonEncode(measurement.toJson()));
    }

    for (final rmssd in [80.0, 90.0, 100.0]) {
      final snapshot = DailyHrvSnapshot(
        id: 's-$rmssd',
        personId: 'athlete-1',
        timestamp: DateTime.now(),
        rmssd: rmssd,
        sdnn: 20,
        meanRR: 950,
        restingHR: 50,
        sampleCount: 100,
      );
      await snapshotBox!.put(snapshot.id, jsonEncode(snapshot.toJson()));
    }

    expect(service.getBaseline('athlete-1'), closeTo(20.0, 0.001));
  });

  test('deleteReadinessMeasurement removes the saved record', () async {
    await openBoxes();
    final rrIntervals = List<int>.generate(
      25,
      (index) => 870 + ((index % 3) * 30),
    );

    await service.saveReadinessSnapshot(
      personId: 'athlete-1',
      deviceId: 'sensor-1',
      rrIntervals: rrIntervals,
      durationSec: 120,
      restingHR: 54,
    );

    final saved = service.getReadinessMeasurements('athlete-1').single;
    await service.deleteReadinessMeasurement(saved.id);

    expect(service.getReadinessMeasurements('athlete-1'), isEmpty);
  });

  test(
      'syncAllUnsyncedReadiness uploads unsynced records and marks them synced',
      () async {
    await openBoxes();
    final repo = _FakeSupabaseRepository();

    final measurement = ReadinessMeasurement(
      id: 'sync-up-1',
      personId: 'athlete-1',
      deviceId: 'sensor-1',
      measuredAt: DateTime(2026, 5, 6, 7, 30),
      durationSec: 180,
      rrIntervals: const [910, 920, 930, 940],
      rmssd: 32,
      sdnn: 28,
      pnn50: 12,
      meanRR: 925,
      sd1: 22,
      sd2: 31,
      restingHR: 50,
      qualityPct: 96,
      readinessPct: 104,
      feelingScore: 4,
    );

    await readinessBox!.put(measurement.id, jsonEncode(measurement.toJson()));

    await service.syncAllUnsyncedReadiness(repo);

    expect(repo.uploadedMeasurements, hasLength(1));
    final payload = repo.uploadedMeasurements.single;
    expect(payload['id'], 'sync-up-1');
    expect(payload['person_id'], 'athlete-1');
    expect(payload['device_id'], 'sensor-1');
    expect(payload['duration_sec'], 180);
    expect(payload['rr_intervals'], [910, 920, 930, 940]);
    expect(payload['feeling'], 4);

    final synced = service.getReadinessMeasurements('athlete-1').singleWhere(
          (entry) => entry.id == 'sync-up-1',
        );
    expect(synced.synced, isTrue);
  });

  test('syncDownReadinessFromCloud stores missing cloud records locally',
      () async {
    await openBoxes();
    final repo = _FakeSupabaseRepository()
      ..cloudMeasurements = [
        {
          'id': 'cloud-1',
          'person_id': 'athlete-2',
          'device_id': 'sensor-9',
          'measured_at': '2026-05-06T01:02:03.000Z',
          'duration_sec': 120,
          'rr_intervals': [800, 810, 820],
          'rmssd': 45.5,
          'sdnn': 40.2,
          'pnn50': 18.0,
          'mean_rr': 810.0,
          'sd1': 30.1,
          'sd2': 44.9,
          'resting_hr': 49,
          'quality_pct': 98.0,
          'readiness_pct': 110.0,
          'feeling': 5,
        }
      ];

    await service.syncDownReadinessFromCloud(repo);

    final saved = service.getReadinessMeasurements('athlete-2').single;
    expect(saved.id, 'cloud-1');
    expect(saved.deviceId, 'sensor-9');
    expect(saved.durationSec, 120);
    expect(saved.rrIntervals, [800, 810, 820]);
    expect(saved.feelingScore, 5);
    expect(saved.synced, isTrue);
  });

  test('syncAllUnsyncedReadiness skips missing remote table without throwing',
      () async {
    await openBoxes();
    final repo = _FakeSupabaseRepository()
      ..uploadError = const PostgrestException(
        message:
            "Could not find the table 'public.readiness_measurements' in the schema cache",
        code: 'PGRST205',
      );

    final measurement = ReadinessMeasurement(
      id: 'missing-table-up',
      personId: 'athlete-3',
      deviceId: 'sensor-3',
      measuredAt: DateTime(2026, 5, 6, 8, 0),
      durationSec: 180,
      rrIntervals: const [900, 905, 910],
      rmssd: 20,
      sdnn: 18,
      pnn50: 5,
      meanRR: 905,
      sd1: 12,
      sd2: 19,
      qualityPct: 100,
    );

    await readinessBox!.put(measurement.id, jsonEncode(measurement.toJson()));

    await service.syncAllUnsyncedReadiness(repo);

    final saved = service.getReadinessMeasurements('athlete-3').single;
    expect(saved.synced, isFalse);
  });

  test('syncDownReadinessFromCloud skips missing remote table without throwing',
      () async {
    await openBoxes();
    final repo = _FakeSupabaseRepository()
      ..fetchError = const PostgrestException(
        message:
            "Could not find the table 'public.readiness_measurements' in the schema cache",
        code: 'PGRST205',
      );

    await service.syncDownReadinessFromCloud(repo);

    expect(service.getAllReadinessMeasurements(), isEmpty);
  });
}

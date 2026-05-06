import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:linglong_hr_monitor/models/daily_hrv_snapshot.dart';
import 'package:linglong_hr_monitor/models/readiness_measurement.dart';
import 'package:linglong_hr_monitor/services/hrv_service.dart';

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
}

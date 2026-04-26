import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/daily_hrv_snapshot.dart';
import '../utils/hrv_analysis.dart';

class HrvService extends ChangeNotifier {
  static final HrvService instance = HrvService._internal();
  HrvService._internal();

  Box<String>? _box;

  // Accumulated RR intervals per device during an active session.
  final Map<String, List<int>> _sessionRRByDevice = {};

  // Last-known RR list per device — used to avoid double-counting duplicates.
  final Map<String, List<int>> _lastKnownRR = {};

  Future<void> init() async {
    _box = await Hive.openBox<String>('hrv_snapshots');
  }

  // ── Session accumulation ──────────────────────────────────────────────────

  /// Call this each timer tick with the device's current rrIntervals list.
  /// Only appends if the list has changed since the last call.
  void addRRIntervals(String deviceId, List<int> intervals) {
    if (intervals.isEmpty) return;
    final last = _lastKnownRR[deviceId];
    if (last != null && _listEquals(last, intervals)) return; // no new data
    _lastKnownRR[deviceId] = List<int>.from(intervals);
    _sessionRRByDevice.putIfAbsent(deviceId, () => []);
    _sessionRRByDevice[deviceId]!.addAll(intervals);
  }

  void clearSessionData() {
    _sessionRRByDevice.clear();
    _lastKnownRR.clear();
  }

  List<int> getSessionRR(String deviceId) =>
      _sessionRRByDevice[deviceId] ?? [];

  /// Live RMSSD from accumulated session RR intervals.
  /// Returns null if fewer than 50 intervals have been collected.
  double? getLiveRmssd(String deviceId) {
    final rr = getSessionRR(deviceId);
    if (rr.length < 50) return null;
    final val = HrvAnalysis.rmssd(rr);
    return val > 0 ? val : null;
  }

  // ── Snapshot persistence ──────────────────────────────────────────────────

  /// Compute HRV from accumulated session data and persist a snapshot.
  Future<void> saveSessionHrv(
      String personId, String deviceId, int? restingHR) async {
    if (_box == null) return;
    final rr = getSessionRR(deviceId);
    if (rr.length < 50) return;
    final result = HrvAnalysis.analyze(rr);
    if (result.rmssd <= 0) return;

    final snapshot = DailyHrvSnapshot(
      id: const Uuid().v4(),
      personId: personId,
      timestamp: DateTime.now(),
      rmssd: result.rmssd,
      sdnn: result.sdnn,
      meanRR: result.meanRR,
      restingHR: restingHR,
      sampleCount: result.validIntervals,
    );

    await _box!.put(snapshot.id, jsonEncode(snapshot.toJson()));
    notifyListeners();
  }

  /// Save a dedicated readiness measurement snapshot (from the readiness screen).
  /// Accepts the raw [rrIntervals] directly rather than pulling from session state.
  Future<void> saveReadinessSnapshot({
    required String personId,
    required String deviceId,
    required List<int> rrIntervals,
    int? restingHR,
    int? feelingScore,
  }) async {
    if (_box == null) return;
    if (rrIntervals.length < 20) return;
    final result = HrvAnalysis.analyze(rrIntervals);
    if (result.rmssd <= 0) return;

    final snapshot = DailyHrvSnapshot(
      id: const Uuid().v4(),
      personId: personId,
      timestamp: DateTime.now(),
      rmssd: result.rmssd,
      sdnn: result.sdnn,
      meanRR: result.meanRR,
      restingHR: restingHR,
      sampleCount: result.validIntervals,
    );

    await _box!.put(snapshot.id, jsonEncode(snapshot.toJson()));
    notifyListeners();
  }

  // ── Query ─────────────────────────────────────────────────────────────────

  List<DailyHrvSnapshot> getSnapshots(String personId, {int days = 60}) {
    if (_box == null) return [];
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final results = <DailyHrvSnapshot>[];
    for (final raw in _box!.values) {
      try {
        final s = DailyHrvSnapshot.fromJson(jsonDecode(raw));
        if (s.personId == personId && s.timestamp.isAfter(cutoff)) {
          results.add(s);
        }
      } catch (_) {}
    }
    results.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return results;
  }

  /// Rolling baseline RMSSD from last 60 days. Returns null if fewer than
  /// 3 snapshots exist (not enough data to establish a baseline).
  double? getBaseline(String personId) {
    final snapshots = getSnapshots(personId, days: 60);
    if (snapshots.length < 3) return null;
    return snapshots.map((s) => s.rmssd).reduce((a, b) => a + b) /
        snapshots.length;
  }

  /// Readiness score relative to personal baseline.
  /// Pass [currentRmssd] to override with a live value (e.g. from an
  /// ongoing session); otherwise the most recent stored snapshot is used.
  ReadinessScore? getReadiness(String personId, {double? currentRmssd}) {
    final baseline = getBaseline(personId);
    if (baseline == null || baseline <= 0) return null;

    double? rmssd = currentRmssd;
    if (rmssd == null) {
      final recent = getSnapshots(personId, days: 1);
      rmssd = recent.isEmpty ? null : recent.last.rmssd;
    }
    if (rmssd == null) return null;

    final percent = (rmssd / baseline * 100).clamp(0.0, 150.0);
    return ReadinessScore(
        percent: percent, baseline: baseline, currentRmssd: rmssd);
  }

  // ── Fatigue ───────────────────────────────────────────────────────────────

  /// Acute fatigue (default 7-day) or chronic fatigue (28-day).
  /// Lower recent RMSSD vs baseline = higher fatigue.
  FatigueScore? getFatigue(String personId, {int days = 7}) {
    final baseline = getBaseline(personId);
    if (baseline == null || baseline <= 0) return null;
    final snapshots = getSnapshots(personId, days: days);
    if (snapshots.isEmpty) return null;

    final avg = snapshots.map((s) => s.rmssd).reduce((a, b) => a + b) /
        snapshots.length;
    final pct = (avg / baseline * 100).clamp(0.0, 150.0);

    final level = pct >= 90
        ? FatigueLevel.low
        : pct >= 75
            ? FatigueLevel.elevated
            : pct >= 60
                ? FatigueLevel.high
                : FatigueLevel.veryHigh;

    return FatigueScore(
        level: level, windowAvgRmssd: avg, baseline: baseline, days: days);
  }

  // ── Team summary ──────────────────────────────────────────────────────────

  /// Average readiness % across all athletes that have a baseline.
  double? getTeamAvgReadiness(List<String> personIds) {
    final scores = personIds
        .map((id) => getReadiness(id))
        .whereType<ReadinessScore>()
        .toList();
    if (scores.isEmpty) return null;
    return scores.map((s) => s.percent).reduce((a, b) => a + b) /
        scores.length;
  }

  // ── Manual snapshot (morning HRV) ─────────────────────────────────────────

  /// Persist a snapshot computed externally (e.g. morning measurement screen).
  Future<void> saveDirectSnapshot(DailyHrvSnapshot snapshot) async {
    if (_box == null) return;
    await _box!.put(snapshot.id, jsonEncode(snapshot.toJson()));
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ── Fatigue model ─────────────────────────────────────────────────────────────

enum FatigueLevel { low, elevated, high, veryHigh }

class FatigueScore {
  final FatigueLevel level;
  final double windowAvgRmssd; // avg RMSSD for the window period
  final double baseline;       // 60-day RMSSD baseline
  final int days;              // window size (7 = acute, 28 = chronic)

  const FatigueScore({
    required this.level,
    required this.windowAvgRmssd,
    required this.baseline,
    required this.days,
  });

  /// windowAvgRmssd as % of baseline (higher = less fatigued).
  double get percent => (windowAvgRmssd / baseline * 100).clamp(0.0, 150.0);

  Color get color {
    switch (level) {
      case FatigueLevel.low:
        return const Color(0xFF1E88E5); // blue
      case FatigueLevel.elevated:
        return const Color(0xFFFFB300); // amber
      case FatigueLevel.high:
        return const Color(0xFFF4511E); // deep orange
      case FatigueLevel.veryHigh:
        return const Color(0xFFE53935); // red
    }
  }

  String get label {
    switch (level) {
      case FatigueLevel.low:
        return 'Low';
      case FatigueLevel.elevated:
        return 'Elevated';
      case FatigueLevel.high:
        return 'High';
      case FatigueLevel.veryHigh:
        return 'Very High';
    }
  }
}

// ── Readiness model ───────────────────────────────────────────────────────────

enum ReadinessZone { veryLow, low, normal, high }

class ReadinessScore {
  final double percent;      // 0–150 (100 = exactly at baseline)
  final double baseline;     // personal RMSSD baseline (ms)
  final double currentRmssd; // current RMSSD (ms)

  const ReadinessScore({
    required this.percent,
    required this.baseline,
    required this.currentRmssd,
  });

  ReadinessZone get zone {
    if (percent < 70) return ReadinessZone.veryLow;
    if (percent < 85) return ReadinessZone.low;
    if (percent <= 115) return ReadinessZone.normal;
    return ReadinessZone.high;
  }

  Color get color {
    switch (zone) {
      case ReadinessZone.veryLow:
        return const Color(0xFFE65100); // deep orange
      case ReadinessZone.low:
        return const Color(0xFFFFB300); // amber
      case ReadinessZone.normal:
        return const Color(0xFF1E88E5); // blue
      case ReadinessZone.high:
        return const Color(0xFF0D47A1); // dark blue
    }
  }

  String get label {
    switch (zone) {
      case ReadinessZone.veryLow:
        return 'Very Low';
      case ReadinessZone.low:
        return 'Low';
      case ReadinessZone.normal:
        return 'Normal';
      case ReadinessZone.high:
        return 'High';
    }
  }
}

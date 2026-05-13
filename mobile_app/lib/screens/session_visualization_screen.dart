
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/person.dart';
import '../models/training_session.dart';
import '../utils/hr_data_processing.dart';
import '../utils/hrv_analysis.dart';
import '../utils/heart_rate_zones.dart';

class SessionVisualizationScreen extends StatefulWidget {
  final TrainingSession session;
  final Person? person;
  const SessionVisualizationScreen({super.key, required this.session, this.person});

  @override
  State<SessionVisualizationScreen> createState() =>
      _SessionVisualizationScreenState();
}

class _SessionVisualizationScreenState extends State<SessionVisualizationScreen>
    with SingleTickerProviderStateMixin {
  bool _trimEnabled = false;
  bool _noiseFilter = false;
  int _warmupSec = 0;
  int _cooldownSec = 0;
  late TabController _tabController;

  TrainingSession get session => widget.session;
  Person? get person => widget.person;

  List<HeartRateData> get _processedData {
    var data = session.heartRateData;
    if (_trimEnabled) {
      data = HrDataProcessing.trim(data,
          warmupSeconds: _warmupSec, cooldownSeconds: _cooldownSec);
    }
    if (_noiseFilter) data = HrDataProcessing.filterNoise(data);
    return data;
  }

  List<int> get _rrIntervals => _processedData
      .where((d) => d.heartRate > 30 && d.heartRate < 220)
      .map((d) => (60000 / d.heartRate).round())
      .toList();

  /// Get max heart rate (from person or calculate)
  int get _maxHeartRate {
    if (person?.maxHeartRate != null) {
      return person!.maxHeartRate!;
    }
    if (person != null) {
      return HeartRateZones.calculateMaxHeartRate(person!.age);
    }
    // Default if no person data
    return 180;
  }

  /// Get resting heart rate (from person or default)
  int get _restingHeartRate {
    return person?.restingHeartRate ?? 60;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (session.heartRateData.isNotEmpty) {
      _warmupSec = HrDataProcessing.detectWarmup(session.heartRateData);
      _cooldownSec = HrDataProcessing.detectCooldown(session.heartRateData);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(session.title.isNotEmpty ? session.title : session.trainingType,
            style: const TextStyle(fontSize: 16)),
        toolbarHeight: 36,
        actions: [
          Icon(
            session.synced ? Icons.cloud_done : Icons.cloud_upload,
            color: session.synced ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Heart Rate'),
            Tab(text: 'Zones'),
            Tab(text: 'HRV'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Compact info card — always visible
          _buildCompactInfoCard(),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHRTab(),
                _buildZonesTab(),
                _buildHRVTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Compact two-column info card ──────────────────────────────────────────

  Widget _buildCompactInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          // Left: general info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoItem(Icons.calendar_today, _formatDate(session.startTime)),
                const SizedBox(height: 4),
                _infoItem(Icons.timer, _formatDuration(session.duration)),
                const SizedBox(height: 4),
                _infoItem(Icons.sports, session.trainingType),
              ],
            ),
          ),
          // Divider
          Container(width: 1, height: 56, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(width: 16),
          // Right: HR stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (session.avgHeartRate != null)
                  _infoItem(Icons.favorite, 'Avg  ${session.avgHeartRate} bpm',
                      color: Colors.orange),
                if (session.maxHeartRate != null) ...[
                  const SizedBox(height: 4),
                  _infoItem(Icons.trending_up, 'Max  ${session.maxHeartRate} bpm',
                      color: Colors.red),
                ],
                if (session.minHeartRate != null) ...[
                  const SizedBox(height: 4),
                  _infoItem(Icons.trending_down, 'Min  ${session.minHeartRate} bpm',
                      color: Colors.blue),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String text, {Color? color}) => Row(
        children: [
          Icon(icon, size: 13, color: color ?? Colors.grey[600]),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: color ?? Colors.grey[800],
                  fontWeight: FontWeight.w500)),
        ],
      );

  // ── Heart Rate tab ────────────────────────────────────────────────────────

  Widget _buildHRTab() {
    if (session.heartRateData.isEmpty) {
      return const Center(child: Text('No heart rate data'));
    }
    final processed = _processedData;
    final stats = HrDataProcessing.calcStats(processed);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Processing controls
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Trim warmup / cooldown',
                        style: TextStyle(fontSize: 13)),
                    subtitle: _trimEnabled
                        ? Text('Warmup ${_warmupSec}s · Cooldown ${_cooldownSec}s',
                            style: const TextStyle(fontSize: 11))
                        : null,
                    value: _trimEnabled,
                    onChanged: (v) => setState(() => _trimEnabled = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  if (_trimEnabled)
                    Row(children: [
                      Expanded(child: _slider('Warmup', _warmupSec, (v) => _warmupSec = v)),
                      Expanded(child: _slider('Cooldown', _cooldownSec, (v) => _cooldownSec = v)),
                    ]),
                  SwitchListTile(
                    title: const Text('Noise filter', style: TextStyle(fontSize: 13)),
                    value: _noiseFilter,
                    onChanged: (v) => setState(() => _noiseFilter = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  if (_trimEnabled || _noiseFilter)
                    Text(
                      'Processed — Avg ${stats.avgHR} · Max ${stats.maxHR} · Min ${stats.minHR} bpm',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // HR chart
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(height: 260, child: _buildHRChart(processed)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Zones tab ─────────────────────────────────────────────────────────────

  Widget _buildZonesTab() {
    if (session.heartRateData.isEmpty) {
      return const Center(child: Text('No heart rate data'));
    }

    // Get zone times - use saved data if available, otherwise calculate
    List<int> zoneTimes = session.zoneTimes ?? _calculateZoneTimes(_processedData);
    final totalTime = zoneTimes.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card with person info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Heart Rate Zone Distribution',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total time: ${_formatZoneDuration(totalTime)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (person != null) ...[
                    const SizedBox(height: 8),
                    _buildPersonInfo(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Zone breakdown with bars
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time in Each Zone',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(5, (index) => _buildZoneRow(
                    index,
                    zoneTimes[index],
                    totalTime,
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Zone distribution chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zone Distribution',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildZoneDistributionChart(zoneTimes, totalTime),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonInfo() {
    final maxHrSource = person!.maxHeartRate != null ? 'Manual' : 'Calculated (220 - age)';
    final restingHrSource = person!.restingHeartRate != null ? 'Manual' : 'Default (60 bpm)';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalized for: ${person!.name}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Max HR: $_maxHeartRate bpm ($maxHrSource)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            'Resting HR: $_restingHeartRate bpm ($restingHrSource)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneRow(int zoneIndex, int timeSeconds, int totalTime) {
    final percentage = totalTime > 0 ? (timeSeconds / totalTime * 100).toStringAsFixed(1) : '0';
    final zoneRange = person != null
        ? HeartRateZones.getZoneRangeStringForPerson(zoneIndex, person!)
        : HeartRateZones.getZoneRangeString(zoneIndex, _maxHeartRate, _restingHeartRate);
    final zoneColor = Color(HeartRateZones.zoneColors[zoneIndex]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: zoneColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${HeartRateZones.zoneNames[zoneIndex]} ($zoneRange)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                '${_formatZoneDuration(timeSeconds)} · $percentage%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalTime > 0 ? timeSeconds / totalTime : 0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(zoneColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneDistributionChart(List<int> zoneTimes, int totalTime) {
    if (totalTime == 0) {
      return const Center(child: Text('No data'));
    }

    return Row(
      children: List.generate(5, (index) {
        final flex = zoneTimes[index];
        final zoneColor = Color(HeartRateZones.zoneColors[index]);
        return Expanded(
          flex: flex > 0 ? flex : 0,
          child: Container(
            height: 80,
            color: zoneColor,
            child: flex > 0
                ? Center(
                    child: Text(
                      '${(zoneTimes[index] / totalTime * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }

  List<int> _calculateZoneTimes(List<HeartRateData> heartRateData) {
    if (heartRateData.length < 2) return [0, 0, 0, 0, 0];

    final zoneTimes = [0, 0, 0, 0, 0];
    final sortedData = List<HeartRateData>.from(heartRateData)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (int i = 1; i < sortedData.length; i++) {
      final previous = sortedData[i - 1];
      final current = sortedData[i];
      final duration = current.timestamp.difference(previous.timestamp).inSeconds;
      final avgHr = ((previous.heartRate + current.heartRate) / 2).round();
      final zoneIndex = person != null
          ? HeartRateZones.getZoneIndexForPerson(avgHr, person!)
          : HeartRateZones.getZoneIndex(avgHr, _maxHeartRate, _restingHeartRate);
      zoneTimes[zoneIndex] += duration;
    }

    return zoneTimes;
  }

  String _formatZoneDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }

  Widget _slider(String label, int value, void Function(int) onSet) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ${value}s', style: const TextStyle(fontSize: 11)),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 300,
          divisions: 300,
          onChanged: (v) => setState(() => onSet(v.round())),
        ),
      ]);

  // ── HRV tab ───────────────────────────────────────────────────────────────

  Widget _buildHRVTab() {
    final rr = _rrIntervals;
    if (rr.length < 10) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.monitor_heart_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Not enough data for HRV analysis\n(need ≥10 HR samples)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
          ]),
        ),
      );
    }

    final hrv = HrvAnalysis.analyze(rr);
    final rolling = HrvAnalysis.rollingRmssd(rr, windowSize: min(30, rr.length ~/ 3));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary metrics with reference ranges
          _buildHrvSummary(hrv),
          const SizedBox(height: 12),
          // Poincaré plot
          _buildPoincareCard(hrv),
          const SizedBox(height: 12),
          // Rolling RMSSD trend
          if (rolling.length >= 5) ...[
            _buildRollingRmssdCard(rolling),
            const SizedBox(height: 12),
          ],
          // Acute interpretation note
          _buildAcuteNote(hrv),
        ],
      ),
    );
  }

  Widget _buildHrvSummary(HrvResult hrv) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HRV Metrics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(children: [
            _hrvMetricTile('RMSSD', hrv.rmssd, 'ms',
                low: 20, mid: 40, high: 60,
                note: 'Parasympathetic tone'),
            _hrvMetricTile('SDNN', hrv.sdnn, 'ms',
                low: 20, mid: 50, high: 100,
                note: 'Overall variability'),
            _hrvMetricTile('pNN50', hrv.pnn50, '%',
                low: 5, mid: 15, high: 30,
                note: 'Vagal activity'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _hrvMetricTile('SD1', hrv.sd1, 'ms',
                low: 10, mid: 25, high: 45,
                note: 'Short-term (beat-to-beat)'),
            _hrvMetricTile('SD2', hrv.sd2, 'ms',
                low: 20, mid: 50, high: 90,
                note: 'Long-term variability'),
            Expanded(
              child: Column(children: [
                Text(hrv.stressLevel,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _stressColor(hrv.stressLevel))),
                const SizedBox(height: 2),
                Text('Stress', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text('${hrv.validIntervals}/${hrv.totalIntervals} valid',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _hrvMetricTile(String label, double value, String unit,
      {required double low, required double mid, required double high, required String note}) {
    final color = value >= high
        ? Colors.green
        : value >= mid
            ? Colors.orange
            : Colors.red;
    return Expanded(
      child: Column(children: [
        Text('${value.toStringAsFixed(1)} $unit',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(note,
            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            textAlign: TextAlign.center),
      ]),
    );
  }

  /// Poincaré scatter plot: RR[i] vs RR[i+1]
  Widget _buildPoincareCard(HrvResult hrv) {
    final rr = hrv.filteredRR;
    if (rr.length < 4) return const SizedBox.shrink();

    final spots = <ScatterSpot>[];
    for (int i = 0; i < rr.length - 1; i++) {
      spots.add(ScatterSpot(rr[i].toDouble(), rr[i + 1].toDouble(),
          radius: 3, color: Colors.blue.withValues(alpha: 0.6)));
    }

    final allRR = rr.map((v) => v.toDouble()).toList();
    final minRR = allRR.reduce(min) - 20;
    final maxRR = allRR.reduce(max) + 20;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Poincaré Plot',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 8),
            Text('SD1 ${hrv.sd1.toStringAsFixed(1)} ms · SD2 ${hrv.sd2.toStringAsFixed(1)} ms',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ]),
          const SizedBox(height: 4),
          Text('Each dot = successive RR pair. Wide spread = high HRV.',
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ScatterChart(ScatterChartData(
              scatterSpots: spots,
              minX: minRR,
              maxX: maxRR,
              minY: minRR,
              maxY: maxRR,
              borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300)),
              gridData: const FlGridData(
                  show: true,
                  horizontalInterval: 100,
                  verticalInterval: 100),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    axisNameWidget: const Text('RR[i+1] ms',
                        style: TextStyle(fontSize: 10)),
                    sideTitles: SideTitles(
                        reservedSize: 36,
                        interval: 100,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 9)))),
                bottomTitles: AxisTitles(
                    axisNameWidget: const Text('RR[i] ms',
                        style: TextStyle(fontSize: 10)),
                    sideTitles: SideTitles(
                        reservedSize: 28,
                        interval: 100,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 9)))),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              scatterTouchData: ScatterTouchData(enabled: false),
            )),
          ),
        ]),
      ),
    );
  }

  /// Rolling RMSSD trend line
  Widget _buildRollingRmssdCard(List<({int index, double rmssd})> rolling) {
    final spots = rolling
        .map((p) => FlSpot(p.index.toDouble(), p.rmssd))
        .toList();
    final maxY = spots.map((s) => s.y).reduce(max) + 10;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RMSSD Over Session',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('Rolling window · drop = increasing fatigue/stress',
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: LineChart(LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: const FlGridData(
                  show: true, horizontalInterval: 20, verticalInterval: 20),
              borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        reservedSize: 32,
                        interval: 20,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 9)))),
                bottomTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.teal,
                  barWidth: 2,
                  dotData: const FlDotData(),
                  belowBarData: BarAreaData(
                      show: true,
                      color: Colors.teal.withValues(alpha: 0.15)),
                ),
                // Reference line at 20ms (high stress threshold)
                LineChartBarData(
                  spots: [
                    FlSpot(spots.first.x, 20),
                    FlSpot(spots.last.x, 20)
                  ],
                  color: Colors.red.withValues(alpha: 0.4),
                  barWidth: 1,
                  dashArray: const [4, 4],
                  dotData: const FlDotData(),
                ),
              ],
            )),
          ),
          Text('Red dashed = 20 ms threshold (high stress below)',
              style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        ]),
      ),
    );
  }

  Widget _buildAcuteNote(HrvResult hrv) {
    final lines = [
      '• During exercise HRV naturally drops — compare relative to your baseline, not absolute values.',
      '• RMSSD < 20 ms during recovery → significant fatigue load.',
      '• Poincaré: tight vertical cluster = respiratory-driven variability. Wide scatter = strong vagal tone.',
      '• SD1/SD2 ratio < 0.25 suggests sympathetic dominance (hard effort or stress).',
    ];
    final ratio = hrv.sd2 > 0 ? hrv.sd1 / hrv.sd2 : 0.0;
    final ratioNote = 'SD1/SD2 this session: ${ratio.toStringAsFixed(2)}'
        '${ratio < 0.25 ? ' — sympathetic dominant' : ' — balanced autonomic tone'}';

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Acute HRV — Training Context',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l, style: const TextStyle(fontSize: 11)),
              )),
          const SizedBox(height: 4),
          Text(ratioNote,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ratio < 0.25 ? Colors.orange[800] : Colors.green[800])),
        ]),
      ),
    );
  }

  // ── HR chart ──────────────────────────────────────────────────────────────

  Widget _buildHRChart(List<HeartRateData> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final sorted = List<HeartRateData>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final start = sorted.first.timestamp;
    final spots = sorted
        .map((d) => FlSpot(
            d.timestamp.difference(start).inSeconds.toDouble(),
            d.heartRate.toDouble()))
        .toList();
    final minY = spots.map((s) => s.y).reduce(min) - 10;
    final maxY = spots.map((s) => s.y).reduce(max) + 10;

    return LineChart(LineChartData(
      minY: minY < 0 ? 0 : minY,
      maxY: maxY,
      gridData: const FlGridData(
          show: true, horizontalInterval: 20, verticalInterval: 60),
      borderData:
          FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                reservedSize: 36,
                interval: 20,
                getTitlesWidget: (v, _) =>
                    Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)))),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                reservedSize: 28,
                interval: 120,
                getTitlesWidget: (v, _) => Text('${(v / 60).round()}m',
                    style: const TextStyle(fontSize: 9)))),
        rightTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.red,
          barWidth: 2,
          dotData: const FlDotData(),
          belowBarData: BarAreaData(
              show: true, color: Colors.red.withValues(alpha: 0.1)),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((s) {
            final m = (s.x / 60).floor();
            final sec = (s.x % 60).round();
            return LineTooltipItem(
                '${m}m ${sec}s\n${s.y.toInt()} bpm',
                const TextStyle(color: Colors.white, fontSize: 11));
          }).toList(),
        ),
      ),
    ));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _stressColor(String level) {
    switch (level) {
      case 'Low': return Colors.green;
      case 'Moderate': return Colors.orange;
      case 'High': return Colors.deepOrange;
      default: return Colors.red;
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m ${sec}s';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }
}

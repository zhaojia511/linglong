import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/training_session.dart';
import '../utils/hr_data_processing.dart';
import '../utils/hrv_analysis.dart';
import '../utils/timezone_utils.dart';

class SessionVisualizationScreen extends StatefulWidget {
  final TrainingSession session;
  const SessionVisualizationScreen({super.key, required this.session});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: Text(
            session.title.isNotEmpty ? session.title : session.trainingType,
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
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
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
          Container(
              width: 1, height: 56, color: Colors.grey.withValues(alpha: 0.3)),
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
                  _infoItem(
                      Icons.trending_up, 'Max  ${session.maxHeartRate} bpm',
                      color: Colors.red),
                ],
                if (session.minHeartRate != null) ...[
                  const SizedBox(height: 4),
                  _infoItem(
                      Icons.trending_down, 'Min  ${session.minHeartRate} bpm',
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
                        ? Text(
                            'Warmup ${_warmupSec}s · Cooldown ${_cooldownSec}s',
                            style: const TextStyle(fontSize: 11))
                        : null,
                    value: _trimEnabled,
                    onChanged: (v) => setState(() => _trimEnabled = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  if (_trimEnabled)
                    Row(children: [
                      Expanded(
                          child: _slider(
                              'Warmup', _warmupSec, (v) => _warmupSec = v)),
                      Expanded(
                          child: _slider('Cooldown', _cooldownSec,
                              (v) => _cooldownSec = v)),
                    ]),
                  SwitchListTile(
                    title: const Text('Noise filter',
                        style: TextStyle(fontSize: 13)),
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
            Icon(Icons.monitor_heart_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Not enough data for HRV analysis\n(need ≥10 HR samples)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
          ]),
        ),
      );
    }

    final hrv = HrvAnalysis.analyze(rr);
    final rolling =
        HrvAnalysis.rollingRmssd(rr, windowSize: min(30, rr.length ~/ 3));

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
                low: 20, mid: 40, high: 60, note: 'Parasympathetic tone'),
            _hrvMetricTile('SDNN', hrv.sdnn, 'ms',
                low: 20, mid: 50, high: 100, note: 'Overall variability'),
            _hrvMetricTile('pNN50', hrv.pnn50, '%',
                low: 5, mid: 15, high: 30, note: 'Vagal activity'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _hrvMetricTile('SD1', hrv.sd1, 'ms',
                low: 10, mid: 25, high: 45, note: 'Short-term (beat-to-beat)'),
            _hrvMetricTile('SD2', hrv.sd2, 'ms',
                low: 20, mid: 50, high: 90, note: 'Long-term variability'),
            Expanded(
              child: Column(children: [
                Text(hrv.stressLevel,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _stressColor(hrv.stressLevel))),
                const SizedBox(height: 2),
                Text('Stress',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
      {required double low,
      required double mid,
      required double high,
      required String note}) {
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
            Text(
                'SD1 ${hrv.sd1.toStringAsFixed(1)} ms · SD2 ${hrv.sd2.toStringAsFixed(1)} ms',
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
                  show: true, border: Border.all(color: Colors.grey.shade300)),
              gridData: const FlGridData(
                  show: true, horizontalInterval: 100, verticalInterval: 100),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    axisNameWidget: const Text('RR[i+1] ms',
                        style: TextStyle(fontSize: 10)),
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 100,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 9)))),
                bottomTitles: AxisTitles(
                    axisNameWidget:
                        const Text('RR[i] ms', style: TextStyle(fontSize: 10)),
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 100,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 9)))),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
    final spots =
        rolling.map((p) => FlSpot(p.index.toDouble(), p.rmssd)).toList();
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
                  show: true, border: Border.all(color: Colors.grey.shade300)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 20,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 9)))),
                bottomTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.teal,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                      show: true, color: Colors.teal.withValues(alpha: 0.15)),
                ),
                // Reference line at 20ms (high stress threshold)
                LineChartBarData(
                  spots: [FlSpot(spots.first.x, 20), FlSpot(spots.last.x, 20)],
                  color: Colors.red.withValues(alpha: 0.4),
                  barWidth: 1,
                  dashArray: [4, 4],
                  dotData: const FlDotData(show: false),
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
                  color:
                      ratio < 0.25 ? Colors.orange[800] : Colors.green[800])),
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
        .map((d) => FlSpot(d.timestamp.difference(start).inSeconds.toDouble(),
            d.heartRate.toDouble()))
        .toList();
    final minY = spots.map((s) => s.y).reduce(min) - 10;
    final maxY = spots.map((s) => s.y).reduce(max) + 10;

    return LineChart(LineChartData(
      minY: minY < 0 ? 0 : minY,
      maxY: maxY,
      gridData: const FlGridData(
          show: true, horizontalInterval: 20, verticalInterval: 60),
      borderData: FlBorderData(
          show: true, border: Border.all(color: Colors.grey.shade300)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 20,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: const TextStyle(fontSize: 9)))),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 120,
                getTitlesWidget: (v, _) => Text('${(v / 60).round()}m',
                    style: const TextStyle(fontSize: 9)))),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.red,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData:
              BarAreaData(show: true, color: Colors.red.withValues(alpha: 0.1)),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((s) {
            final m = (s.x / 60).floor();
            final sec = (s.x % 60).round();
            return LineTooltipItem('${m}m ${sec}s\n${s.y.toInt()} bpm',
                const TextStyle(color: Colors.white, fontSize: 11));
          }).toList(),
        ),
      ),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _stressColor(String level) {
    switch (level) {
      case 'Low':
        return Colors.green;
      case 'Moderate':
        return Colors.orange;
      case 'High':
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }

  String _formatDate(DateTime dt) => TimezoneUtils.formatDateTime(dt);

  String _formatDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m ${sec}s';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }
}

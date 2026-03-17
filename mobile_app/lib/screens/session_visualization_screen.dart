import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/training_session.dart';
import '../utils/hr_data_processing.dart';
import '../utils/hrv_analysis.dart';
import '../utils/training_load.dart';
import '../models/person.dart';
import '../services/database_service.dart';

class SessionVisualizationScreen extends StatefulWidget {
  final TrainingSession session;

  const SessionVisualizationScreen({super.key, required this.session});

  @override
  State<SessionVisualizationScreen> createState() => _SessionVisualizationScreenState();
}

class _SessionVisualizationScreenState extends State<SessionVisualizationScreen> {
  bool _trimEnabled = false;
  bool _noiseFilter = false;
  int _warmupSec = 0;
  int _cooldownSec = 0;
  Person? _person;

  TrainingSession get session => widget.session;

  List<HeartRateData> get _processedData {
    var data = session.heartRateData;
    if (_trimEnabled) {
      data = HrDataProcessing.trim(data, warmupSeconds: _warmupSec, cooldownSeconds: _cooldownSec);
    }
    if (_noiseFilter) {
      data = HrDataProcessing.filterNoise(data);
    }
    return data;
  }

  @override
  void initState() {
    super.initState();
    if (session.heartRateData.isNotEmpty) {
      _warmupSec = HrDataProcessing.detectWarmup(session.heartRateData);
      _cooldownSec = HrDataProcessing.detectCooldown(session.heartRateData);
    }
    _person = DatabaseService.instance.getPersonById(session.personId);
  }

  @override
  Widget build(BuildContext context) {
    final processed = _processedData;
    final processedStats = HrDataProcessing.calcStats(processed);

    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          Icon(
            session.synced ? Icons.cloud_done : Icons.cloud_upload,
            color: session.synced ? Colors.green : Colors.grey,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Date', _formatDateTime(session.startTime)),
                    _buildInfoRow('Duration', _formatDuration(session.duration)),
                    _buildInfoRow('Type', session.trainingType),
                    if (session.avgHeartRate != null)
                      _buildInfoRow('Avg HR', '${session.avgHeartRate} bpm'),
                    if (session.maxHeartRate != null)
                      _buildInfoRow('Max HR', '${session.maxHeartRate} bpm'),
                    if (session.minHeartRate != null)
                      _buildInfoRow('Min HR', '${session.minHeartRate} bpm'),
                    if (session.calories != null)
                      _buildInfoRow('Calories', '${session.calories?.toStringAsFixed(1)} kcal'),
                    if (session.distance != null)
                      _buildInfoRow('Distance', '${session.distance?.toStringAsFixed(2)} km'),
                    if (session.notes != null && session.notes!.isNotEmpty)
                      _buildInfoRow('Notes', session.notes!),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Data Processing Controls
            if (session.heartRateData.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Processing',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Trim warmup/cooldown'),
                        subtitle: _trimEnabled
                            ? Text('Warmup: ${_warmupSec}s | Cooldown: ${_cooldownSec}s')
                            : null,
                        value: _trimEnabled,
                        onChanged: (v) => setState(() => _trimEnabled = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_trimEnabled) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildSlider('Warmup', _warmupSec, 0, 300, (v) {
                                setState(() => _warmupSec = v.round());
                              }),
                            ),
                            Expanded(
                              child: _buildSlider('Cooldown', _cooldownSec, 0, 300, (v) {
                                setState(() => _cooldownSec = v.round());
                              }),
                            ),
                          ],
                        ),
                      ],
                      SwitchListTile(
                        title: const Text('Noise filter'),
                        subtitle: const Text('Remove HR spikes'),
                        value: _noiseFilter,
                        onChanged: (v) => setState(() => _noiseFilter = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_trimEnabled || _noiseFilter)
                        Text(
                          'After processing: Avg ${processedStats.avgHR} bpm | '
                          'Max ${processedStats.maxHR} bpm | Min ${processedStats.minHR} bpm',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Training Load Card
              _buildTrainingLoadCard(),

              // HRV Analysis Card
              _buildHrvCard(),

              // Heart Rate Chart
              Text(
                'Heart Rate Over Time',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 300,
                    child: _buildHeartRateChart(),
                  ),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No heart rate data available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, int value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value}s', style: const TextStyle(fontSize: 12)),
        Slider(
          value: value.toDouble(),
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTrainingLoadCard() {
    if (session.avgHeartRate == null) return const SizedBox.shrink();
    final p = _person;
    final maxHR = p?.maxHeartRate ?? 190;
    final restHR = p?.restingHeartRate ?? 60;
    final gender = p?.gender ?? 'male';

    final trimpVal = TrainingLoad.trimp(
      avgHR: session.avgHeartRate!,
      durationSeconds: session.duration,
      maxHR: maxHR,
      restingHR: restHR,
      gender: gender,
    );
    final intensity = TrainingLoad.intensity(trimpVal);
    final recovery = TrainingLoad.recoveryHours(trimpVal);
    final vo2max = TrainingLoad.estimateVO2Max(p?.maxHeartRate, p?.restingHeartRate);
    final vo2cat = vo2max != null && p != null
        ? TrainingLoad.vo2MaxCategory(vo2max, p.age, p.gender)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Training Load',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [
                _buildHrvMetric('TRIMP', trimpVal.toStringAsFixed(1)),
                _buildHrvMetric('Intensity', intensity),
                _buildHrvMetric('Recovery', '${recovery}h'),
              ]),
              if (vo2max != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  _buildHrvMetric('VO2 Max', '${vo2max.toStringAsFixed(1)} ml/kg/min'),
                  if (vo2cat != null) _buildHrvMetric('Fitness', vo2cat),
                  const Expanded(child: SizedBox()),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHrvCard() {
    // Extract RR intervals from consecutive HR data timestamps
    // Real RR intervals come from BLE; this approximates from HR values
    if (session.heartRateData.length < 10) return const SizedBox.shrink();

    final rrIntervals = session.heartRateData
        .where((d) => d.heartRate > 30 && d.heartRate < 220)
        .map((d) => (60000 / d.heartRate).round()) // Convert BPM to ms interval
        .toList();

    if (rrIntervals.length < 10) return const SizedBox.shrink();

    final hrv = HrvAnalysis.analyze(rrIntervals);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HRV Analysis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildHrvMetric('RMSSD', '${hrv.rmssd.toStringAsFixed(1)} ms'),
                  _buildHrvMetric('SDNN', '${hrv.sdnn.toStringAsFixed(1)} ms'),
                  _buildHrvMetric('pNN50', '${hrv.pnn50.toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildHrvMetric('Mean RR', '${hrv.meanRR.toStringAsFixed(0)} ms'),
                  _buildHrvMetric('Stress', hrv.stressLevel),
                  _buildHrvMetric('Valid', '${hrv.validIntervals}/${hrv.totalIntervals}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHrvMetric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateChart() {
    final data = List<HeartRateData>.from(_processedData);
    if (data.isEmpty) return const SizedBox.shrink();

    // Sort data by timestamp
    data.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final startTime = data.first.timestamp;
    final spots = data.map((hrData) {
      final x = hrData.timestamp.difference(startTime).inSeconds.toDouble();
      final y = hrData.heartRate.toDouble();
      return FlSpot(x, y);
    }).toList();

    final minY = data.map((d) => d.heartRate).reduce((a, b) => a < b ? a : b).toDouble() - 10;
    final maxY = data.map((d) => d.heartRate).reduce((a, b) => a > b ? a : b).toDouble() + 10;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 20,
          verticalInterval: 60,
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 120, // Show every 2 minutes
              getTitlesWidget: (value, meta) {
                final minutes = (value / 60).round();
                return Text(
                  '${minutes}m',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        minX: 0,
        maxX: spots.isNotEmpty ? spots.last.x : 0,
        minY: minY < 0 ? 0 : minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final minutes = (spot.x / 60).round();
                final seconds = (spot.x % 60).round();
                final timeStr = seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
                return LineTooltipItem(
                  '$timeStr\n${spot.y.toInt()} bpm',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }
}
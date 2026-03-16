import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/training_session.dart';

class SessionVisualizationScreen extends StatelessWidget {
  final TrainingSession session;

  const SessionVisualizationScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
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

            const SizedBox(height: 24),

            // Heart Rate Chart
            if (session.heartRateData.isNotEmpty) ...[
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
    final data = session.heartRateData;
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
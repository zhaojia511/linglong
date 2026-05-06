import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../models/readiness_measurement.dart';
import '../services/database_service.dart';
import '../services/hrv_service.dart';
import '../utils/timezone_utils.dart';

class ReadinessHistoryScreen extends StatefulWidget {
  final Person? initialAthlete;

  const ReadinessHistoryScreen({super.key, this.initialAthlete});

  @override
  State<ReadinessHistoryScreen> createState() => _ReadinessHistoryScreenState();
}

class _ReadinessHistoryScreenState extends State<ReadinessHistoryScreen> {
  static const Map<String, int?> _rangeOptions = {
    '7d': 7,
    '28d': 28,
    '60d': 60,
    'All': null,
  };

  String _selectedRange = '60d';

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final persons = {
      for (final person in db.getAllPersons()) person.id: person
    };

    return AnimatedBuilder(
      animation: HrvService.instance,
      builder: (context, child) {
        final allMeasurements = HrvService.instance.getAllReadinessMeasurements(
          days: _rangeOptions[_selectedRange],
        );
        final filtered = widget.initialAthlete == null
            ? allMeasurements
            : allMeasurements
                .where((measurement) =>
                    measurement.personId == widget.initialAthlete!.id)
                .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.initialAthlete == null
                ? 'Readiness History'
                : '${widget.initialAthlete!.name} Readiness'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _rangeOptions.keys.map((label) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _selectedRange == label,
                          onSelected: (_) {
                            setState(() {
                              _selectedRange = label;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const _EmptyReadinessHistory()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final measurement = filtered[index];
                          final person = persons[measurement.personId];
                          return _ReadinessMeasurementCard(
                            measurement: measurement,
                            person: person,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyReadinessHistory extends StatelessWidget {
  const _EmptyReadinessHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No readiness measurements yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ReadinessMeasurementCard extends StatelessWidget {
  final ReadinessMeasurement measurement;
  final Person? person;

  const _ReadinessMeasurementCard({
    required this.measurement,
    required this.person,
  });

  @override
  Widget build(BuildContext context) {
    final readiness = measurement.readinessPct;
    final readinessScore = readiness == null
        ? null
        : ReadinessScore(
            percent: readiness,
            baseline: measurement.rmssd,
            currentRmssd: measurement.rmssd,
          );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: readinessScore?.color.withValues(alpha: 0.16) ??
              Colors.grey.shade200,
          child: Icon(
            Icons.monitor_heart,
            color: readinessScore?.color ?? Colors.grey.shade700,
          ),
        ),
        title: Text(person?.name ?? 'Unknown athlete'),
        subtitle: Text(
          '${TimezoneUtils.formatDateTime(measurement.measuredAt)} • '
          'RMSSD ${measurement.rmssd.toStringAsFixed(1)} ms • '
          'RHR ${measurement.restingHR?.toString() ?? '--'} bpm',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              readiness == null
                  ? 'No baseline'
                  : '${readiness.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: readinessScore?.color,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              measurement.synced ? Icons.cloud_done : Icons.cloud_off,
              size: 16,
              color: measurement.synced ? Colors.green : Colors.grey,
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReadinessMeasurementDetailScreen(
                measurement: measurement,
                person: person,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ReadinessMeasurementDetailScreen extends StatelessWidget {
  final ReadinessMeasurement measurement;
  final Person? person;

  const ReadinessMeasurementDetailScreen({
    super.key,
    required this.measurement,
    this.person,
  });

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete measurement'),
            content: const Text(
              'Are you sure you want to delete this readiness measurement?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    await HrvService.instance.deleteReadinessMeasurement(measurement.id);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Readiness measurement deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final readiness = measurement.readinessPct;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Readiness Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person?.name ?? 'Unknown athlete',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(TimezoneUtils.formatDateTime(measurement.measuredAt)),
                  const SizedBox(height: 8),
                  Text('Device: ${measurement.deviceId}'),
                  Text('Duration: ${measurement.durationSec}s'),
                  Text(
                    readiness == null
                        ? 'Readiness: No baseline yet'
                        : 'Readiness: ${readiness.toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetricSection(
            title: 'Metrics',
            items: [
              _MetricItem(
                  'RMSSD', '${measurement.rmssd.toStringAsFixed(1)} ms'),
              _MetricItem('SDNN', '${measurement.sdnn.toStringAsFixed(1)} ms'),
              _MetricItem('pNN50', '${measurement.pnn50.toStringAsFixed(1)} %'),
              _MetricItem(
                  'Mean RR', '${measurement.meanRR.toStringAsFixed(1)} ms'),
              _MetricItem('SD1', '${measurement.sd1.toStringAsFixed(1)} ms'),
              _MetricItem('SD2', '${measurement.sd2.toStringAsFixed(1)} ms'),
              _MetricItem('Resting HR',
                  '${measurement.restingHR?.toString() ?? '--'} bpm'),
              _MetricItem(
                  'Quality', '${measurement.qualityPct.toStringAsFixed(0)} %'),
              _MetricItem(
                  'Feeling', measurement.feelingScore?.toString() ?? '--'),
              _MetricItem('Intervals', '${measurement.rrIntervals.length}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  final String title;
  final List<_MetricItem> items;

  const _MetricSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label)),
                    Text(item.value,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;

  const _MetricItem(this.label, this.value);
}

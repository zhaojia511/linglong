import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hr_device.dart';
import '../models/person.dart';
import '../services/ble_service.dart';
import '../services/database_service.dart';
import '../services/hrv_service.dart';
import '../utils/hrv_analysis.dart';

/// Resting HRV readiness measurement screen.
/// Flow: Setup → Measurement (countdown + live RR capture) → Results + Feeling score
class ReadinessScreen extends StatefulWidget {
  /// Pre-select athlete if launched from a profile row.
  final Person? initialAthlete;

  const ReadinessScreen({super.key, this.initialAthlete});

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

enum _Phase { setup, measuring, results }

class _ReadinessScreenState extends State<ReadinessScreen> {
  _Phase _phase = _Phase.setup;

  // Setup choices
  Person? _selectedAthlete;
  HRDevice? _selectedSensor;
  int _durationMinutes = 3; // default 3 min per Kubios standard

  // Measurement state
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  final List<int> _accumulatedRR = [];
  List<int> _lastKnownRR = [];
  int? _liveHR;

  // Results
  HrvResult? _result;
  int? _feelingScore; // 1–5

  @override
  void initState() {
    super.initState();
    _selectedAthlete = widget.initialAthlete;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Measurement logic ──────────────────────────────────────────────────────

  void _startMeasurement() {
    if (_selectedAthlete == null || _selectedSensor == null) return;
    _accumulatedRR.clear();
    _lastKnownRR.clear();

    setState(() {
      _phase = _Phase.measuring;
      _remainingSeconds = _durationMinutes * 60;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final bleService = Provider.of<BLEService>(context, listen: false);
      // Find the sensor — it may have new RR data each tick
      final device = bleService.connectedDevices.firstWhere(
          (d) => d.id == _selectedSensor!.id,
          orElse: () => _selectedSensor!);

      // Accumulate new RR intervals (avoid double-counting duplicates)
      if (device.rrIntervals != null && device.rrIntervals!.isNotEmpty) {
        if (!_listEquals(device.rrIntervals!, _lastKnownRR)) {
          _lastKnownRR = List<int>.from(device.rrIntervals!);
          _accumulatedRR.addAll(device.rrIntervals!);
        }
      }

      setState(() {
        _liveHR = device.currentHeartRate;
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _finishMeasurement();
      }
    });
  }

  void _finishMeasurement() {
    _countdownTimer?.cancel();
    if (_accumulatedRR.length < 20) {
      // Too few intervals — go back to setup with error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Not enough RR data. Make sure the sensor supports HRV and is worn correctly.'),
          backgroundColor: Colors.orange,
        ));
        setState(() => _phase = _Phase.setup);
      }
      return;
    }

    final result = HrvAnalysis.analyze(_accumulatedRR);
    setState(() {
      _result = result;
      _phase = _Phase.results;
    });
  }

  Future<void> _saveResult() async {
    if (_result == null ||
        _selectedAthlete == null ||
        _selectedSensor == null) {
      return;
    }
    // Save HRV snapshot via HrvService
    final saved = await HrvService.instance.saveReadinessSnapshot(
      personId: _selectedAthlete!.id,
      deviceId: _selectedSensor!.id,
      rrIntervals: _accumulatedRR,
      durationSec: _durationMinutes * 60,
      restingHR: _liveHR,
      feelingScore: _feelingScore,
    );
    if (!saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Measurement could not be saved. Try again with cleaner RR data.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Readiness measurement saved'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Readiness Measurement'),
        leading: _phase == _Phase.measuring
            ? const SizedBox.shrink() // disable back during measurement
            : null,
      ),
      body: switch (_phase) {
        _Phase.setup => _buildSetup(),
        _Phase.measuring => _buildMeasuring(),
        _Phase.results => _buildResults(),
      },
    );
  }

  // ── Setup phase ────────────────────────────────────────────────────────────

  Widget _buildSetup() {
    final athletes = DatabaseService.instance.getAthletes();
    final bleService = Provider.of<BLEService>(context);
    final connectedSensors =
        bleService.connectedDevices.where((d) => d.isConnected).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Instructions card
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Instructions',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ]),
                const SizedBox(height: 8),
                const Text(
                  '1. Sit or lie still and relax\n'
                  '2. Breathe normally — do not control your breathing\n'
                  '3. Wear the chest strap snugly and make sure it is reading\n'
                  '4. Measure at the same time each day (ideally morning)',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Athlete selection
        Text('Athlete', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (athletes.isEmpty)
          const Text('No athletes. Add athletes in the Profile tab.',
              style: TextStyle(color: Colors.grey))
        else
          DropdownButtonFormField<Person>(
            initialValue: _selectedAthlete,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text('Select athlete'),
            items: athletes
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a.name),
                    ))
                .toList(),
            onChanged: (a) => setState(() => _selectedAthlete = a),
          ),
        const SizedBox(height: 20),

        // Sensor selection
        Text('Heart Rate Sensor',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (connectedSensors.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No sensors connected. Connect a chest strap in the Dashboard.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ]),
          )
        else
          DropdownButtonFormField<HRDevice>(
            initialValue: _selectedSensor != null &&
                    connectedSensors.any((d) => d.id == _selectedSensor!.id)
                ? connectedSensors
                    .firstWhere((d) => d.id == _selectedSensor!.id)
                : null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text('Select sensor'),
            items: connectedSensors
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.name),
                    ))
                .toList(),
            onChanged: (d) => setState(() => _selectedSensor = d),
          ),
        const SizedBox(height: 20),

        // Duration selection
        Text('Measurement Duration',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1 min')),
            ButtonSegment(value: 2, label: Text('2 min')),
            ButtonSegment(value: 3, label: Text('3 min')),
          ],
          selected: {_durationMinutes},
          onSelectionChanged: (s) => setState(() => _durationMinutes = s.first),
        ),
        const SizedBox(height: 8),
        Text(
          _durationMinutes == 3
              ? 'Recommended — gives best HRV accuracy'
              : _durationMinutes == 2
                  ? 'Good — acceptable for daily tracking'
                  : 'Short — minimum for a rough estimate',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),

        // Start button
        FilledButton.icon(
          onPressed: (_selectedAthlete != null && _selectedSensor != null)
              ? _startMeasurement
              : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Measurement'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }

  // ── Measuring phase ────────────────────────────────────────────────────────

  Widget _buildMeasuring() {
    final totalSeconds = _durationMinutes * 60;
    final elapsed = totalSeconds - _remainingSeconds;
    final progress = elapsed / totalSeconds;
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final rrCount = _accumulatedRR.length;
    final liveRmssd = rrCount >= 20 ? HrvAnalysis.rmssd(_accumulatedRR) : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _selectedAthlete!.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Stay still and breathe normally',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 40),

          // Countdown ring
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[200],
                    color: _progressColor(progress),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                    const Text('remaining',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Live stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LiveStatCard(
                label: 'Heart Rate',
                value: _liveHR != null ? '${_liveHR!} bpm' : '--',
                icon: Icons.favorite,
              ),
              _LiveStatCard(
                label: 'RMSSD',
                value: liveRmssd != null
                    ? '${liveRmssd.toStringAsFixed(1)} ms'
                    : '...',
                icon: Icons.show_chart,
              ),
              _LiveStatCard(
                label: 'RR collected',
                value: '$rrCount',
                icon: Icons.timeline,
              ),
            ],
          ),
          const SizedBox(height: 32),

          TextButton(
            onPressed: () {
              _countdownTimer?.cancel();
              setState(() => _phase = _Phase.setup);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Color _progressColor(double progress) {
    if (progress < 0.5) return Colors.orange;
    if (progress < 0.8) return Colors.lightBlue;
    return Colors.green;
  }

  // ── Results phase ──────────────────────────────────────────────────────────

  Widget _buildResults() {
    final r = _result!;
    final qualityPct =
        (min(r.validIntervals, 500) / 500 * 100).clamp(0.0, 100.0);
    final baseline = _selectedAthlete != null
        ? HrvService.instance.getBaseline(_selectedAthlete!.id)
        : null;
    final readinessPct = (baseline != null && baseline > 0)
        ? (r.rmssd / baseline * 100).clamp(0.0, 150.0)
        : null;

    return Column(
      children: [
        // Scrollable metrics area
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            children: [
              // Header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_selectedAthlete!.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '$_durationMinutes min measurement · ${r.validIntervals} RR intervals',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (readinessPct != null) ...[
                        const SizedBox(height: 12),
                        _ReadinessBadge(readinessPct),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // HRV metrics grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  _MetricCard(
                      label: 'RMSSD',
                      value: '${r.rmssd.toStringAsFixed(1)} ms',
                      subtitle: 'Parasympathetic activity'),
                  _MetricCard(
                      label: 'SDNN',
                      value: '${r.sdnn.toStringAsFixed(1)} ms',
                      subtitle: 'Overall HRV'),
                  _MetricCard(
                      label: 'pNN50',
                      value: '${r.pnn50.toStringAsFixed(1)}%',
                      subtitle: 'Vagal tone'),
                  _MetricCard(
                      label: 'Mean RR',
                      value: '${r.meanRR.toStringAsFixed(0)} ms',
                      subtitle:
                          '≈ ${(60000 / r.meanRR).toStringAsFixed(0)} bpm rest'),
                  _MetricCard(
                      label: 'SD1',
                      value: '${r.sd1.toStringAsFixed(1)} ms',
                      subtitle: 'Short-term variability'),
                  _MetricCard(
                      label: 'Quality',
                      value: '${qualityPct.toStringAsFixed(0)}%',
                      subtitle: '${r.validIntervals} valid intervals'),
                ],
              ),
              const SizedBox(height: 20),

              // Feeling score
              Text('How do you feel today?',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                _selectedAthlete!.name,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final score = i + 1;
                  final labels = ['Very Bad', 'Bad', 'OK', 'Good', 'Very Good'];
                  final emojis = ['😞', '😕', '😐', '🙂', '😄'];
                  final selected = _feelingScore == score;
                  return GestureDetector(
                    onTap: () => setState(() => _feelingScore = score),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2)
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Column(
                        children: [
                          Text(emojis[i],
                              style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 2),
                          Text(labels[i],
                              style: TextStyle(
                                  fontSize: 10,
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[600],
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        // Sticky bottom action bar — always visible, never scrolled away
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _saveResult,
                icon: const Icon(Icons.save),
                label: const Text('Save Result'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() {
                  _phase = _Phase.setup;
                  _result = null;
                  _feelingScore = null;
                }),
                child:
                    const Text('Measure Again'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _LiveStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _LiveStatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _MetricCard(
      {required this.label, required this.value, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ReadinessBadge extends StatelessWidget {
  final double pct;

  const _ReadinessBadge(this.pct);

  Color get _color {
    if (pct >= 90) return Colors.green;
    if (pct >= 75) return Colors.lightBlue;
    if (pct >= 60) return Colors.orange;
    return Colors.red;
  }

  String get _label {
    if (pct >= 90) return 'High Readiness';
    if (pct >= 75) return 'Normal';
    if (pct >= 60) return 'Reduced';
    return 'Low Readiness';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: _color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Readiness',
                  style: TextStyle(
                      fontSize: 10,
                      color: _color,
                      fontWeight: FontWeight.w600)),
              Text(_label,
                  style: TextStyle(
                      fontSize: 12,
                      color: _color,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/hr_device.dart';
import '../models/person.dart';
import 'dashboard_screen.dart';

class AthleteDetailScreen extends StatelessWidget {
  final HRDevice device;
  final Person? athlete;
  final List<HeartRateDataPoint> hrHistory;
  final List<int>? zoneSecs;

  static const _zoneColors = [
    Color(0xFF4FC3F7),
    Color(0xFF66BB6A),
    Color(0xFFFDD835),
    Color(0xFFFF7043),
    Color(0xFFE53935),
  ];
  static const _zoneNames = ['Recovery', 'Aerobic', 'Tempo', 'Threshold', 'Anaerobic'];

  const AthleteDetailScreen({
    super.key,
    required this.device,
    required this.athlete,
    required this.hrHistory,
    this.zoneSecs,
  });

  Color get _zoneColor {
    final hr = device.currentHeartRate;
    if (hr == null) return const Color(0xFF757575);
    if (hr < 120) return _zoneColors[0];
    if (hr < 150) return _zoneColors[1];
    if (hr < 170) return _zoneColors[2];
    if (hr < 190) return _zoneColors[3];
    return _zoneColors[4];
  }

  double? _computeRmssd(List<int>? rr) {
    if (rr == null || rr.length < 2) return null;
    double sumSq = 0;
    for (int i = 1; i < rr.length; i++) {
      final d = (rr[i] - rr[i - 1]).toDouble();
      sumSq += d * d;
    }
    return math.sqrt(sumSq / (rr.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final bg = _zoneColor;
    final isDark = bg == const Color(0xFFFDD835);
    final textColor = isDark ? Colors.black87 : Colors.white;
    final subColor = isDark ? Colors.black54 : Colors.white70;
    final rmssd = _computeRmssd(device.rrIntervals);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.black26,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(athlete?.name ?? device.name,
            style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large BPM + zone name
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    device.currentHeartRate?.toString() ?? '--',
                    style: TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('bpm', style: TextStyle(fontSize: 20, color: subColor)),
                        Text(
                          _zoneName(device.currentHeartRate),
                          style: TextStyle(
                              fontSize: 16,
                              color: textColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Stats row: HRV, battery, signal
              Row(
                children: [
                  if (rmssd != null) ...[
                    _statChip(
                      label: 'HRV',
                      value: '${rmssd.toStringAsFixed(0)}ms',
                      dotColor: rmssd >= 40
                          ? Colors.greenAccent
                          : rmssd >= 20
                              ? Colors.yellowAccent
                              : Colors.redAccent,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (device.batteryLevel != null) ...[
                    _statChip(
                      label: 'Battery',
                      value: '${device.batteryLevel}%',
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    const SizedBox(width: 16),
                  ],
                  _statChip(
                    label: 'Signal',
                    value: '${device.rssi} dBm',
                    textColor: textColor,
                    subColor: subColor,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // HR sparkline — full width
              if (hrHistory.length >= 2) ...[
                Text('Heart Rate (last 60s)',
                    style: TextStyle(fontSize: 13, color: subColor)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 100,
                  child: CustomPaint(
                    size: const Size(double.infinity, 100),
                    painter: _DetailSparklinePainter(
                      points: hrHistory,
                      color: textColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Zone bars with labels
              if (zoneSecs != null && zoneSecs!.fold(0, (a, b) => a + b) > 0) ...[
                Text('Time in Zone',
                    style: TextStyle(fontSize: 13, color: subColor)),
                const SizedBox(height: 8),
                _buildZoneBars(textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _zoneName(int? hr) {
    if (hr == null) return 'Rest';
    if (hr < 120) return 'Recovery';
    if (hr < 150) return 'Aerobic';
    if (hr < 170) return 'Tempo';
    if (hr < 190) return 'Threshold';
    return 'Anaerobic';
  }

  Widget _statChip({
    required String label,
    required String value,
    Color? dotColor,
    required Color textColor,
    required Color subColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: subColor)),
        Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildZoneBars(Color textColor) {
    final secs = zoneSecs!;
    final total = secs.fold(0, (a, b) => a + b);
    return Column(
      children: List.generate(5, (i) {
        if (secs[i] == 0) return const SizedBox.shrink();
        final pct = secs[i] / total;
        final mins = secs[i] ~/ 60;
        final s = secs[i] % 60;
        final timeStr = mins > 0 ? '${mins}m ${s}s' : '${s}s';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(_zoneNames[i],
                    style: TextStyle(fontSize: 12, color: textColor)),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: _zoneColors[i].withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Text(timeStr,
                    style: TextStyle(fontSize: 11, color: textColor),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _DetailSparklinePainter extends CustomPainter {
  final List<HeartRateDataPoint> points;
  final Color color;

  _DetailSparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minVal = points.map((p) => p.value).reduce(math.min);
    final maxVal = points.map((p) => p.value).reduce(math.max);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    // Faint fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i / (points.length - 1) * size.width;
      final y = size.height - ((points[i].value - minVal) / range) * size.height * 0.85 - size.height * 0.05;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Min/max labels
    final labelStyle = TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10);
    _drawLabel(canvas, '${maxVal.toInt()}', 4, 2, labelStyle, size);
    _drawLabel(canvas, '${minVal.toInt()}', 4, size.height - 14, labelStyle, size);
  }

  void _drawLabel(Canvas canvas, String text, double x, double y,
      TextStyle style, Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_DetailSparklinePainter old) => old.points != points;
}

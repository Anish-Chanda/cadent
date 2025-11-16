import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// Simple, dependency-free charts implemented with CustomPainter.
/// Supports basic elevation and pace/speed area-line sparklines.
class ActivityCharts extends StatefulWidget {
  final List<double>? elevationSamples;
  final List<double>? paceSamples;
  final List<DateTime>? elevationTimestamps;
  final List<DateTime>? paceTimestamps;

  const ActivityCharts({
    super.key,
    this.elevationSamples,
    this.paceSamples,
    this.elevationTimestamps,
    this.paceTimestamps,
  });

  @override
  State<ActivityCharts> createState() => _ActivityChartsState();
}

class _ActivityChartsState extends State<ActivityCharts> {
  bool _showElevation = true;
  bool _showSpeed = true;

  bool get _hasElevation => widget.elevationSamples != null && widget.elevationSamples!.length > 1;
  bool get _hasSpeed => widget.paceSamples != null && widget.paceSamples!.length > 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Performance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Elevation'),
                  selected: _showElevation,
                  onSelected: (v) {
                    setState(() {
                      _showElevation = v;
                      if (!_showElevation && !_showSpeed) _showSpeed = true; // ensure one shown
                    });
                  },
                  selectedColor: Colors.orange.shade100,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Speed'),
                  selected: _showSpeed,
                  onSelected: (v) {
                    setState(() {
                      _showSpeed = v;
                      if (!_showElevation && !_showSpeed) _showElevation = true;
                    });
                  },
                  selectedColor: Colors.blue.shade100,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!_hasElevation && !_hasSpeed)
          _buildPlaceholder(context, 'No streams available')
        else
          _buildCombinedChart(context),
      ],
    );
  }

  Widget _buildCombinedChart(BuildContext context) {
    final elevation = widget.elevationSamples ?? [];
    final speed = widget.paceSamples ?? [];
    final timestamps = widget.elevationTimestamps ?? widget.paceTimestamps;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _CombinedPainter(
                elevation: elevation,
                speed: speed,
                timestamps: timestamps,
                showElevation: _showElevation,
                showSpeed: _showSpeed,
                textDirection: Directionality.of(context),
              ),
              size: const Size(double.infinity, 160),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart, size: 28, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                const SizedBox(height: 6),
                Text(
                  'No time-series samples available for $title.\nProvide a list of samples to render a chart.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomChart(BuildContext context, List<double> samples, List<DateTime>? timestamps, Color color, String label) {
    return const SizedBox.shrink();
  }
}

// keep old single-series painter unused; combined painter implemented below
// Combined painter draws elevation (left axis) and speed (right axis) when enabled.
class _CombinedPainter extends CustomPainter {
  final List<double> elevation;
  final List<double> speed;
  final List<DateTime>? timestamps;
  final bool showElevation;
  final bool showSpeed;
  final TextDirection textDirection;

  _CombinedPainter({
    required this.elevation,
    required this.speed,
    this.timestamps,
    required this.showElevation,
    required this.showSpeed,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = 44.0;
    final rightPad = 44.0; // leave room for right axis labels
    final topPad = 8.0;
    final bottomPad = 24.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    // Draw grids or background if desired

    // Draw elevation (left axis)
    if (showElevation && elevation.isNotEmpty) {
      final minE = elevation.reduce((a, b) => a < b ? a : b);
      final maxE = elevation.reduce((a, b) => a > b ? a : b);
      final padE = (maxE - minE) * 0.05;
      final minEP = minE - padE;
      final maxEP = maxE + padE;
      final rangeE = (maxEP - minEP) == 0 ? 1 : (maxEP - minEP);

      final paintEFill = Paint()..color = Colors.orange.shade100.withOpacity(0.9);
      final paintELine = Paint()
        ..color = Colors.orange.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true;

      final pathE = Path();
      final fillE = Path();

      for (var i = 0; i < elevation.length; i++) {
        final dx = leftPad + (i / (elevation.length - 1)) * chartWidth;
        final normalized = (elevation[i] - minEP) / rangeE;
        final dy = topPad + (1 - normalized) * chartHeight;
        if (i == 0) {
          pathE.moveTo(dx, dy);
          fillE.moveTo(dx, topPad + chartHeight);
          fillE.lineTo(dx, dy);
        } else {
          pathE.lineTo(dx, dy);
          fillE.lineTo(dx, dy);
        }
      }
      fillE.lineTo(leftPad + chartWidth, topPad + chartHeight);
      fillE.close();

      canvas.drawPath(fillE, paintEFill);
      canvas.drawPath(pathE, paintELine);

      // left axis labels
      final labelStyle = TextStyle(color: Colors.grey[700], fontSize: 11);
      _drawYAxisLabel(canvas, leftPad, '${maxEP.toStringAsFixed(1)}', topPad, labelStyle, alignLeft: false);
      _drawYAxisLabel(canvas, leftPad, '${minEP.toStringAsFixed(1)}', topPad + chartHeight, labelStyle, alignLeft: false);
    }

    // Draw speed (right axis)
    if (showSpeed && speed.isNotEmpty) {
      final minS = speed.reduce((a, b) => a < b ? a : b);
      final maxS = speed.reduce((a, b) => a > b ? a : b);
      final padS = (maxS - minS) * 0.05;
      final minSP = minS - padS;
      final maxSP = maxS + padS;
      final rangeS = (maxSP - minSP) == 0 ? 1 : (maxSP - minSP);

      final paintSLine = Paint()
        ..color = Colors.blue.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true;

      final pathS = Path();
      for (var i = 0; i < speed.length; i++) {
        final dx = leftPad + (i / (speed.length - 1)) * chartWidth;
        final normalized = (speed[i] - minSP) / rangeS;
        final dy = topPad + (1 - normalized) * chartHeight;
        if (i == 0) {
          pathS.moveTo(dx, dy);
        } else {
          pathS.lineTo(dx, dy);
        }
      }

      canvas.drawPath(pathS, paintSLine);

      // right axis labels
      final labelStyle = TextStyle(color: Colors.grey[700], fontSize: 11);
      _drawYAxisLabel(canvas, size.width - rightPad + 6, '${maxSP.toStringAsFixed(1)}', topPad, labelStyle, alignLeft: true);
      _drawYAxisLabel(canvas, size.width - rightPad + 6, '${minSP.toStringAsFixed(1)}', topPad + chartHeight, labelStyle, alignLeft: true);
    }

    // X axis labels
    if (timestamps != null && timestamps!.isNotEmpty) {
      final fmt = intl.DateFormat('HH:mm:ss');
      final start = timestamps!.first;
      final middle = timestamps![(timestamps!.length - 1) ~/ 2];
      final end = timestamps!.last;

      _drawXAxisLabel(canvas, Offset(leftPad, topPad + chartHeight + 6), fmt.format(start), chartWidth, TextStyle(color: Colors.grey[600], fontSize: 11));
      _drawXAxisLabel(canvas, Offset(leftPad + chartWidth / 2, topPad + chartHeight + 6), fmt.format(middle), chartWidth, TextStyle(color: Colors.grey[600], fontSize: 11), center: true);
      _drawXAxisLabel(canvas, Offset(leftPad + chartWidth, topPad + chartHeight + 6), fmt.format(end), chartWidth, TextStyle(color: Colors.grey[600], fontSize: 11), alignRight: true);
    } else {
      // fallback indices
      final start = '0';
      final middle = '${((elevation.isNotEmpty ? elevation.length : speed.length) / 2).round()}';
      final end = '${((elevation.isNotEmpty ? elevation.length : speed.length) - 1)}';
      final baseY = topPad + chartHeight + 6;
      _drawXAxisLabel(canvas, Offset(leftPad, baseY), start, chartWidth, TextStyle(color: Colors.grey[600], fontSize: 11));
      _drawXAxisLabel(canvas, Offset(leftPad + chartWidth / 2, baseY), middle, chartWidth, TextStyle(color: Colors.grey[600], fontSize: 11), center: true);
      _drawXAxisLabel(canvas, Offset(leftPad + chartWidth, baseY), end, chartWidth, TextStyle(color: Colors.grey[600], fontSize: 11), alignRight: true);
    }
  }

  void _drawYAxisLabel(Canvas canvas, double x, String text, double y, TextStyle style, {bool alignLeft = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
    );
    tp.layout();
    final dx = alignLeft ? x : x - tp.width;
    tp.paint(canvas, Offset(dx, y - tp.height / 2));
  }

  void _drawXAxisLabel(Canvas canvas, Offset pos, String text, double maxWidth, TextStyle style, {bool center = false, bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
    );
    tp.layout(minWidth: 0, maxWidth: maxWidth / 2);
    double dx = pos.dx - (center ? tp.width / 2 : (alignRight ? tp.width : 0));
    tp.paint(canvas, Offset(dx, pos.dy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


import 'package:flutter/material.dart';
import '../utils/app_spacing.dart';
import '../utils/duration_formatter.dart';
 import '../models/streams.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';

/// Clean, single-file chart widget for activities.
/// - Uses `StreamsModel` when provided (distance in meters on X axis).
/// - Falls back to legacy samples/timestamps when `streams` is null.
class ActivityCharts extends StatefulWidget {
  final StreamsModel? streams;
  final List<double>? elevationSamples;
  final List<double>? paceSamples;
  final List<DateTime>? elevationTimestamps;
  final List<DateTime>? paceTimestamps;
  final List<double>? distanceSamples;
  
  const ActivityCharts({
    super.key,
    this.streams,
    this.elevationSamples,
    this.paceSamples,
    this.elevationTimestamps,
    this.paceTimestamps,
    this.distanceSamples,
  });

  @override
  State<ActivityCharts> createState() => _ActivityChartsState();
}

class _ActivityChartsState extends State<ActivityCharts> {
  bool _showDistance = true;
  // Interaction state for draggable scope/tooltip
  bool _draggingLine = false;
  bool _draggingSplits = false;
  String? _hoverChartId;
  Offset? _dragLocal;
  int? _hoverIndex;
  String? _hoverChart; // 'line' or 'splits'
  List<double>? _hoverXValues;
  List<double>? _hoverYValues;
  bool _hoverIsTime = false;
  String _hoverXLabel = '';
  String _hoverYLabel = '';
  late bool _isMetric;
  bool get isMetric => _isMetric;
  @override
  Widget build(BuildContext context) {
    _isMetric = context.select<AppSettingsProvider, bool>((p) => p.isMetric);
    if (widget.streams != null) return _buildFromStreams(context, widget.streams!);
    return _buildLegacy(context);
  }

  Widget _buildFromStreams(BuildContext context, StreamsModel s) {
    final elevations = s.numericSeries('elevation');
    final speeds = s.numericSeries('speed'); // km/h

    // Prefer an explicit distance series from the backend. Support several common keys.
    List<double> getDistanceSeries() {
      final candidates = ['distance', 'distance_total', 'distance_cumulative', 'dist', 'cumdist', 'distance_km'];
      for (final k in candidates) {
        if (s.streams.containsKey(k)) {
          final vals = s.numericSeries(k);
          if (vals.isEmpty) continue;
          if (k == 'distance_km') {
            return vals.map((v) => v * 1000.0)
      .toList();
          }
          return vals;
        }
      }
      // fallback to generic 'distance' name
      return s.numericSeries('distance');
    }

    final distances = getDistanceSeries(); // meters

    final hasElevation = elevations.isNotEmpty && distances.isNotEmpty;
    final hasSpeed = speeds.isNotEmpty && distances.isNotEmpty;

    final speedsDisplay = speeds.map((v) {
        final kph = v < 0 ? 0.0 : v * 3.6; // m/s -> km/h
        return isMetric ? kph : kph * 0.621371;
    }).toList(); // km/h or mph for display

    // splits now represent time per completed unit (km when metric, mi when imperial)
    final splitsAll = isMetric
        ? _calculateSplitsTimePerKm(distances, speeds)
        : _calculateSplitsTimePerMile(distances, speeds);

    final totalUnits = distances.isNotEmpty
        ? (isMetric
            ? (distances.last ~/ 1000) // still count whole kilometers for splits
            : (distances.last ~/ 1609))
        : 0;

final splits = totalUnits > 0 ? splitsAll.take(totalUnits).toList() : <double>[];

    // axis toggle (Distance / Time) - show when we have distance samples or time offsets

    // prepare x-values based on toggle. Prefer stream-provided time offsets
    // when switching to time mode so indices align with the Y-series samples.
    final timeOffsets = s.timeOffsetsSeconds();
    final xForCharts = _showDistance
        ? (isMetric ? distances.map((d) => d / 1000.0).toList() : distances.map((d) => d / 1609.34).toList())
        : (timeOffsets.isNotEmpty ? timeOffsets : _computeElapsedSecondsFromDistancesSpeeds(distances, speeds));

    final distanceUnit = isMetric ? 'km' : 'mi';
    final xLabelDist = _showDistance ? 'Distance ($distanceUnit)' : 'Time';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Performance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      AppSpacing.gapSM,
      if (!hasElevation && !hasSpeed) _buildPlaceholder(context, 'No streams available')
      else ...[
        if (distances.isNotEmpty || s.timeOffsetsSeconds().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ToggleButtons(
              isSelected: [_showDistance, !_showDistance],
              onPressed: (i) => setState(() => _showDistance = (i == 0)),
              borderRadius: BorderRadius.circular(6),
              selectedBorderColor: Theme.of(context).colorScheme.primary,
              fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              color: Theme.of(context).colorScheme.onSurface,
              selectedColor: Theme.of(context).colorScheme.primary,
              children: [Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('Distance')), Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('Time'))],
            ),
          ),
        if (hasElevation) _buildLineChartDistance(context, xForCharts, isMetric ? elevations : elevations.map((e) => e * 3.28084).toList(), Theme.of(context).colorScheme.secondary, isMetric ? 'Elevation (m)' : 'Elevation (ft)', xLabelDist, isMetric ? 'Elevation (m)' : 'Elevation (ft)', xIsTime: !_showDistance),
        if (hasSpeed) _buildLineChartDistance(context, xForCharts, speedsDisplay, Theme.of(context).colorScheme.primary, isMetric ? 'Speed (km/h)' : 'Speed (mph)', xLabelDist, 'Speed (${isMetric ? 'km/h' : 'mph'})', yMin: 0, xIsTime: !_showDistance),
        if (splits.isNotEmpty)
          _buildSplitsBarChart(
            context,
            splits,
            isMetric ? 'km' : 'mi',
            isMetric ? 'Time per km' : 'Time per mile',
            isTime: true,
          ),
      ]
    ]);
  }

  Widget _buildLegacy(BuildContext context) {
    final hasElevation = widget.elevationSamples != null && widget.elevationSamples!.length > 1;
    final hasSpeed = widget.paceSamples != null && widget.paceSamples!.length > 1;
    final timestamps = widget.elevationTimestamps ?? widget.paceTimestamps;
    final hasDistanceSamples = widget.distanceSamples != null && widget.distanceSamples!.length > 1;

    // If legacy distance samples are available, prefer rendering the distance/time toggle
    // and use the distance series as the x axis. Otherwise, fall back to legacy painter.
    if (hasDistanceSamples) {
      final distances = widget.distanceSamples!; // assumed meters
      // try to compute per-sample elapsed seconds from timestamps if available
      List<double> elapsedSecs = [];
      if (timestamps != null && timestamps.isNotEmpty) {
        elapsedSecs = timestamps.map((t) => t.difference(timestamps.first).inSeconds.toDouble())
      .toList();
      } else if (widget.paceSamples != null && widget.paceSamples!.isNotEmpty) {
        // paceSamples are expected in km/h for legacy mocks, convert to m/s
        final speedsMs = widget.paceSamples!.map((v) => v / 3.6)
      .toList();
        elapsedSecs = _computeElapsedSecondsFromDistancesSpeeds(distances, speedsMs);
      }

      final distanceUnit = isMetric ? 'km' : 'mi';
      final xForCharts = _showDistance
          ? (isMetric ? distances.map((d) => d / 1000.0).toList() : distances.map((d) => d / 1609.34).toList())
          : (elapsedSecs.isNotEmpty ? elapsedSecs : _computeElapsedSecondsFromDistancesSpeeds(distances, []));

      // Precompute legacy splits (one per completed unit) so we can reference
      // them from the widget children without executing statements inside
      // the collection literal (which Dart doesn't allow).
      List<double> splitsLegacy = [];
      if (hasSpeed && widget.paceSamples != null && widget.paceSamples!.isNotEmpty) {
        final speedsKmh = widget.paceSamples!; // assumed km/h
        final splitsAllLegacy = isMetric
            ? _calculateSplitsTimePerKm(distances, speedsKmh)
            : _calculateSplitsTimePerMile(distances, speedsKmh);
        final totalUnitsLegacy = distances.isNotEmpty
            ? (isMetric
                ? (distances.last ~/ 1000)
                : (distances.last ~/ 1609.34))
            : 0;
        splitsLegacy = totalUnitsLegacy > 0 ? splitsAllLegacy.take(totalUnitsLegacy).toList() : <double>[];
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Performance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapSM,
        if (!hasElevation && !hasSpeed) _buildPlaceholder(context, 'No streams available')
        else ...[
          // show the toggle when we have either distance or time offsets
          if (hasDistanceSamples || (timestamps != null && timestamps.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ToggleButtons(
                isSelected: [_showDistance, !_showDistance],
                onPressed: (i) => setState(() => _showDistance = (i == 0)),
                borderRadius: BorderRadius.circular(6),
                selectedBorderColor: Theme.of(context).colorScheme.primary,
                fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                color: Theme.of(context).colorScheme.onSurface,
                selectedColor: Theme.of(context).colorScheme.primary,
                children: [Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('Distance')), Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('Time'))],
              ),
            ),
          if (hasElevation) _buildLineChartDistance(context, xForCharts, widget.elevationSamples!, Theme.of(context).colorScheme.secondary, isMetric ? 'Elevation (m)' : 'Elevation (ft)', _showDistance
    ? 'Distance ($distanceUnit)'
    : 'Time', isMetric ? 'Elevation (m)' : 'Elevation (ft)', xIsTime: !_showDistance),
          if (hasSpeed) _buildLineChartDistance(context, xForCharts, widget.paceSamples!, Theme.of(context).colorScheme.primary, 'Speed (${isMetric ? 'km/h' : 'mph'})', _showDistance
    ? 'Distance ($distanceUnit)'
    : 'Time', 'Speed (${isMetric ? 'km/h' : 'mph'})', yMin: 0, xIsTime: !_showDistance),
          if (splitsLegacy.isNotEmpty)
            _buildSplitsBarChart(context, splitsLegacy, isMetric ? 'km' : 'mi', isMetric ? 'Time per km' : 'Time per mile', isTime: true),
        ]
      ]);
    }

    // fallback: no distance samples available, use legacy drawing by index/time
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Performance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      AppSpacing.gapSM,
      if (!hasElevation && !hasSpeed) _buildPlaceholder(context, 'No streams available')
      else ...[
        if (hasElevation) _buildLineChartLegacy(context, widget.elevationSamples!, timestamps, Theme.of(context).colorScheme.secondary, isMetric ? 'Elevation (m)' : 'Elevation (ft)'
),
        if (hasSpeed) _buildLineChartLegacy(context, widget.paceSamples!, timestamps, Theme.of(context).colorScheme.primary, 'Speed (${isMetric ? 'km/h' : 'mph'})'),
        if (hasSpeed) _buildSplitsBarChartLegacy(context, widget.paceSamples, timestamps),
      ]
    ]);
  }

  Widget _buildLineChartDistance(BuildContext context, List<double> xValues, List<double> yValues, Color color, String title, String xLabel, String yLabel, {double? yMin, bool xIsTime = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        AppSpacing.gapXS,
        SizedBox(
          height: 120,
          child: LayoutBuilder(builder: (ctx, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(details.globalPosition);
                _updateHoverForLine(local, box.size, xValues, yValues, xIsTime, xLabel, yLabel, title);
              },
              onPanUpdate: (details) {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(details.globalPosition);
                _updateHoverForLine(local, box.size, xValues, yValues, xIsTime, xLabel, yLabel, title);
              },
              onPanEnd: (_) {
                setState(() {
                  _draggingLine = false;
                });
              },
              onTapDown: (details) {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(details.globalPosition);
                _updateHoverForLine(local, box.size, xValues, yValues, xIsTime, xLabel, yLabel, title);
              },
              child: Stack(children: [
                CustomPaint(
                  painter: _SingleLinePainterDistance(
                    xValues: xValues,
                    yValues: yValues,
                    color: color,
                    textColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
                    textDirection: Directionality.of(context),
                    xLabel: xLabel,
                    yLabel: yLabel,
                    yMin: yMin,
                    labelYAxis: true,
                    xIsTime: xIsTime,
                  ),
                  size: Size(constraints.maxWidth, 120),
                ),
                if (_draggingLine && _hoverChartId == title && _dragLocal != null)
                  Positioned(left: _dragLocal!.dx - 1, top: 0, bottom: 0, child: Container(width: 2, color: Colors.black26)),
                if (_draggingLine && _hoverChartId == title && _dragLocal != null && _hoverIndex != null)
                  Positioned(left: (_dragLocal!.dx + 8).clamp(8.0, constraints.maxWidth - 120.0), top: 6, child: _buildMiniPopup(_hoverIndex!, _hoverXValues, _hoverYValues, _hoverIsTime, _hoverXLabel, _hoverYLabel)),
              ]),
            );
          }),
        ),
      ]),
    );
  }

  Widget _buildSplitsBarChart(BuildContext context, List<double> splits, String xLabel, String yLabel, {bool isTime = false}) {
    if (splits.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Splits ($xLabel)', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.tertiary)),
        AppSpacing.gapXS,
        SizedBox(
          height: 80,
          child: LayoutBuilder(builder: (ctx, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(details.globalPosition);
                _updateHoverForSplits(local, box.size, splits, isTime, xLabel, yLabel, xLabel);
              },
              onPanUpdate: (details) {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(details.globalPosition);
                _updateHoverForSplits(local, box.size, splits, isTime, xLabel, yLabel, xLabel);
              },
              onPanEnd: (_) {
                setState(() {
                  _draggingSplits = false;
                });
              },
              onTapDown: (details) {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(details.globalPosition);
                _updateHoverForSplits(local, box.size, splits, isTime, xLabel, yLabel, xLabel);
              },
              child: Stack(children: [
                CustomPaint(
                  painter: _SplitsBarPainter(
                    splits: splits,
                    textColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
                    textDirection: Directionality.of(context),
                    xLabel: xLabel,
                    yLabel: yLabel,
                    labelYAxis: false,
                    isTime: isTime,
                  ),
                  size: Size(constraints.maxWidth, 80),
                ),
                if (_draggingSplits && _hoverChartId == xLabel && _dragLocal != null && _hoverIndex != null)
                  Positioned(left: _dragLocal!.dx - 1, top: 0, bottom: 0, child: Container(width: 2, color: Colors.black26)),
                if (_draggingSplits && _hoverChartId == xLabel && _dragLocal != null && _hoverIndex != null)
                  Positioned(left: (_dragLocal!.dx + 8).clamp(8.0, constraints.maxWidth - 120.0), top: 6, child: _buildMiniPopup(_hoverIndex!, _hoverXValues, _hoverYValues, isTime, xLabel, yLabel)),
              ]),
            );
          }),
        ),
      ]),
    );
  }

  Widget _buildLineChartLegacy(BuildContext context, List<double> samples, List<DateTime>? timestamps, Color color, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        AppSpacing.gapXS,
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _SingleLinePainterLegacy(
              samples: samples,
              timestamps: timestamps,
              color: color,
              textColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
              textDirection: Directionality.of(context),
            ),
            size: const Size(double.infinity, 120),
          ),
        ),
      ]),
    );
  }

  Widget _buildSplitsBarChartLegacy(BuildContext context, List<double>? speedSamples, List<DateTime>? timestamps) {
    if (speedSamples == null || timestamps == null || speedSamples.isEmpty || timestamps.length != speedSamples.length) return const SizedBox.shrink();
    final splits = <double>[];
    double coveredKm = 0.0;
    for (int i = 1; i < timestamps.length; i++) {
      final elapsed = timestamps[i].difference(timestamps[0]).inSeconds;
      final distKm = elapsed * (speedSamples[i] / 3600.0);
      final completed = distKm.floor();
      if (completed > coveredKm.floor()) {
        splits.add(speedSamples[i]);
        coveredKm = completed.toDouble();
      }
    }
    if (splits.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Splits (${isMetric ? 'km' : 'mi'})', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
        AppSpacing.gapXS,
        SizedBox(
          height: 80,
          child: CustomPaint(
            painter: _SplitsBarPainter(
              splits: splits,
              textColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
              textDirection: Directionality.of(context),
              xLabel: isMetric ? 'km' : 'mi',
              yLabel: 'Avg Speed (km/h)',
              labelYAxis: false,
            ),
            size: const Size(double.infinity, 80),
          ),
        ),
      ]),
    );
  }

  Widget _buildPlaceholder(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.show_chart, size: 28, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
        AppSpacing.gapHorizontalSM,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No time-series samples available for $title.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
  List<double> _calculateSplitsTimePerMile(List<double> distances, List<double> speed) {
    if (distances.isEmpty || speed.isEmpty) return [];

    const mile = 1609.34;
    final result = <double>[];

    // Start cumulative distance at the current offset within the first mile so
    // that split boundaries align with the activity's absolute distance values.
    double cumDist = distances.first % mile;
    double cumTime = 0.0;

    for (var i = 0; i < distances.length - 1; i++) {
      final cur = distances[i];
      final next = distances[i + 1];
      var delta = next - cur;
      if (delta <= 0) continue;

      // Pick speed for this segment; if missing, use last known or small epsilon
      double sp = 0.0;
      if (i < speed.length) {
        sp = speed[i];
      } else if (speed.isNotEmpty) {
        sp = speed.last;
      } else {
        sp = 0.0;
      }
      if (sp <= 0.01) {
        sp = 0.5; // fallback km/h to avoid division by zero
      }

      double remainingDelta = delta;

      while (remainingDelta > 0) {
        final need = mile - cumDist;

        if (remainingDelta >= need) {
          // Completes a mile
          final timeForNeed = (need / 1000.0) / sp * 3600.0;
          cumTime += timeForNeed;
          result.add(cumTime);
          // Prepare for next mile
          remainingDelta -= need;
          cumDist = 0.0;
          cumTime = 0.0;
        } else {
          // Partial segment, accumulate and break
          cumDist += remainingDelta;
          cumTime += (remainingDelta / 1000.0) / sp * 3600.0;
          remainingDelta = 0.0;
        }
      }
    }

    // Ensure the number of splits does not exceed the integer miles in the
    // activity (defensive - algorithm should naturally produce this count).
    final totalMiles = (distances.last ~/ mile);
    if (result.length > totalMiles) return result.sublist(0, totalMiles);
    return result;
  }

  // distances in meters, speed in m/s -> compute time (seconds) taken for each
  // completed kilometer. Returns one entry per completed km in seconds.
  List<double> _calculateSplitsTimePerKm(List<double> distances, List<double> speed) {
    if (distances.isEmpty || speed.isEmpty) return [];
    final result = <double>[];

    // Start cumulative distance at the current offset within the first km so
    // that split boundaries align with the activity's absolute distance values.
    double cumDist = distances.first % 1000.0; // distance since last km boundary
    double cumTime = 0.0; // time since last km boundary (seconds)

    // iterate over segments defined by successive distance samples
    for (var i = 0; i < distances.length - 1; i++) {
      final cur = distances[i];
      final next = distances[i + 1];
      var delta = next - cur;
      if (delta <= 0) continue;

      // pick speed for this segment; if missing, use last known or small epsilon
      double sp = 0.0;
      if (i < speed.length) {
        sp = speed[i];
      } else if (speed.isNotEmpty) {
        sp = speed.last;
      } else {
        sp = 0.0;
      }
      if (sp <= 0.01) {
        sp = 0.5; // fallback km/h to avoid division by zero
      }

      // time to traverse whole delta at current speed (not stored separately)

      // consume the delta, possibly crossing one or more km boundaries
      double remainingDelta = delta;
      while (remainingDelta > 0) {
        final need = 1000.0 - cumDist;
        if (remainingDelta >= need) {
          // completes a km
          final timeForNeed = (need / 1000.0) / sp * 3600.0;
          cumTime += timeForNeed;
          result.add(cumTime);
          // prepare for next km
          remainingDelta -= need;
          cumDist = 0.0;
          cumTime = 0.0;
        } else {
          // partial segment, accumulate and break
          cumDist += remainingDelta;
          cumTime += (remainingDelta / 1000.0) / sp * 3600.0;
          remainingDelta = 0.0;
        }
      }
    }
    // Ensure the number of splits does not exceed the integer kilometers in the
    // activity (defensive - algorithm should naturally produce this count).
    final totalKm = (distances.last ~/ 1000);
    if (result.length > totalKm) return result.sublist(0, totalKm);
    return result;
  }

  // Build per-sample elapsed seconds from distances and speeds.
  // distances in meters, speed in m/s -> returns list of cumulative seconds for each sample (first sample = 0).
  List<double> _computeElapsedSecondsFromDistancesSpeeds(List<double> distances, List<double> speed) {
    if (distances.isEmpty) return [];
    final result = <double>[];
    double cumTime = 0.0;
    result.add(0.0);
    for (var i = 1; i < distances.length; i++) {
      final delta = distances[i] - distances[i - 1];
      if (delta <= 0) {
        result.add(cumTime);
        continue;
      }
      double sp = (i - 1) < speed.length ? speed[i - 1] : (speed.isNotEmpty ? speed.last : 0.0);
      if (sp <= 0.01) sp = 0.5;
      cumTime += delta / sp;
      result.add(cumTime);
    }
    return result;
  }

  // User interaction helpers -------------------------------------------------
  void _updateHoverForLine(Offset local, Size size, List<double> xValues, List<double> yValues, bool xIsTime, String xLabel, String yLabel, String chartId) {
    if (yValues.isEmpty) return;
    final n = yValues.length;
    final frac = (local.dx.clamp(0.0, size.width) / size.width).clamp(0.0, 1.0);
    final idx = (frac * (n - 1)).round().clamp(0, n - 1);
    setState(() {
      _draggingLine = true;
      _draggingSplits = false;
      _hoverChartId = chartId;
      _dragLocal = local;
      _hoverIndex = idx;
      _hoverChart = 'line';
      _hoverXValues = xValues;
      _hoverYValues = yValues;
      _hoverIsTime = xIsTime;
      _hoverXLabel = xLabel;
      _hoverYLabel = yLabel;
    });
  }

  void _updateHoverForSplits(Offset local, Size size, List<double> splits, bool isTime, String xLabel, String yLabel, String chartId) {
    if (splits.isEmpty) return;
    final n = splits.length;
    final frac = (local.dx.clamp(0.0, size.width) / size.width).clamp(0.0, 1.0);
    var idx = (frac * n).floor();
    if (idx >= n) idx = n - 1;
    setState(() {
      _draggingSplits = true;
      _draggingLine = false;
      _hoverChartId = chartId;
      _dragLocal = local;
      _hoverIndex = idx;
      _hoverChart = 'splits';
      _hoverXValues = null;
      _hoverYValues = splits;
      _hoverIsTime = isTime;
      _hoverXLabel = xLabel;
      _hoverYLabel = yLabel;
    });
  }

  Widget _buildMiniPopup(int idx, List<double>? xvals, List<double>? yvals, bool isTime, String xLabel, String yLabel) {
    // unit string based on user choice (km vs miles)
    final String distanceUnit = isMetric ? 'km' : 'mi';
    final lines = <Widget>[];
    // determine chart title and color
    final rawChartId = _hoverChartId ?? '';
    final chartNameRaw = rawChartId.isNotEmpty
        ? rawChartId.split('(').first.trim()
        : (_hoverChart == 'splits' ? 'Splits' : xLabel.split('(').first.trim());
    // append unit for distance charts so the popup is clear
    final chartName = chartNameRaw.toLowerCase() == 'distance'
        ? 'Distance ($distanceUnit)'
        : chartNameRaw;
    Color chartColor = Colors.black;
    final lc = chartName.toLowerCase();
    if (lc.contains('elev')) {
      chartColor = Colors.orange;
    } else if (lc.contains('speed')) {
      chartColor = Colors.blue;
    } else if (lc.contains('split') || lc == 'km') {
      chartColor = Colors.green;
    }

    String parseLabelName(String label) {
      // Extract text before '(' if present
      if (label.contains('(')) {
        return label.split('(').first.trim();
      }
      return label.trim();
    }

    String parseLabelUnit(String label) {
      if (label.contains('(') && label.contains(')')) {
        final start = label.indexOf('(');
        final end = label.indexOf(')', start + 1);
        if (end > start) return label.substring(start + 1, end).trim();
      }
      return '';
    }

    if (_hoverChart == 'splits') {
      final splitUnitLabel = isMetric ? 'km' : 'mi';
      lines.add(Text('$splitUnitLabel - ${idx + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
      final val = (yvals != null && idx < yvals.length) ? yvals[idx] : double.nan;
      if (isTime && !val.isNaN) {
        lines.add(Text('Time - ${formatDuration(val)}', style: TextStyle(fontSize: 12)));
      } else if (!val.isNaN) {
        lines.add(Text('Value - ${val.toStringAsFixed(2)}', style: TextStyle(fontSize: 12)));
      } else {
        lines.add(Text('Value - n/a', style: TextStyle(fontSize: 12)));
      }
    } else {
      final xv = (xvals != null && idx < xvals.length) ? xvals[idx] : double.nan;
      final yv = (yvals != null && idx < yvals.length) ? yvals[idx] : double.nan;

      final xName = parseLabelName(xLabel.isNotEmpty ? xLabel : 'X');
      final xUnit = parseLabelUnit(xLabel);
      final yName = parseLabelName(yLabel.isNotEmpty ? yLabel : 'Y');
      final yUnit = parseLabelUnit(yLabel);

      String xText;
      if (xv.isNaN) {
        xText = 'n/a';
      } else {
        xText = isTime ? formatDuration(xv) : xv.toStringAsFixed(2);
      }
      String yText;
      if (yv.isNaN) {
        yText = 'n/a';
      } else {
        yText = yv.toStringAsFixed(1);
      }

      // Build lines: Label - value (unit)
      lines.add(Text('$xName - $xText${xUnit.isNotEmpty ? ' ($xUnit)' : ''}', style: TextStyle(fontSize: 12)));
      lines.add(AppSpacing.gapXXS);
      lines.add(Text('$yName - $yText${yUnit.isNotEmpty ? ' ($yUnit)' : ''}', style: TextStyle(fontSize: 12)));
    }

    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(chartName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: chartColor)),
          const SizedBox(height: 6),
          ...lines
        ]),
      ),
    );
  }
}

// -- Painters --
class _SingleLinePainterDistance extends CustomPainter {
  final List<double> xValues;
  final List<double> yValues;
  final Color color;
  final Color textColor;
  final TextDirection textDirection;
  final String xLabel;
  final String yLabel;
  final double? yMin;
  final bool labelYAxis;
  final bool xIsTime;

  _SingleLinePainterDistance({required this.xValues, required this.yValues, required this.color, required this.textColor, required this.textDirection, required this.xLabel, required this.yLabel, this.yMin, this.labelYAxis = false, this.xIsTime = false});

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadBase = 10.0;
    final rightPad = 10.0;
    final topPad = 8.0;
    final bottomPad = 30.0;
    // reserve width for unit label at left so numeric axis labels won't overlap
        double unitReserve = 0.0;
        if (labelYAxis) {
          final tpUnit = TextPainter(textDirection: textDirection);
          tpUnit.text = TextSpan(text: yLabel, style: TextStyle(fontSize: 12, color: textColor));
          tpUnit.layout();
          // cap reserve so charts don't get pushed excessively to the right
          unitReserve = tpUnit.width + 8.0;
          if (unitReserve > 36.0) unitReserve = 36.0;
        }
        final leftPad = leftPadBase + unitReserve;
    final chartW = size.width - leftPad - rightPad;
     final chartH = size.height - topPad - bottomPad;
     if (xValues.isEmpty || yValues.isEmpty) return;

    final minX = xValues.first;
    final maxX = xValues.last == minX ? minX + 1 : xValues.last;
    final minY = (yMin ?? yValues.reduce((a, b) => a < b ? a : b));
    final maxY = yValues.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.05;
    final minYP = minY - pad;
    final maxYP = maxY + pad;
    final rangeY = (maxYP - minYP) == 0 ? 1 : (maxYP - minYP);

    final axisPaint = Paint()..color = textColor.withOpacity(0.3)..strokeWidth = 1.0;
    canvas.drawLine(Offset(leftPad, topPad), Offset(leftPad, topPad + chartH), axisPaint);
    canvas.drawLine(Offset(leftPad, topPad + chartH), Offset(leftPad + chartW, topPad + chartH), axisPaint);

    final path = Path();
    // If xValues and yValues lengths differ or xValues are not strictly
    // non-decreasing, fall back to index-based X mapping to avoid drawing
    // spurious long segments when switching to time mode.
    bool useIndexMapping = xValues.length != yValues.length;
    if (!useIndexMapping) {
      for (var i = 0; i < xValues.length - 1; i++) {
        if (xValues[i] > xValues[i + 1]) {
          useIndexMapping = true;
          break;
        }
      }
    }

    final int n = yValues.length;
    // (no gap-break logic here; we prefer index mapping when data are uneven)
    for (var i = 0; i < n; i++) {
      final double xv = (!useIndexMapping && i < xValues.length) ? xValues[i] : (minX + (i / (n > 1 ? (n - 1) : 1)) * (maxX - minX));
      final double yv = yValues[i];
      if (yv.isNaN || yv.isInfinite) continue;
      final double dx = useIndexMapping
          ? leftPad + (i / (n > 1 ? (n - 1) : 1)) * chartW
          : leftPad + ((xv - minX) / (maxX - minX)) * chartW;
      final norm = (yv - minYP) / rangeY;
      final dy = topPad + (1 - norm) * chartH;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true);

    if (labelYAxis) {
      final tp = TextPainter(textDirection: textDirection);
      tp.text = TextSpan(text: maxYP.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: textColor));
      tp.layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, topPad - tp.height / 2));
      tp.text = TextSpan(text: minYP.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: textColor));
      tp.layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, topPad + chartH - tp.height / 2));
      tp.text = TextSpan(text: xLabel, style: TextStyle(fontSize: 12, color: textColor));
      tp.layout();
      // push x-axis label further down so it doesn't overlap x-axis tick labels
      tp.paint(canvas, Offset(leftPad + chartW / 2 - tp.width / 2, topPad + chartH + 18));
    }

    // draw start/mid/end x-axis labels (distance or time)
    final tpX = TextPainter(textDirection: textDirection);
    final baseY = topPad + chartH + 8;
    if (n > 0) {
      double startVal, endVal, midVal;
      if (useIndexMapping) {
        startVal = 0.0;
        endVal = (n > 1) ? (n - 1).toDouble() : 0.0;
        midVal = (startVal + endVal) / 2;
      } else {
        startVal = xValues.first;
        endVal = xValues.last == startVal ? startVal + 1 : xValues.last;
        midVal = (startVal + endVal) / 2;
      }

      if (xIsTime) {
        tpX.text = TextSpan(text: formatDuration(startVal), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11));
        tpX.layout();
        tpX.paint(canvas, Offset(leftPad, baseY));

        tpX.text = TextSpan(text: formatDuration(midVal), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11));
        tpX.layout();
        tpX.paint(canvas, Offset(leftPad + chartW / 2 - tpX.width / 2, baseY));

        tpX.text = TextSpan(text: formatDuration(endVal), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11));
        tpX.layout();
        tpX.paint(canvas, Offset(leftPad + chartW - tpX.width, baseY));
      } else {
        tpX.text = TextSpan(text: startVal.toStringAsFixed(1), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11));
        tpX.layout();
        tpX.paint(canvas, Offset(leftPad, baseY));

        tpX.text = TextSpan(text: midVal.toStringAsFixed(1), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11));
        tpX.layout();
        tpX.paint(canvas, Offset(leftPad + chartW / 2 - tpX.width / 2, baseY));

        tpX.text = TextSpan(text: endVal.toStringAsFixed(1), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11));
        tpX.layout();
        tpX.paint(canvas, Offset(leftPad + chartW - tpX.width, baseY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SingleLinePainterLegacy extends CustomPainter {
  final List<double> samples;
  final List<DateTime>? timestamps;
  final Color color;
  final Color textColor;
  final TextDirection textDirection;

  _SingleLinePainterLegacy({required this.samples, this.timestamps, required this.color, required this.textColor, required this.textDirection});

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadBase = 10.0;
    final rightPad = 10.0;
    final topPad = 8.0;
    final bottomPad = 28.0;
    double unitReserve = 0.0;
    // legacy painter always shows y labels; reserve space so labels fit inside
    final tpUnit = TextPainter(textDirection: textDirection);
    tpUnit.text = TextSpan(text: '0', style: TextStyle(fontSize: 12, color: textColor));
    tpUnit.layout();
    unitReserve = tpUnit.width + 8.0;
    final leftPad = leftPadBase + unitReserve;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    if (samples.isEmpty) return;

    final minV = samples.reduce((a, b) => a < b ? a : b);
    final maxV = samples.reduce((a, b) => a > b ? a : b);
    final pad = (maxV - minV) * 0.05;
    final minVP = minV - pad;
    final maxVP = maxV + pad;
    final rangeV = (maxVP - minVP) == 0 ? 1 : (maxVP - minVP);

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final dx = leftPad + (i / (samples.length - 1)) * chartW;
      final norm = (samples[i] - minVP) / rangeV;
      final dy = topPad + (1 - norm) * chartH;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true);

    final tp = TextPainter(textDirection: textDirection);
    tp.text = TextSpan(text: maxVP.toStringAsFixed(1), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11));
    tp.layout();
    tp.paint(canvas, Offset(leftPad - tp.width - 6, topPad - tp.height / 2));
    tp.text = TextSpan(text: minVP.toStringAsFixed(1), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11));
    tp.layout();
    tp.paint(canvas, Offset(leftPad - tp.width - 6, topPad + chartH - tp.height / 2));

    final baseY = topPad + chartH + 18;
    if (timestamps != null && timestamps!.isNotEmpty) {
      String fmtDur(int seconds) {
        if (seconds < 60) return '0:${seconds.toString().padLeft(2, '0')}';
        if (seconds < 3600) {
          final m = seconds ~/ 60;
          final s = seconds % 60;
          return '$m:${s.toString().padLeft(2, '0')}';
        }
        final h = seconds ~/ 3600;
        final rem = seconds % 3600;
        final m = rem ~/ 60;
        final s = rem % 60;
        return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }

      final start = fmtDur(0);
      final midIdx = (timestamps!.length - 1) ~/ 2;
      final mid = fmtDur(timestamps![midIdx].difference(timestamps!.first).inSeconds);
      final end = fmtDur(timestamps!.last.difference(timestamps!.first).inSeconds);
      _drawXAxisLabel(canvas, Offset(leftPad, baseY), start, chartW, TextStyle(color: textColor.withOpacity(0.7), fontSize: 11), textDirection);
      _drawXAxisLabel(canvas, Offset(leftPad + chartW / 2, baseY), mid, chartW, TextStyle(color: textColor.withOpacity(0.7), fontSize: 11), textDirection, center: true);
      _drawXAxisLabel(canvas, Offset(leftPad + chartW, baseY), end, chartW, TextStyle(color: textColor.withOpacity(0.7), fontSize: 11), textDirection, alignRight: true);
    } else {
      _drawXAxisLabel(canvas, Offset(leftPad, baseY), '0', chartW, TextStyle(color: textColor.withOpacity(0.7), fontSize: 11), textDirection);
      _drawXAxisLabel(canvas, Offset(leftPad + chartW / 2, baseY), '${(samples.length / 2).round()}', chartW, TextStyle(color: textColor.withOpacity(0.7), fontSize: 11), textDirection, center: true);
      _drawXAxisLabel(canvas, Offset(leftPad + chartW, baseY), '${samples.length - 1}', chartW, TextStyle(color: textColor.withOpacity(0.7), fontSize: 11), textDirection, alignRight: true);
    }
  }

  void _drawXAxisLabel(Canvas canvas, Offset pos, String text, double maxWidth, TextStyle style, TextDirection td, {bool center = false, bool alignRight = false}) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: td);
    tp.layout(minWidth: 0, maxWidth: maxWidth / 2);
    final dx = pos.dx - (center ? tp.width / 2 : (alignRight ? tp.width : 0));
    tp.paint(canvas, Offset(dx, pos.dy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SplitsBarPainter extends CustomPainter {
  final List<double> splits;
  final Color textColor;
  final TextDirection textDirection;
  final String xLabel;
  final String yLabel;
  final bool labelYAxis;
  final bool isTime;

  _SplitsBarPainter({required this.splits, required this.textColor, required this.textDirection, required this.xLabel, required this.yLabel, this.labelYAxis = false, this.isTime = false});

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadBase = 10.0;
    final rightPad = 10.0;
    final topPad = 8.0;
    final bottomPad = 30.0;
    // reserve width for y-axis label inside the container
    double unitReserve = 0.0;
    if (labelYAxis) {
      final tpUnit = TextPainter(textDirection: textDirection);
      tpUnit.text = TextSpan(text: yLabel, style: TextStyle(fontSize: 12, color: textColor));
      tpUnit.layout();
      unitReserve = tpUnit.width + 8.0;
    }
    final leftPad = leftPadBase + unitReserve;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    if (splits.isEmpty) return;

    final minV = splits.reduce((a, b) => a < b ? a : b);
    final maxV = splits.reduce((a, b) => a > b ? a : b);
    final pad = (maxV - minV) * 0.05;
    // Force baseline to start at 0 so bars are drawn from 0..value rather than
    // from minSplit..value which can compress the visual range.
    final minVP = 0.0;
    final maxVP = maxV + pad;
    final rangeV = (maxVP - minVP) == 0 ? 1 : (maxVP - minVP);

    final barW = chartW / splits.length;
    for (var i = 0; i < splits.length; i++) {
      final dx = leftPad + i * barW;
      final norm = (splits[i] - minVP) / rangeV;
      final dy = topPad + (1 - norm) * chartH;
      final rect = Rect.fromLTWH(dx, dy, barW * 0.8, chartH - (dy - topPad));
      canvas.drawRect(rect, Paint()..color = Colors.green.shade400);
      // small index under the bar (no top label)
      final idxTp = TextPainter(text: TextSpan(text: '${i + 1}', style: TextStyle(fontSize: 10, color: textColor)), textDirection: textDirection);
      idxTp.layout();
      idxTp.paint(canvas, Offset(dx + barW * 0.4 - idxTp.width / 2, size.height - bottomPad + 2));
    }

        if (labelYAxis) {
          final tp = TextPainter(textDirection: textDirection);
          if (isTime) {
            final maxLabelSecs = maxVP;
            final minLabelSecs = minVP;
            final maxMins = maxLabelSecs ~/ 60;
            final maxRem = (maxLabelSecs % 60).round().toString().padLeft(2, '0');
            final minMins = minLabelSecs ~/ 60;
            final minRem = (minLabelSecs % 60).round().toString().padLeft(2, '0');
            tp.text = TextSpan(text: '$maxMins:$maxRem', style: TextStyle(fontSize: 11, color: textColor));
            tp.layout();
            tp.paint(canvas, Offset(leftPad - tp.width - 6, topPad - tp.height / 2));
            tp.text = TextSpan(text: '$minMins:$minRem', style: TextStyle(fontSize: 11, color: textColor));
            tp.layout();
            tp.paint(canvas, Offset(leftPad - tp.width - 6, topPad + chartH - tp.height / 2));
          } else {
            tp.text = TextSpan(text: maxVP.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: textColor));
            tp.layout();
            tp.paint(canvas, Offset(leftPad - tp.width - 6, topPad - tp.height / 2));
            tp.text = TextSpan(text: minVP.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: textColor));
            tp.layout();
            tp.paint(canvas, Offset(leftPad - tp.width - 6, topPad + chartH - tp.height / 2));
          }

          tp.text = TextSpan(text: xLabel, style: TextStyle(fontSize: 12, color: textColor));
          tp.layout();
          tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height - bottomPad + 18));
        }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}



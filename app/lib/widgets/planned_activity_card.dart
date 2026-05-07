import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/planned_activity.dart';
import '../providers/app_settings_provider.dart';

class PlannedActivityCard extends StatelessWidget {
  final PlannedActivity planned;

  const PlannedActivityCard({super.key, required this.planned});

  @override
  Widget build(BuildContext context) {
    final isMetric = context.read<AppSettingsProvider>().isMetric;
    final primary = Theme.of(context).colorScheme.primary;

    final (icon: typeIcon, color: typeColor, label: typeLabel) = _typeInfo(planned.activityType);

    final metrics = <String>[];
    if (planned.plannedDurationSecond != null) {
      metrics.add(_formatDuration(planned.plannedDurationSecond!));
    }
    if (planned.plannedDistanceMeter != null) {
      metrics.add(_formatDistance(planned.plannedDistanceMeter!, isMetric));
    }
    if (planned.targetPowerWatt != null) {
      metrics.add('${planned.targetPowerWatt} W');
    } else if (planned.targetAverageSpeedMeterPerSecond != null) {
      metrics.add(_formatTarget(planned.activityType, planned.targetAverageSpeedMeterPerSecond!, isMetric));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, size: 13, color: typeColor),
              const SizedBox(width: 5),
              Text(
                typeLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Planned',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            planned.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (planned.description != null && planned.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              planned.description!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              metrics.join('  •  '),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({IconData icon, Color color, String label}) _typeInfo(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return (icon: Icons.directions_run, color: Colors.orange, label: 'Running');
      case 'road_biking':
        return (icon: Icons.directions_bike, color: Colors.blue, label: 'Cycling');
      case 'strength_training':
        return (icon: Icons.fitness_center, color: Colors.purple, label: 'Strength Training');
      case 'cross_training':
        return (icon: Icons.sports_gymnastics, color: Colors.teal, label: 'Cross Training');
      case 'mobility_training':
        return (icon: Icons.self_improvement, color: Colors.green, label: 'Mobility Training');
      case 'resting':
        return (icon: Icons.hotel, color: Colors.grey, label: 'Rest Day');
      default:
        return (icon: Icons.fitness_center, color: Colors.grey, label: type);
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String _formatDistance(double meters, bool isMetric) {
    final km = meters / 1000;
    if (isMetric) {
      return km >= 10 ? '${km.toStringAsFixed(0)} km' : '${km.toStringAsFixed(1)} km';
    } else {
      final mi = km * 0.621371;
      return mi >= 10 ? '${mi.toStringAsFixed(0)} mi' : '${mi.toStringAsFixed(1)} mi';
    }
  }

  String _formatTarget(String activityType, double speedMs, bool isMetric) {
    final isBike = activityType.toLowerCase().contains('bike') ||
        activityType.toLowerCase().contains('biking');
    if (isBike) {
      final speed = isMetric ? speedMs * 3.6 : speedMs * 2.23694;
      return '${speed.toStringAsFixed(1)} ${isMetric ? 'kph' : 'mph'}';
    } else {
      final paceSPerUnit = isMetric ? 1000 / speedMs : 1609.34 / speedMs;
      final m = paceSPerUnit ~/ 60;
      final s = (paceSPerUnit % 60).round();
      return '$m:${s.toString().padLeft(2, '0')} ${isMetric ? '/km' : '/mi'}';
    }
  }
}

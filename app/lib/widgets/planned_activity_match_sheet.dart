import 'dart:developer';

import 'package:flutter/material.dart';

import '../models/planned_activity.dart';
import '../services/planned_activity_service.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_size.dart';

class PlannedActivityMatchSheet extends StatefulWidget {
  final List<PlannedActivity> plannedActivities;
  final String completedActivityId;

  const PlannedActivityMatchSheet({
    super.key,
    required this.plannedActivities,
    required this.completedActivityId,
  });

  @override
  State<PlannedActivityMatchSheet> createState() =>
      _PlannedActivityMatchSheetState();
}

class _PlannedActivityMatchSheetState
    extends State<PlannedActivityMatchSheet> {
  String? _selectedId;
  bool _isLoading = false;

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '--';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  Future<void> _confirm() async {
    if (_selectedId == null) return;
    setState(() => _isLoading = true);

    try {
      final success = await PlannedActivityService.instance.matchActivity(
        plannedActivityId: _selectedId!,
        completedActivityId: widget.completedActivityId,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Activity matched successfully!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to match activity. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      log('Error matching activity: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSpacing.gapMD,

            // Title
            Text(
              'Match to Planned Activity',
              style: AppTextStyles.titleLarge(
                context,
                fontWeight: AppTextSize.bold,
              ),
            ),
            AppSpacing.gapXS,
            Text(
              'Link this activity to one of today\'s planned workouts.',
              style: AppTextStyles.bodyMedium(context),
            ),
            AppSpacing.gapMD,

            // List of planned activities
            ...widget.plannedActivities.map(
              (activity) => _PlannedActivityTile(
                activity: activity,
                isSelected: _selectedId == activity.id,
                onTap: () => setState(() => _selectedId = activity.id),
                formatDuration: _formatDuration,
                formatDistance: _formatDistance,
              ),
            ),

            AppSpacing.gapMD,

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Skip'),
                  ),
                ),
                AppSpacing.gapHorizontalMD,
                Expanded(
                  child: FilledButton(
                    onPressed:
                        (_selectedId == null || _isLoading) ? null : _confirm,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirm'),
                  ),
                ),
              ],
            ),
            AppSpacing.gapMD,
          ],
        ),
      ),
    );
  }
}

class _PlannedActivityTile extends StatelessWidget {
  final PlannedActivity activity;
  final bool isSelected;
  final VoidCallback onTap;
  final String Function(int?) formatDuration;
  final String Function(double?) formatDistance;

  const _PlannedActivityTile({
    required this.activity,
    required this.isSelected,
    required this.onTap,
    required this.formatDuration,
    required this.formatDistance,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: AppSpacing.paddingMD,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: AppSpacing.borderRadiusMD,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? colorScheme.primary : colorScheme.outline,
            ),
            AppSpacing.gapHorizontalMD,

            // Activity info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: AppTextStyles.titleMedium(
                      context,
                      fontWeight: AppTextSize.bold,
                    ),
                  ),
                  AppSpacing.gapXXS,
                  Row(
                    children: [
                      Text(
                        activity.activityType,
                        style: AppTextStyles.labelSmall(context),
                      ),
                      if (activity.plannedDistanceMeter != null) ...[
                        Text(
                          '  ·  ${formatDistance(activity.plannedDistanceMeter)}',
                          style: AppTextStyles.labelSmall(context),
                        ),
                      ],
                      if (activity.plannedDurationSecond != null) ...[
                        Text(
                          '  ·  ${formatDuration(activity.plannedDurationSecond)}',
                          style: AppTextStyles.labelSmall(context),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

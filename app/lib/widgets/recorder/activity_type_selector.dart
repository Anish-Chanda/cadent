import 'package:flutter/material.dart';
import '../../models/recording_session_model.dart';
import '../../utils/app_spacing.dart';

/// Bottom sheet selector for choosing activity type.
/// Displays a list of workout types to select from.
class ActivityTypeSelector extends StatelessWidget {
  final WorkoutType currentType;
  final Function(WorkoutType) onTypeSelected;

  const ActivityTypeSelector({
    super.key,
    required this.currentType,
    required this.onTypeSelected,
  });

  /// Show the activity type selector as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required WorkoutType currentType,
    required Function(WorkoutType) onTypeSelected,
  }) {
    return showModalBottomSheet<WorkoutType>(
      context: context,
      builder: (context) => ActivityTypeSelector(
        currentType: currentType,
        onTypeSelected: (type) {
          onTypeSelected(type);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Activity Type',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.gapLG,
          ...WorkoutType.values.map(
            (type) => ListTile(
              title: Text(
                type.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ) ?? const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: currentType == type
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => onTypeSelected(type),
            ),
          ),
          AppSpacing.gapLG,
        ],
      ),
    );
  }
}

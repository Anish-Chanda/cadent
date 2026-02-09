import 'package:flutter/material.dart';
import '../../models/recording_session_model.dart';

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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          ...WorkoutType.values.map(
            (type) => ListTile(
              title: Text(
                type.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: currentType == type
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () => onTypeSelected(type),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

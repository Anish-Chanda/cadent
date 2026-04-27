import 'package:flutter/material.dart';

import '../models/training_plan.dart';
import '../services/training_plans_service.dart';
import '../widgets/global/empty_state_widget.dart';
import '../widgets/global/error_state_widget.dart';
import '../widgets/global/loading_indicator.dart';
import 'training_plan_import_sheet.dart';

class TrainingPlanDetailScreen extends StatefulWidget {
  final TrainingPlan plan;

  const TrainingPlanDetailScreen({super.key, required this.plan});

  @override
  State<TrainingPlanDetailScreen> createState() =>
      _TrainingPlanDetailScreenState();
}

class _TrainingPlanDetailScreenState extends State<TrainingPlanDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<TrainingPlanWorkout> _workouts = [];

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Training Plan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final plan = widget.plan;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.primaryActivityType != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  plan.primaryActivityType!.replaceAll('_', ' '),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              plan.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                plan.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _InfoPill(
                  icon: Icons.calendar_view_week,
                  label: '${plan.durationWeeks} weeks',
                ),
                _InfoPill(
                  icon: Icons.fitness_center,
                  label: '${plan.recommendedWorkoutsPerWeek} per week',
                ),
                ElevatedButton.icon(
                  onPressed: _openImportSheet,
                  icon: const Icon(Icons.download),
                  label: const Text('Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(message: _errorMessage, onRetry: _loadWorkouts);
    }

    return RefreshIndicator(
      onRefresh: () => _loadWorkouts(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          _buildHeaderCard(context),
          const SizedBox(height: 8),
          if (_workouts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: EmptyStateWidget(
                icon: Icons.event_busy,
                title: 'No workouts in this plan',
                message: 'This training plan has no workout templates yet.',
              ),
            )
          else
            ..._groupWorkoutsByWeek(
              _workouts,
            ).map((week) => _WorkoutWeekSection(week: week)),
        ],
      ),
    );
  }

  Future<void> _loadWorkouts({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final workouts = await TrainingPlansService.instance
          .getTrainingPlanWorkouts(widget.plan.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _workouts = workouts;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _openImportSheet() async {
    final imported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TrainingPlanImportSheet(plan: widget.plan),
    );

    if (!mounted || imported != true) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Training plan imported.')));
  }

  List<_WorkoutWeek> _groupWorkoutsByWeek(List<TrainingPlanWorkout> workouts) {
    final sorted = [...workouts]
      ..sort((a, b) => a.sequenceIndex.compareTo(b.sequenceIndex));

    final grouped = <int, List<TrainingPlanWorkout>>{};

    for (final workout in sorted) {
      final sequenceIndex = workout.sequenceIndex <= 0
          ? 1
          : workout.sequenceIndex;
      final weekNumber = ((sequenceIndex - 1) ~/ 7) + 1;
      grouped
          .putIfAbsent(weekNumber, () => <TrainingPlanWorkout>[])
          .add(workout);
    }

    final weekEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return weekEntries
        .map(
          (entry) => _WorkoutWeek(weekNumber: entry.key, workouts: entry.value),
        )
        .toList();
  }
}

class _WorkoutWeek {
  final int weekNumber;
  final List<TrainingPlanWorkout> workouts;

  const _WorkoutWeek({required this.weekNumber, required this.workouts});
}

class _WorkoutWeekSection extends StatelessWidget {
  final _WorkoutWeek week;

  const _WorkoutWeekSection({required this.week});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Week ${week.weekNumber}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...week.workouts.map((workout) {
                final sequenceIndex = workout.sequenceIndex <= 0
                    ? 1
                    : workout.sequenceIndex;
                final dayNumber = ((sequenceIndex - 1) % 7) + 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Day $dayNumber',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              workout.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (workout.description != null &&
                          workout.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          workout.description!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricChip(
                            icon: Icons.category,
                            label: workout.type.replaceAll('_', ' '),
                          ),
                          if (workout.plannedDurationS != null)
                            _MetricChip(
                              icon: Icons.schedule,
                              label:
                                  '${(workout.plannedDurationS! / 60).round()} min',
                            ),
                          if (workout.plannedDistanceM != null)
                            _MetricChip(
                              icon: Icons.straighten,
                              label:
                                  '${(workout.plannedDistanceM! / 1000).toStringAsFixed(1)} km',
                            ),
                          if (workout.plannedElevationGainM != null)
                            _MetricChip(
                              icon: Icons.terrain,
                              label:
                                  '${workout.plannedElevationGainM!.toStringAsFixed(0)} m',
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14), const SizedBox(width: 4), Text(label)],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14), const SizedBox(width: 4), Text(label)],
      ),
    );
  }
}

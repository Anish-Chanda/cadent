import 'dart:async';

import 'package:flutter/material.dart';

import '../models/training_plan.dart';
import '../services/training_plans_service.dart';
import '../widgets/global/empty_state_widget.dart';
import '../widgets/global/error_state_widget.dart';
import '../widgets/global/loading_indicator.dart';
import 'training_plan_detail_screen.dart';

class TrainingPlansScreen extends StatefulWidget {
  const TrainingPlansScreen({super.key});

  @override
  State<TrainingPlansScreen> createState() => _TrainingPlansScreenState();
}

class _TrainingPlansScreenState extends State<TrainingPlansScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;

  bool _isLoading = true;
  String? _errorMessage;

  List<TrainingPlan> _plans = [];
  TrainingPlanActivityTypeFilter _activityType =
      TrainingPlanActivityTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadTrainingPlans();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Training Plans',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _loadTrainingPlans(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search plans',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _loadTrainingPlans();
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(TrainingPlanActivityTypeFilter.all),
                _buildFilterChip(TrainingPlanActivityTypeFilter.running),
                _buildFilterChip(TrainingPlanActivityTypeFilter.roadBiking),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(TrainingPlanActivityTypeFilter filter) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(filter.label),
        selected: _activityType == filter,
        onSelected: (isSelected) {
          if (!isSelected || _activityType == filter) {
            return;
          }

          setState(() {
            _activityType = filter;
          });

          _loadTrainingPlans();
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(
        message: _errorMessage,
        onRetry: _loadTrainingPlans,
      );
    }

    if (_plans.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.event_note,
        title: 'No training plans found',
        message: 'Try another query or activity type.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTrainingPlans(showLoading: false),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _plans.length,
        itemBuilder: (context, index) {
          final plan = _plans[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          TrainingPlanDetailScreen(plan: plan),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            plan.primaryActivityType == 'road_biking'
                                ? Icons.directions_bike
                                : Icons.directions_run,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      if (plan.description != null &&
                          plan.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          plan.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PlanMetaChip(
                            icon: Icons.calendar_view_week,
                            label: '${plan.durationWeeks} weeks',
                          ),
                          _PlanMetaChip(
                            icon: Icons.fitness_center,
                            label: '${plan.recommendedWorkoutsPerWeek}/week',
                          ),
                          _PlanMetaChip(
                            icon: Icons.trending_up,
                            label: plan.difficulty,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadTrainingPlans(),
    );
  }

  Future<void> _loadTrainingPlans({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final plans = await TrainingPlansService.instance.getTrainingPlans(
        query: _searchController.text,
        activityType: _activityType,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _plans = plans;
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
}

class _PlanMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlanMetaChip({required this.icon, required this.label});

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

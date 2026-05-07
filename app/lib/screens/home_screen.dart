import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/planned_activity.dart';
import '../providers/activities_provider.dart';
import '../providers/calendar_provider.dart';
import '../widgets/activity_card.dart';
import '../widgets/calendar_card.dart';
import '../widgets/planned_activity_card.dart';
import '../widgets/global/loading_indicator.dart';
import '../widgets/global/error_state_widget.dart';
import '../widgets/global/empty_state_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ActivitiesProvider>(context, listen: false);
      if (provider.loadingState == ActivitiesLoadingState.idle) {
        provider.loadActivities();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Activities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        actions: [
          Consumer<ActivitiesProvider>(
            builder: (context, provider, child) {
              return IconButton(
                onPressed: provider.isLoading ? null : () => provider.refreshActivities(),
                icon: const Icon(Icons.refresh),
              );
            },
          ),
        ],
      ),
      body: Consumer2<ActivitiesProvider, CalendarProvider>(
        builder: (context, activitiesProvider, calendarProvider, child) {
          return _buildBody(activitiesProvider, calendarProvider);
        },
      ),
    );
  }

  Widget _buildBody(ActivitiesProvider provider, CalendarProvider calendarProvider) {
    if (provider.isLoading) return const LoadingIndicator();
    if (provider.hasError) {
      return ErrorStateWidget(
        message: provider.errorMessage,
        onRetry: () => provider.retry(),
      );
    }

    final selectedPlanned = _selectedDate != null
        ? calendarProvider.plannedForDate(_selectedDate!)
        : <PlannedActivity>[];

    final selectedActivities = _selectedDate != null
        ? provider.activities.where((a) => DateUtils.isSameDay(a.startTime, _selectedDate!)).toList()
        : [];

    final pastActivities = provider.activities
        .where((a) => _selectedDate == null || !DateUtils.isSameDay(a.startTime, _selectedDate!))
        .toList();

    final items = <Widget>[
      CalendarCard(
        selectedDate: _selectedDate,
        onDateSelected: (date) => setState(() => _selectedDate = date),
      ),
      ...selectedPlanned.map((p) => PlannedActivityCard(planned: p)),
      ...selectedActivities.map((a) => ActivityCard(activity: a)),
      _buildSeparator(context),
      if (pastActivities.isEmpty && selectedActivities.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: EmptyStateWidget(
            icon: Icons.directions_run,
            title: 'No activities yet',
            message: 'Tap the record button to start your first activity',
          ),
        )
      else
        ...pastActivities.map((a) => ActivityCard(activity: a)),
    ];

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        provider.refreshActivities(),
        calendarProvider.refresh(),
      ]),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: items,
      ),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            'Past Activities',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(thickness: 0.5)),
        ],
      ),
    );
  }

}

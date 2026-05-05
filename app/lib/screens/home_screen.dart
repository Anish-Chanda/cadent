import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/planned_activity.dart';
import '../providers/activities_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/calendar_provider.dart';
import '../widgets/activity_card.dart';
import '../widgets/calendar_card.dart';
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

    final isMetric = context.read<AppSettingsProvider>().isMetric;

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
      ...selectedPlanned.map((p) => _buildPlannedCard(context, p, isMetric)),
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

  Widget _buildStatCell(BuildContext context, IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 17),
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildPlannedCard(BuildContext context, PlannedActivity planned, bool isMetric) {
    IconData icon;
    Color color;
    String label;

    switch (planned.activityType.toLowerCase()) {
      case 'running':
        icon = Icons.directions_run; color = Colors.orange; label = 'Run';
        break;
      case 'road_biking':
        icon = Icons.directions_bike; color = Colors.blue; label = 'Road Ride';
        break;
      default:
        icon = Icons.fitness_center; color = Colors.grey; label = planned.activityType;
    }

    final dateStr = DateFormat.MMMd().format(planned.startTime);

    final distanceKm = planned.plannedDistanceMeter != null ? planned.plannedDistanceMeter! / 1000 : null;
    final distanceMiles = distanceKm != null ? distanceKm * 0.621371 : null;
    final distance = isMetric ? distanceKm : distanceMiles;
    final distanceStr = distance != null ? '${distance.toStringAsFixed(2)} ${isMetric ? 'km' : 'mi'}' : '--';

    String durationStr = '--';
    if (planned.plannedDurationSecond != null) {
      final h = planned.plannedDurationSecond! ~/ 3600;
      final m = (planned.plannedDurationSecond! % 3600) ~/ 60;
      durationStr = h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    final isBike = planned.activityType.toLowerCase().contains('bike') || planned.activityType.toLowerCase().contains('biking');
    String targetStr = '--';
    String targetLabel = isBike ? 'Target Speed' : 'Target Pace';
    IconData targetIcon = isBike ? Icons.speed : Icons.timer_outlined;

    if (planned.targetPowerWatt != null) {
      targetStr = '${planned.targetPowerWatt} W';
      targetLabel = 'Target Power';
      targetIcon = Icons.bolt;
    } else if (planned.targetAverageSpeedMeterPerSecond != null) {
      final speedMs = planned.targetAverageSpeedMeterPerSecond!;
      if (isBike) {
        final speed = isMetric ? speedMs * 3.6 : speedMs * 2.23694;
        targetStr = '${speed.toStringAsFixed(1)} ${isMetric ? 'kph' : 'mph'}';
      } else {
        final paceSPerUnit = isMetric ? 1000 / speedMs : 1609.34 / speedMs;
        final m = paceSPerUnit ~/ 60;
        final s = (paceSPerUnit % 60).round();
        targetStr = '$m:${s.toString().padLeft(2, '0')} ${isMetric ? '/km' : '/mi'}';
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Theme.of(context).brightness == Brightness.light
            ? Border.all(color: Colors.grey.shade300, width: 0.8)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planned.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$label · $dateStr',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Planned',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                Expanded(child: _buildStatCell(context, Icons.straighten, distanceStr, 'Distance')),
                Expanded(child: _buildStatCell(context, Icons.access_time, durationStr, 'Duration')),
                Expanded(child: _buildStatCell(context, targetIcon, targetStr, targetLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/activity.dart';
import '../models/planned_activity.dart';
import '../providers/activities_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/calendar_provider.dart';
import 'global/empty_state_widget.dart';

class CalendarCard extends StatefulWidget {
  const CalendarCard({Key? key}) : super(key: key);

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  DateTime? _selectedDate;
  int _weekOffset = 0;

  List<DateTime> _surroundingDays() {
    final now = DateTime.now();
    final baseDate = now.add(Duration(days: _weekOffset * 5));
    return List.generate(5, (i) => DateTime(baseDate.year, baseDate.month, baseDate.day + i - 2));
  }

  void _previousWeek() {
    setState(() {
      _weekOffset--;
      _selectedDate = null;
    });
  }

  void _nextWeek() {
    setState(() {
      _weekOffset++;
      _selectedDate = null;
    });
  }

  List<Activity> _getActivitiesForDate(List<Activity> activities, DateTime date) {
    return activities.where((activity) {
      return DateUtils.isSameDay(activity.startTime, date);
    }).toList();
  }

  Widget _buildActivityIndicator(BuildContext context, List<Activity> activities, List<PlannedActivity> planned, bool isSelected) {
    final hasCompleted = activities.any((a) => a.endTime != null);
    final hasPlanned = planned.isNotEmpty;
    final hasAny = activities.isNotEmpty || hasPlanned;

    Color dotColor;
    Color? fillColor;

    if (isSelected) {
      dotColor = Colors.white;
      fillColor = hasCompleted ? Colors.white : Colors.transparent;
    } else if (hasCompleted) {
      dotColor = Colors.blue;
      fillColor = Colors.blue;
    } else if (hasAny) {
      dotColor = Colors.blue;
      fillColor = Colors.transparent;
    } else {
      dotColor = Colors.grey.shade400;
      fillColor = Colors.transparent;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(
          color: dotColor,
          width: 1.5,
        ),
      ),
    );
  }

  IconData _getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'road_biking':
        return Icons.directions_bike;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _surroundingDays();
    final today = DateTime.now();

    return Consumer3<ActivitiesProvider, AppSettingsProvider, CalendarProvider>(
      builder: (context, activitiesProvider, settingsProvider, calendarProvider, child) {
        final activities = activitiesProvider.activities;
        final isMetric = settingsProvider.isMetric;
        final selectedActivities = _selectedDate != null
            ? _getActivitiesForDate(activities, _selectedDate!)
            : <Activity>[];
        final selectedPlanned = _selectedDate != null
            ? calendarProvider.plannedForDate(_selectedDate!)
            : <PlannedActivity>[];

        return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Calendar row with navigation arrows
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    // Left arrow
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _previousWeek,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 28,
                    ),
                    // Days
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: days.map((date) {
                          final isToday = DateUtils.isSameDay(date, today);
                          final isSelected = _selectedDate != null && DateUtils.isSameDay(date, _selectedDate!);
                          final dayName = DateFormat.E().format(date);
                          final dayNum = DateFormat.d().format(date);
                          final dayActivities = _getActivitiesForDate(activities, date);
                          final dayPlanned = calendarProvider.plannedForDate(date);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDate = isSelected ? null : date;
                              });
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // "Today" label
                                if (isToday)
                                  Text(
                                    'Today',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  )
                                else
                                  const SizedBox(height: 12),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    border: isToday
                                        ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 1.5)
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        dayName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.onPrimary
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dayNum,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.onPrimary
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildActivityIndicator(context, dayActivities, dayPlanned, isSelected),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Right arrow
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _nextWeek,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 28,
                    ),
                  ],
                ),
              ),
              // Details section
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: (selectedActivities.isEmpty && selectedPlanned.isEmpty) || _selectedDate == null ? 180 : 0,
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _selectedDate == null
                    ? const EmptyStateWidget(
                        icon: Icons.calendar_today,
                        title: 'Select a Day',
                        message: 'Tap a date above to see your activities',
                        iconSize: 48,
                      )
                    : (selectedActivities.isEmpty && selectedPlanned.isEmpty)
                        ? const EmptyStateWidget(
                            icon: Icons.directions_run,
                            title: 'No Activities Today',
                            iconSize: 48,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...selectedActivities.map((activity) {
                                final distance = isMetric
                                    ? activity.stats?.derived.distanceKm ?? 0
                                    : activity.stats?.derived.distanceMiles ?? 0;
                                final distanceLabel = isMetric ? 'km' : 'mi';
                                final isCompleted = activity.endTime != null;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getActivityIcon(activity.activityType),
                                        size: 28,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              activity.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              '${distance.toStringAsFixed(2)} $distanceLabel',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isCompleted ? Icons.check_circle : Icons.schedule,
                                        size: 22,
                                        color: isCompleted ? Colors.green : Colors.orange,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              ...selectedPlanned.map((planned) {
                                final distanceKm = planned.plannedDistanceMeter != null
                                    ? planned.plannedDistanceMeter! / 1000
                                    : null;
                                final distanceMiles = distanceKm != null ? distanceKm * 0.621371 : null;
                                final distance = isMetric ? distanceKm : distanceMiles;
                                final distanceLabel = isMetric ? 'km' : 'mi';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getActivityIcon(planned.activityType),
                                        size: 28,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              planned.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            if (distance != null)
                                              Text(
                                                '${distance.toStringAsFixed(2)} $distanceLabel',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.event,
                                        size: 22,
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
              ),
            ],
        );
      },
    );
  }
}

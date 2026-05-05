import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/activity.dart';
import '../models/planned_activity.dart';
import '../providers/calendar_provider.dart';

class CalendarCard extends StatefulWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;

  const CalendarCard({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  int _weekOffset = 0;

  List<DateTime> _surroundingDays() {
    final now = DateTime.now();
    final baseDate = now.add(Duration(days: _weekOffset * 5));
    return List.generate(5, (i) => DateTime(baseDate.year, baseDate.month, baseDate.day + i - 2));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentRange());
  }

  void _loadCurrentRange() {
    final days = _surroundingDays();
    context.read<CalendarProvider>().loadCalendar(days.first, days.last);
  }

  void _previousWeek() {
    setState(() => _weekOffset--);
    widget.onDateSelected(null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentRange());
  }

  void _nextWeek() {
    setState(() => _weekOffset++);
    widget.onDateSelected(null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentRange());
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
        border: Border.all(color: dotColor, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _surroundingDays();
    final today = DateTime.now();

    return Consumer<CalendarProvider>(
      builder: (context, calendarProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousWeek,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 28,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: days.map((date) {
                    final isToday = DateUtils.isSameDay(date, today);
                    final isSelected = widget.selectedDate != null && DateUtils.isSameDay(date, widget.selectedDate!);
                    final dayName = DateFormat.E().format(date);
                    final dayNum = DateFormat.d().format(date);
                    final dayActivities = calendarProvider.activitiesForDate(date);
                    final dayPlanned = calendarProvider.plannedForDate(date);

                    return GestureDetector(
                      onTap: () => widget.onDateSelected(isSelected ? null : date),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dayNum,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
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
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextWeek,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 28,
              ),
            ],
          ),
        );
      },
    );
  }
}

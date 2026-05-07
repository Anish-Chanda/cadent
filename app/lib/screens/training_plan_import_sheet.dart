import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/training_plan.dart';
import '../services/training_plans_service.dart';

class TrainingPlanImportSheet extends StatefulWidget {
  final TrainingPlan plan;

  const TrainingPlanImportSheet({super.key, required this.plan});

  @override
  State<TrainingPlanImportSheet> createState() =>
      _TrainingPlanImportSheetState();
}

class _TrainingPlanImportSheetState extends State<TrainingPlanImportSheet> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateLabelFormat = DateFormat('EEE, MMM d, yyyy');
  final DateFormat _timeLabelFormat = DateFormat('h:mm a');
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late DateTime _startDate;
  late int _selectedWorkoutsPerWeek;

  Timer? _previewDebounce;

  TrainingPlanPreviewResponse? _previewResponse;
  bool _isPreviewLoading = false;
  bool _isImporting = false;

  String? _previewError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _selectedWorkoutsPerWeek = widget.plan.recommendedWorkoutsPerWeek.clamp(
      1,
      7,
    );

    _titleController.text = widget.plan.title;
    _descriptionController.text = widget.plan.description ?? '';

    _titleController.addListener(_schedulePreviewRequest);
    _descriptionController.addListener(_schedulePreviewRequest);

    _schedulePreviewRequest();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _titleController.removeListener(_schedulePreviewRequest);
    _descriptionController.removeListener(_schedulePreviewRequest);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewItems = _buildPreviewItems();
    final groupedPreviewItems = _groupPreviewItemsByDate(previewItems);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(context),
              if (_isPreviewLoading)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildFormFields(context),
                    const SizedBox(height: 16),
                    _buildSummaryCards(previewItems),
                    const SizedBox(height: 16),
                    _buildPreviewSection(context, groupedPreviewItems),
                    if (_submitError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _submitError!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Import Plan',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.plan.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modify Before Import',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Start Date', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _pickStartDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(_dateLabelFormat.format(_startDate)),
            ),
            const SizedBox(height: 12),
            Text(
              'Workouts Per Week',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  onPressed: _isImporting
                      ? null
                      : () => _updateWorkoutsPerWeek(
                          _selectedWorkoutsPerWeek - 1,
                        ),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_selectedWorkoutsPerWeek',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: _isImporting
                      ? null
                      : () => _updateWorkoutsPerWeek(
                          _selectedWorkoutsPerWeek + 1,
                        ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recommended: ${widget.plan.recommendedWorkoutsPerWeek}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              enabled: !_isImporting,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 4,
              enabled: !_isImporting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(List<_PreviewAgendaItem> previewItems) {
    var importCount = 0;
    var plannedCount = 0;
    var completedCount = 0;

    for (final item in previewItems) {
      switch (item.kind) {
        case _PreviewItemKind.imported:
          importCount += 1;
        case _PreviewItemKind.planned:
          plannedCount += 1;
        case _PreviewItemKind.completed:
          completedCount += 1;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Import',
            value: importCount,
            icon: Icons.download,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: 'Planned',
            value: plannedCount,
            icon: Icons.event_note,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: 'Completed',
            value: completedCount,
            icon: Icons.check_circle_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(
    BuildContext context,
    Map<DateTime, List<_PreviewAgendaItem>> groupedPreviewItems,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_previewError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _previewError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              )
            else if (_isPreviewLoading && _previewResponse == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (groupedPreviewItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Adjust import settings to load preview items.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...groupedPreviewItems.entries.map((entry) {
                final day = entry.key;
                final items = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE, MMM d').format(day),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...items.map(
                        (item) => _PreviewRow(
                          title: item.title,
                          subtitle:
                              '${item.typeLabel} • ${_timeLabelFormat.format(item.startTime.toLocal())}',
                          kind: item.kind,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isImporting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isImporting ? null : _submitImport,
              child: _isImporting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Import Plan'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _startDate = picked;
    });
    _schedulePreviewRequest();
  }

  void _updateWorkoutsPerWeek(int value) {
    final clamped = value.clamp(1, 7);
    if (clamped == _selectedWorkoutsPerWeek) {
      return;
    }

    setState(() {
      _selectedWorkoutsPerWeek = clamped;
    });
    _schedulePreviewRequest();
  }

  void _schedulePreviewRequest() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 250), _loadPreview);
  }

  Future<void> _loadPreview() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isPreviewLoading = true;
      _previewError = null;
    });

    try {
      final response = await TrainingPlansService.instance
          .importTrainingPlanDryRun(
            widget.plan.id,
            ImportTrainingPlanDryRunRequest(
              startDate: _buildStartDateWithLocalHour(_startDate),
              selectedWorkoutsPerWeek: _selectedWorkoutsPerWeek,
              title: _titleController.text.trim().isEmpty
                  ? null
                  : _titleController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
            ),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _previewResponse = response;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _previewError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreviewLoading = false;
        });
      }
    }
  }

  Future<void> _submitImport() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      return;
    }

    if (_selectedWorkoutsPerWeek < 1 || _selectedWorkoutsPerWeek > 7) {
      setState(() {
        _submitError = 'Workouts per week must be between 1 and 7.';
      });
      return;
    }

    setState(() {
      _submitError = null;
      _isImporting = true;
    });

    try {
      await TrainingPlansService.instance.importTrainingPlan(
        widget.plan.id,
        ImportTrainingPlanRequest(
          startDate: _buildStartDateWithLocalHour(_startDate),
          selectedWorkoutsPerWeek: _selectedWorkoutsPerWeek,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  DateTime _buildStartDateWithLocalHour(DateTime baseDate) {
    return DateTime(baseDate.year, baseDate.month, baseDate.day, 9);
  }

  List<_PreviewAgendaItem> _buildPreviewItems() {
    if (_previewResponse == null) {
      return [];
    }

    final items = <_PreviewAgendaItem>[];

    for (final activity in _previewResponse!.activities) {
      items.add(
        _PreviewAgendaItem(
          title: activity.title,
          typeLabel: activity.type.replaceAll('_', ' '),
          startTime: activity.startTime,
          kind: _PreviewItemKind.completed,
        ),
      );
    }

    for (final planned in _previewResponse!.plannedActivities) {
      if (planned.matchedActivityId != null) {
        continue;
      }

      items.add(
        _PreviewAgendaItem(
          title: planned.title,
          typeLabel: planned.type.replaceAll('_', ' '),
          startTime: planned.startTime,
          kind: planned.isDryRun
              ? _PreviewItemKind.imported
              : _PreviewItemKind.planned,
        ),
      );
    }

    items.sort((a, b) => a.startTime.compareTo(b.startTime));
    return items;
  }

  Map<DateTime, List<_PreviewAgendaItem>> _groupPreviewItemsByDate(
    List<_PreviewAgendaItem> items,
  ) {
    final grouped = <DateTime, List<_PreviewAgendaItem>>{};

    for (final item in items) {
      final local = item.startTime.toLocal();
      final dayKey = DateTime(local.year, local.month, local.day);

      final bucket = grouped.putIfAbsent(dayKey, () => <_PreviewAgendaItem>[]);
      bucket.add(item);
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return {for (final entry in sortedEntries) entry.key: entry.value};
  }
}

enum _PreviewItemKind { imported, planned, completed }

class _PreviewAgendaItem {
  final String title;
  final String typeLabel;
  final DateTime startTime;
  final _PreviewItemKind kind;

  const _PreviewAgendaItem({
    required this.title,
    required this.typeLabel,
    required this.startTime,
    required this.kind,
  });
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final _PreviewItemKind kind;

  const _PreviewRow({
    required this.title,
    required this.subtitle,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final kindMeta = _buildMeta(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kindMeta.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kindMeta.badge,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              kindMeta.label,
              style: TextStyle(
                color: kindMeta.badgeText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _PreviewKindMeta _buildMeta(BuildContext context) {
    switch (kind) {
      case _PreviewItemKind.imported:
        return _PreviewKindMeta(
          label: 'Import',
          background: Theme.of(context).colorScheme.primaryContainer,
          badge: Theme.of(context).colorScheme.primary,
          badgeText: Theme.of(context).colorScheme.onPrimary,
        );
      case _PreviewItemKind.planned:
        return _PreviewKindMeta(
          label: 'Planned',
          background: Theme.of(context).colorScheme.surfaceContainer,
          badge: Theme.of(context).colorScheme.outline,
          badgeText: Theme.of(context).colorScheme.onPrimary,
        );
      case _PreviewItemKind.completed:
        return _PreviewKindMeta(
          label: 'Completed',
          background: Theme.of(context).colorScheme.secondaryContainer,
          badge: Theme.of(context).colorScheme.secondary,
          badgeText: Theme.of(context).colorScheme.onSecondary,
        );
    }
  }
}

class _PreviewKindMeta {
  final String label;
  final Color background;
  final Color badge;
  final Color badgeText;

  const _PreviewKindMeta({
    required this.label,
    required this.background,
    required this.badge,
    required this.badgeText,
  });
}

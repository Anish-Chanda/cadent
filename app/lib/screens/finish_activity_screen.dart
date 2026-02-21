import 'dart:developer';

import 'package:flutter/material.dart';
import '../widgets/global/app_text_form_field.dart';
import '../widgets/global/summary_stat_card.dart';
import '../widgets/global/primary_button.dart';
import '../utils/app_spacing.dart';

class FinishActivityScreen extends StatefulWidget {
  final String formattedTime;
  final String formattedDistance;
  final String activityName;

  const FinishActivityScreen({
    super.key,
    required this.formattedTime,
    required this.formattedDistance,
    required this.activityName,
  });

  @override
  State<FinishActivityScreen> createState() => _FinishActivityScreenState();
}

class _FinishActivityScreenState extends State<FinishActivityScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocus = FocusNode();
  final _descriptionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Set default title based on activity type
    _titleController.text = '${widget.activityName} Activity';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  void _saveActivity() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final finalTitle = title.isEmpty ? '${widget.activityName} Activity' : title;
    
    log('Activity saved: $finalTitle - ${widget.activityName} - ${widget.formattedTime} - ${widget.formattedDistance}');    
    Navigator.pop(context, {
      'title': finalTitle,
      'description': description,
      'action': 'save'
    });
  }

  void _discardActivity() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Activity?'),
        content: const Text('Are you sure you want to discard this activity? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              log('Activity discarded: ${widget.activityName} - ${widget.formattedTime} - ${widget.formattedDistance}');              
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, {
                'action': 'discard'
              }); // Go back with discard result
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, {
            'action': 'resume'
          });
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context, {
            'action': 'resume'
          }),
        ),
        title: Text(
          'Save Activity',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
          ),
        ),

      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  // Activity Type
                  Text(
                    widget.activityName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  AppSpacing.gapLG,
                  
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Time',
                          value: widget.formattedTime,
                        ),
                      ),
                      AppSpacing.gapHorizontalMD,
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Distance',
                          value: widget.formattedDistance,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            AppSpacing.gapXXL,
            
            // Title Input
            Text(
              'Title',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            AppSpacing.gapSM,
            AppTextFormField(
              controller: _titleController,
              focusNode: _titleFocus,
              hintText: 'Enter activity title',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _descriptionFocus.requestFocus(),
              onChanged: (_) {},
            ),
            
            AppSpacing.gapXL,
            
            // Description Input
            Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            AppSpacing.gapSM,
            AppTextFormField(
              controller: _descriptionController,
              focusNode: _descriptionFocus,
              maxLines: 4,
              hintText: 'Add a description (optional)',
              textInputAction: TextInputAction.done,
              onChanged: (_) {},
            ),
            
            AppSpacing.gapXXXL,
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Discard',
                    onPressed: _discardActivity,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    textColor: Theme.of(context).colorScheme.error,
                  ),
                ),
                AppSpacing.gapHorizontalMD,
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    text: 'Save Activity',
                    onPressed: _saveActivity,
                  ),
                ),
              ],
            ),
          ],
        ),
      ), // Close Scaffold body (SingleChildScrollView)
    ), // Close Scaffold
    ); // Close PopScope
  }
}
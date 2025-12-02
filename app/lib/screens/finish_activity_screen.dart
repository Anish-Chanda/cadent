import 'dart:developer';

import 'package:flutter/material.dart';

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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, {
            'action': 'resume'
          }),
        ),
        title: const Text(
          'Save Activity',
          style: TextStyle(
            color: Colors.black,
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
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  // Activity Type
                  Text(
                    widget.activityName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryStatCard(
                          'Time',
                          widget.formattedTime,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryStatCard(
                          'Distance',
                          widget.formattedDistance,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Title Input
            const Text(
              'Title',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              focusNode: _titleFocus,
              decoration: InputDecoration(
                hintText: 'Enter activity title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _descriptionFocus.requestFocus(),
            ),
            
            const SizedBox(height: 24),
            
            // Description Input
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              focusNode: _descriptionFocus,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add a description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            
            const SizedBox(height: 40),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _discardActivity,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Discard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saveActivity,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
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

  Widget _buildSummaryStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
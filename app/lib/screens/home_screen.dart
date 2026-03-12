import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/activities_provider.dart';
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
  @override
  void initState() {
    super.initState();
    // Load activities when screen initializes
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
      body: Consumer<ActivitiesProvider>(
        builder: (context, provider, child) {
          return _buildBody(provider);
        },
      ),
    );
  }

  Widget _buildBody(ActivitiesProvider provider) {
    if (provider.isLoading) {
      return const LoadingIndicator();
    }

    if (provider.hasError) {
      return ErrorStateWidget(
        message: provider.errorMessage,
        onRetry: () => provider.retry(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refreshActivities(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80), // Space for FAB
        itemCount: provider.activities.length + (provider.isEmpty ? 2 : 1), // +1 for calendar card, +1 for empty state if needed
        itemBuilder: (context, index) {
          // First item is the calendar card
          if (index == 0) {
            return const CalendarCard();
          }
          // If empty and this is the second item, show empty state
          if (provider.isEmpty && index == 1) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: EmptyStateWidget(
                icon: Icons.directions_run,
                title: 'No activities yet',
                message: 'Tap the record button to start your first activity',
              ),
            );
          }
          // Rest are activity cards
          final activity = provider.activities[index - 1];
          return ActivityCard(activity: activity);
        },
      ),
    );
  }
}
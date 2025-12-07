import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:cadence/screens/home_screen.dart';
import 'package:cadence/providers/activities_provider.dart';
import 'package:cadence/widgets/activity_card.dart';
import 'package:cadence/models/activity.dart';

// Create the mock class
class MockActivitiesProvider extends Mock implements ActivitiesProvider {}

void main() {
  group('HomeScreen', () {
    late MockActivitiesProvider mockActivitiesProvider;

    setUp(() {
      mockActivitiesProvider = MockActivitiesProvider();

      // Set up default stub behaviors
      when(() => mockActivitiesProvider.isLoading).thenReturn(false);
      when(() => mockActivitiesProvider.hasError).thenReturn(false);
      when(() => mockActivitiesProvider.isEmpty).thenReturn(false);
      when(() => mockActivitiesProvider.errorMessage).thenReturn(null);
      when(() => mockActivitiesProvider.activities).thenReturn([]);
      when(
        () => mockActivitiesProvider.loadingState,
      ).thenReturn(ActivitiesLoadingState.idle);

      // Stub async methods with default behavior
      when(
        () => mockActivitiesProvider.loadActivities(),
      ).thenAnswer((_) async {});
      when(
        () => mockActivitiesProvider.refreshActivities(),
      ).thenAnswer((_) async {});
      when(() => mockActivitiesProvider.retry()).thenAnswer((_) async {});
    });

    testWidgets('displays all UI elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      // Verify main elements
      expect(find.text('Activities'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('loads activities on init', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      // Wait for post-frame callback
      await tester.pumpAndSettle();

      // Verify loadActivities was called
      verify(() => mockActivitiesProvider.loadActivities()).called(1);
    });

    testWidgets('does not load activities if not idle', (tester) async {
      when(
        () => mockActivitiesProvider.loadingState,
      ).thenReturn(ActivitiesLoadingState.loading);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify loadActivities was not called
      verifyNever(() => mockActivitiesProvider.loadActivities());
    });
    testWidgets('shows error state when hasError is true', (tester) async {
      when(() => mockActivitiesProvider.hasError).thenReturn(true);
      when(
        () => mockActivitiesProvider.errorMessage,
      ).thenReturn('Failed to load activities');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Failed to load activities'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows default error message when errorMessage is null', (
      tester,
    ) async {
      when(() => mockActivitiesProvider.hasError).thenReturn(true);
      when(() => mockActivitiesProvider.errorMessage).thenReturn(null);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('An error occurred'), findsOneWidget);
    });

    testWidgets('calls retry when Retry button is tapped', (tester) async {
      when(() => mockActivitiesProvider.hasError).thenReturn(true);
      when(
        () => mockActivitiesProvider.errorMessage,
      ).thenReturn('Failed to load activities');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      verify(() => mockActivitiesProvider.retry()).called(1);
    });

    testWidgets('shows empty state when isEmpty is true', (tester) async {
      when(() => mockActivitiesProvider.isEmpty).thenReturn(true);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.directions_run), findsOneWidget);
      expect(find.text('No activities yet'), findsOneWidget);
      expect(
        find.text('Tap the record button to start your first activity'),
        findsOneWidget,
      );
    });

    testWidgets('displays activities in ListView', (tester) async {
      // Create mock activities
      final mockActivities = [
        Activity(
          id: '1',
          title: 'Morning Run',
          description: 'A nice morning run',
          activityType: 'run',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 1800)),
          processingVer: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Activity(
          id: '2',
          title: 'Evening Ride',
          description: 'Evening cycling session',
          activityType: 'ride',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 3600)),
          processingVer: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(() => mockActivitiesProvider.isEmpty).thenReturn(false);
      when(() => mockActivitiesProvider.activities).thenReturn(mockActivities);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ActivityCard), findsNWidgets(2));
    });

    testWidgets('calls refreshActivities when refresh icon is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      verify(() => mockActivitiesProvider.refreshActivities()).called(1);
    });

    testWidgets('calls refreshActivities on pull-to-refresh', (tester) async {
      when(() => mockActivitiesProvider.isEmpty).thenReturn(false);
      when(() => mockActivitiesProvider.activities).thenReturn([
        Activity(
          id: '1',
          title: 'Morning Run',
          description: 'A nice morning run',
          activityType: 'run',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 1800)),
          processingVer: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Perform pull-to-refresh gesture
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
      await tester.pumpAndSettle();

      verify(() => mockActivitiesProvider.refreshActivities()).called(1);
    });

    testWidgets('ListView has bottom padding for FAB', (tester) async {
      when(() => mockActivitiesProvider.isEmpty).thenReturn(false);
      when(() => mockActivitiesProvider.activities).thenReturn([
        Activity(
          id: '1',
          title: 'Morning Run',
          description: 'A nice morning run',
          activityType: 'run',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 1800)),
          processingVer: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ActivitiesProvider>.value(
            value: mockActivitiesProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.padding, const EdgeInsets.only(bottom: 80));
    });
  });
}

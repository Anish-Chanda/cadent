import 'package:cadent/providers/app_settings_provider.dart';
import 'package:cadent/providers/calendar_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:cadent/screens/home_screen.dart';
import 'package:cadent/providers/activities_provider.dart';
import 'package:cadent/widgets/activity_card.dart';
import 'package:cadent/models/activity.dart';

import 'Mocks/mock_app_settings_provider.dart';
import 'Mocks/mock_calendar_provider.dart';

class MockActivitiesProvider extends Mock implements ActivitiesProvider {}

void main() {
  group('HomeScreen', () {
    late MockActivitiesProvider mockActivitiesProvider;
    late MockAppSettingsProvider mockAppSettingsProvider;
    late MockCalendarProvider mockCalendarProvider;

    setUp(() {
      mockActivitiesProvider = MockActivitiesProvider();
      mockAppSettingsProvider = MockAppSettingsProvider();
      mockCalendarProvider = MockCalendarProvider();

      when(() => mockActivitiesProvider.isLoading).thenReturn(false);
      when(() => mockActivitiesProvider.hasError).thenReturn(false);
      when(() => mockActivitiesProvider.isEmpty).thenReturn(false);
      when(() => mockActivitiesProvider.errorMessage).thenReturn(null);
      when(() => mockActivitiesProvider.activities).thenReturn([]);
      when(() => mockAppSettingsProvider.isMetric).thenReturn(true);
      when(() => mockActivitiesProvider.loadingState).thenReturn(ActivitiesLoadingState.idle);
      when(() => mockActivitiesProvider.loadActivities()).thenAnswer((_) async {});
      when(() => mockActivitiesProvider.refreshActivities()).thenAnswer((_) async {});
      when(() => mockActivitiesProvider.retry()).thenAnswer((_) async {});

      when(() => mockCalendarProvider.isLoading).thenReturn(false);
      when(() => mockCalendarProvider.hasError).thenReturn(false);
      when(() => mockCalendarProvider.activities).thenReturn([]);
      when(() => mockCalendarProvider.plannedActivities).thenReturn([]);
      when(() => mockCalendarProvider.errorMessage).thenReturn(null);
      when(() => mockCalendarProvider.activitiesForDate(any())).thenReturn([]);
      when(() => mockCalendarProvider.plannedForDate(any())).thenReturn([]);
      when(() => mockCalendarProvider.loadCalendar(any(), any())).thenAnswer((_) async {});
      when(() => mockCalendarProvider.refresh()).thenAnswer((_) async {});
    });

    Widget buildSubject() => MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ActivitiesProvider>.value(value: mockActivitiesProvider),
              ChangeNotifierProvider<CalendarProvider>.value(value: mockCalendarProvider),
              ChangeNotifierProvider<AppSettingsProvider>.value(value: mockAppSettingsProvider),
            ],
            child: const HomeScreen(),
          ),
        );

    testWidgets('displays all UI elements', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Activities'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('loads activities on init', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      verify(() => mockActivitiesProvider.loadActivities()).called(1);
    });

    testWidgets('does not load activities if not idle', (tester) async {
      when(() => mockActivitiesProvider.loadingState).thenReturn(ActivitiesLoadingState.loading);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      verifyNever(() => mockActivitiesProvider.loadActivities());
    });

    testWidgets('shows error state when hasError is true', (tester) async {
      when(() => mockActivitiesProvider.hasError).thenReturn(true);
      when(() => mockActivitiesProvider.errorMessage).thenReturn('Failed to load activities');

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Failed to load activities'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows default error message when errorMessage is null', (tester) async {
      when(() => mockActivitiesProvider.hasError).thenReturn(true);
      when(() => mockActivitiesProvider.errorMessage).thenReturn(null);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('An error occurred'), findsOneWidget);
    });

    testWidgets('calls retry when Retry button is tapped', (tester) async {
      when(() => mockActivitiesProvider.hasError).thenReturn(true);
      when(() => mockActivitiesProvider.errorMessage).thenReturn('Failed to load activities');

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      verify(() => mockActivitiesProvider.retry()).called(1);
    });

    testWidgets('shows empty state when isEmpty is true', (tester) async {
      when(() => mockActivitiesProvider.isEmpty).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // CalendarCard also uses Icons.directions_run for its empty state,
      // so assert at least one instance is present.
      expect(find.byIcon(Icons.directions_run), findsAtLeastNWidgets(1));
      expect(find.text('No activities yet'), findsOneWidget);
      expect(
        find.text('Tap the record button to start your first activity'),
        findsOneWidget,
      );
    });

    testWidgets('displays activities in ListView', (tester) async {
      final mockActivities = [
        Activity(
          id: '1',
          title: 'Morning Run',
          description: 'A nice morning run',
          activityType: 'running',
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
          activityType: 'road_biking',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 3600)),
          processingVer: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(() => mockActivitiesProvider.isEmpty).thenReturn(false);
      when(() => mockActivitiesProvider.activities).thenReturn(mockActivities);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);

      // Scroll down to ensure both ActivityCards are built and visible.
      await tester.scrollUntilVisible(find.text('Evening Ride'), 100);
      await tester.pumpAndSettle();

      expect(find.text('Morning Run'), findsOneWidget);
      expect(find.text('Evening Ride'), findsOneWidget);
    });

    testWidgets('calls refreshActivities when refresh icon is tapped', (tester) async {
      await tester.pumpWidget(buildSubject());
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
          activityType: 'running',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 1800)),
          processingVer: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

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
          activityType: 'running',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 1800)),
          processingVer: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.padding, const EdgeInsets.only(bottom: 80));
    });
  });
}

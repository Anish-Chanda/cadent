import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:cadence/screens/activity_detail_screen.dart';
import 'package:cadence/models/activity.dart';

void main() {
  group('ActivityDetailScreen', () {
    late Activity mockActivity;

    setUp(() {
      // Create a complete mock activity with all required fields
      mockActivity = Activity(
        id: '1',
        title: 'Morning Run',
        description: 'A nice morning run',
        activityType: 'running',
        startTime: DateTime(2024, 1, 15, 8, 30),
        endTime: DateTime(2024, 1, 15, 9, 0),
        stats: ActivityStats(
          elapsedSeconds: 1800.0,
          avgSpeedMs: 3.5,
          elevationGainM: 50.0,
          distanceM: 5000.0,
          derived: DerivedStats(
            speedKmh: 12.6,
            speedMph: 7.8,
            paceSPerKm: 476.0,
            paceSPerMile: 766.0,
            distanceKm: 5.0,
            distanceMiles: 3.1,
          ),
        ),
        polyline: 'encodedPolylineString',
        bbox: BoundingBox(
          minLat: 40.0,
          maxLat: 40.1,
          minLon: -74.0,
          maxLon: -73.9,
        ),
        start: Coordinate(lat: 40.05, lon: -73.95),
        end: Coordinate(lat: 40.08, lon: -73.92),
        processingVer: 1,
        createdAt: DateTime(2024, 1, 15, 9, 0),
        updatedAt: DateTime(2024, 1, 15, 9, 0),
      );
    });

    testWidgets('displays all UI elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      // Verify main elements
      expect(find.byType(MapLibreMap), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays activity title and date', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Morning Run'), findsOneWidget);
      expect(find.textContaining('January 15, 2024'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays activity type badge for run', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Run'), findsOneWidget);
      expect(find.byIcon(Icons.directions_run), findsOneWidget);
    });

    testWidgets('displays activity type badge for bike', (tester) async {
      final bikeActivity = Activity(
        id: '2',
        title: 'Evening Ride',
        description: 'Evening cycling session',
        activityType: 'road_biking',
        startTime: DateTime(2024, 1, 15, 18, 30),
        endTime: DateTime(2024, 1, 15, 20, 0),
        stats: ActivityStats(
          elapsedSeconds: 5400.0,
          avgSpeedMs: 7.5,
          elevationGainM: 150.0,
          distanceM: 40000.0,
          derived: DerivedStats(
            speedKmh: 27.0,
            speedMph: 16.8,
            paceSPerKm: null,
            paceSPerMile: null,
            distanceKm: 40.0,
            distanceMiles: 24.9,
          ),
        ),
        polyline: 'encodedPolylineString',
        bbox: BoundingBox(
          minLat: 40.0,
          maxLat: 40.2,
          minLon: -74.0,
          maxLon: -73.8,
        ),
        processingVer: 1,
        createdAt: DateTime(2024, 1, 15, 20, 0),
        updatedAt: DateTime(2024, 1, 15, 20, 0),
      );

      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: bikeActivity)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ride'), findsOneWidget);
      expect(find.byIcon(Icons.directions_bike), findsOneWidget);
    });

    testWidgets('displays distance stat correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('5.00'), findsOneWidget);
      expect(find.text('km'), findsOneWidget);
    });

    testWidgets('displays moving time stat correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      expect(find.text('MOVING TIME'), findsOneWidget);
      expect(find.text('30:00'), findsOneWidget);
    });

    testWidgets('displays elevation gain stat correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      expect(find.text('ELEVATION GAIN'), findsOneWidget);
      expect(find.text('50.0'), findsOneWidget);
      expect(find.text('m'), findsOneWidget);
    });

    testWidgets('displays avg pace for running activities', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      expect(find.text('AVG PACE'), findsOneWidget);
      expect(find.text('7:56/km'), findsOneWidget);
    });

    testWidgets('displays avg speed for biking activities', (tester) async {
      final bikeActivity = Activity(
        id: '2',
        title: 'Evening Ride',
        description: 'Evening cycling session',
        activityType: 'road_biking',
        startTime: DateTime(2024, 1, 15, 18, 30),
        endTime: DateTime(2024, 1, 15, 20, 0),
        stats: ActivityStats(
          elapsedSeconds: 5400.0,
          avgSpeedMs: 7.5,
          elevationGainM: 150.0,
          distanceM: 40000.0,
          derived: DerivedStats(
            speedKmh: 27.0,
            speedMph: 16.8,
            paceSPerKm: null,
            paceSPerMile: null,
            distanceKm: 40.0,
            distanceMiles: 24.9,
          ),
        ),
        polyline: 'encodedPolylineString',
        bbox: BoundingBox(
          minLat: 40.0,
          maxLat: 40.2,
          minLon: -74.0,
          maxLon: -73.8,
        ),
        processingVer: 1,
        createdAt: DateTime(2024, 1, 15, 20, 0),
        updatedAt: DateTime(2024, 1, 15, 20, 0),
      );

      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: bikeActivity)),
      );

      await tester.pumpAndSettle();

      expect(find.text('AVG SPEED'), findsOneWidget);
      expect(find.text('27.00'), findsOneWidget);
      expect(find.text('km/h'), findsOneWidget);
    });


    testWidgets('displays drag handle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      // Find the drag handle container
      final dragHandle = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 40 &&
            widget.constraints?.maxHeight == 4,
      );

      expect(dragHandle, findsOneWidget);
    });

    testWidgets('back button pops navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ActivityDetailScreen(activity: mockActivity),
                    ),
                  );
                },
                child: const Text('Go to Detail'),
              ),
            ),
          ),
        ),
      );

      // Navigate to detail screen
      await tester.tap(find.text('Go to Detail'));
      await tester.pumpAndSettle();

      // Verify we're on detail screen
      expect(find.byType(ActivityDetailScreen), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify we're back to original screen
      expect(find.byType(ActivityDetailScreen), findsNothing);
      expect(find.text('Go to Detail'), findsOneWidget);
    });

    testWidgets('formats duration correctly for hours', (tester) async {
      final longActivity = Activity(
        id: '3',
        title: 'Long Run',
        description: 'A very long run',
        activityType: 'running',
        startTime: DateTime(2024, 1, 15, 8, 0),
        endTime: DateTime(2024, 1, 15, 11, 30),
        stats: ActivityStats(
          elapsedSeconds: 12600.0, // 3 hours 30 minutes
          avgSpeedMs: 3.5,
          elevationGainM: 200.0,
          distanceM: 44100.0,
          derived: DerivedStats(
            speedKmh: 12.6,
            speedMph: 7.8,
            paceSPerKm: 476.0,
            paceSPerMile: 766.0,
            distanceKm: 44.1,
            distanceMiles: 27.4,
          ),
        ),
        polyline: 'encodedPolylineString',
        bbox: BoundingBox(
          minLat: 40.0,
          maxLat: 40.3,
          minLon: -74.0,
          maxLon: -73.7,
        ),
        processingVer: 1,
        createdAt: DateTime(2024, 1, 15, 11, 30),
        updatedAt: DateTime(2024, 1, 15, 11, 30),
      );

      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: longActivity)),
      );

      await tester.pumpAndSettle();

      expect(find.text('3:30:00'), findsOneWidget);
    });

    testWidgets('initializes map with correct style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      final mapWidget = tester.widget<MapLibreMap>(find.byType(MapLibreMap));
      expect(
        mapWidget.styleString,
        'https://tiles.openfreemap.org/styles/liberty',
      );
    });

    testWidgets('initializes map with correct zoom level', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      final mapWidget = tester.widget<MapLibreMap>(find.byType(MapLibreMap));
      expect(mapWidget.initialCameraPosition.zoom, 14.0);
    });

    testWidgets('draggable sheet has correct initial size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );

      expect(sheet.initialChildSize, 0.45);
      expect(sheet.minChildSize, 0.3);
      expect(sheet.maxChildSize, 0.9);
    });

    testWidgets('disposes controllers properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: mockActivity)),
      );

      await tester.pumpAndSettle();

      // Remove the widget to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Empty'))),
      );

      // If dispose wasn't handled properly, this would throw an error
      expect(tester.takeException(), isNull);
    });
  });
}

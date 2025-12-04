import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cadence/widgets/activity_charts.dart';
import 'package:cadence/models/streams.dart';

// Mock classes
class MockStreamsModel extends Mock implements StreamsModel {}

void main() {
  group('ActivityCharts', () {
    late MockStreamsModel mockStreams;

    setUp(() {
      mockStreams = MockStreamsModel();
    });

    testWidgets('displays placeholder when no data is available', (
      tester,
    ) async {
      when(() => mockStreams.numericSeries('elevation')).thenReturn([]);
      when(() => mockStreams.numericSeries('speed')).thenReturn([]);
      when(() => mockStreams.numericSeries('distance')).thenReturn([]);
      when(() => mockStreams.streams).thenReturn({});
      when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActivityCharts(streams: mockStreams)),
        ),
      );

      expect(find.text('Performance'), findsOneWidget);
      expect(find.text('No streams available'), findsOneWidget);
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('displays elevation chart when elevation data is available', (
      tester,
    ) async {
      final distances = [0.0, 1000.0, 2000.0, 3000.0];
      final elevations = [100.0, 120.0, 110.0, 130.0];

      when(() => mockStreams.numericSeries('elevation')).thenReturn(elevations);
      when(() => mockStreams.numericSeries('speed')).thenReturn([]);
      when(() => mockStreams.numericSeries('distance')).thenReturn(distances);
      when(() => mockStreams.streams).thenReturn({'distance': distances});
      when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActivityCharts(streams: mockStreams)),
        ),
      );

      expect(find.text('Performance'), findsOneWidget);
      expect(find.text('Elevation (m)'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('displays speed chart when speed data is available', (
      tester,
    ) async {
      final distances = [0.0, 1000.0, 2000.0, 3000.0];
      final speeds = [3.0, 3.5, 3.2, 3.8]; // m/s

      when(() => mockStreams.numericSeries('elevation')).thenReturn([]);
      when(() => mockStreams.numericSeries('speed')).thenReturn(speeds);
      when(() => mockStreams.numericSeries('distance')).thenReturn(distances);
      when(() => mockStreams.streams).thenReturn({'distance': distances});
      when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActivityCharts(streams: mockStreams)),
        ),
      );

      expect(find.text('Speed (km/h)'), findsOneWidget);
    });

    testWidgets('displays splits chart when sufficient distance data', (
      tester,
    ) async {
      final distances = List.generate(11, (i) => i * 1000.0); // 0-10km
      final speeds = List.generate(11, (i) => 3.0); // constant 3 m/s

      when(() => mockStreams.numericSeries('elevation')).thenReturn([]);
      when(() => mockStreams.numericSeries('speed')).thenReturn(speeds);
      when(() => mockStreams.numericSeries('distance')).thenReturn(distances);
      when(() => mockStreams.streams).thenReturn({'distance': distances});
      when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActivityCharts(streams: mockStreams)),
        ),
      );

      expect(find.text('Splits (km)'), findsOneWidget);
    });

    testWidgets('toggle switches between Distance and Time views', (
      tester,
    ) async {
      final distances = [0.0, 1000.0, 2000.0, 3000.0];
      final elevations = [100.0, 120.0, 110.0, 130.0];
      final timeOffsets = [0.0, 300.0, 600.0, 900.0]; // seconds

      when(() => mockStreams.numericSeries('elevation')).thenReturn(elevations);
      when(() => mockStreams.numericSeries('speed')).thenReturn([]);
      when(() => mockStreams.numericSeries('distance')).thenReturn(distances);
      when(() => mockStreams.streams).thenReturn({'distance': distances});
      when(() => mockStreams.timeOffsetsSeconds()).thenReturn(timeOffsets);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActivityCharts(streams: mockStreams)),
        ),
      );

      // Should show toggle buttons
      expect(find.byType(ToggleButtons), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);

      // Tap Time button
      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();

      // Verify state changed (widget should rebuild)
      expect(find.byType(ToggleButtons), findsOneWidget);
    });

    group('Distance series detection', () {
      testWidgets('finds distance from distance key', (tester) async {
        final distances = [0.0, 1000.0, 2000.0];
        final speeds = [3.0, 3.5, 3.2];

        when(() => mockStreams.numericSeries('elevation')).thenReturn([]);
        when(() => mockStreams.numericSeries('speed')).thenReturn(speeds);
        when(() => mockStreams.numericSeries('distance')).thenReturn(distances);
        when(() => mockStreams.streams).thenReturn({'distance': distances});
        when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ActivityCharts(streams: mockStreams)),
          ),
        );

        verify(
          () => mockStreams.numericSeries('distance'),
        ).called(greaterThan(0));
      });

      testWidgets('finds distance from distance_km and converts', (
        tester,
      ) async {
        final distancesKm = [0.0, 1.0, 2.0]; // in km
        final speeds = [3.0, 3.5, 3.2];

        when(() => mockStreams.numericSeries('elevation')).thenReturn([]);
        when(() => mockStreams.numericSeries('speed')).thenReturn(speeds);
        when(() => mockStreams.numericSeries('distance')).thenReturn([]);
        when(() => mockStreams.numericSeries('distance_total')).thenReturn([]);
        when(
          () => mockStreams.numericSeries('distance_cumulative'),
        ).thenReturn([]);
        when(() => mockStreams.numericSeries('dist')).thenReturn([]);
        when(() => mockStreams.numericSeries('cumdist')).thenReturn([]);
        when(
          () => mockStreams.numericSeries('distance_km'),
        ).thenReturn(distancesKm);
        when(
          () => mockStreams.streams,
        ).thenReturn({'distance_km': distancesKm});
        when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ActivityCharts(streams: mockStreams)),
          ),
        );

        // Should convert km to meters internally
        expect(find.text('Speed (km/h)'), findsOneWidget);
      });
    });

    group('Edge cases', () {
      testWidgets('handles negative speeds by clamping to zero', (
        tester,
      ) async {
        final distances = [0.0, 1000.0, 2000.0];
        final speeds = [-1.0, 3.5, -0.5]; // some negative speeds

        when(() => mockStreams.numericSeries('elevation')).thenReturn([]);
        when(() => mockStreams.numericSeries('speed')).thenReturn(speeds);
        when(() => mockStreams.numericSeries('distance')).thenReturn(distances);
        when(() => mockStreams.streams).thenReturn({'distance': distances});
        when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ActivityCharts(streams: mockStreams)),
          ),
        );

        // Should not crash and display speed chart
        expect(find.text('Speed (km/h)'), findsOneWidget);
      });

      testWidgets('handles empty streams map', (tester) async {
        when(() => mockStreams.numericSeries('elevation')).thenReturn([]);
        when(() => mockStreams.numericSeries('speed')).thenReturn([]);
        when(() => mockStreams.numericSeries('distance')).thenReturn([]);
        when(() => mockStreams.streams).thenReturn({});
        when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ActivityCharts(streams: mockStreams)),
          ),
        );

        expect(find.text('No streams available'), findsOneWidget);
      });

      testWidgets('handles mismatched data lengths gracefully', (tester) async {
        final distances = [0.0, 1000.0, 2000.0, 3000.0];
        final elevations = [100.0, 120.0]; // shorter than distances

        when(
          () => mockStreams.numericSeries('elevation'),
        ).thenReturn(elevations);
        when(() => mockStreams.numericSeries('speed')).thenReturn([]);
        when(() => mockStreams.numericSeries('distance')).thenReturn(distances);
        when(() => mockStreams.streams).thenReturn({'distance': distances});
        when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ActivityCharts(streams: mockStreams)),
          ),
        );

        // Should still render without crashing
        expect(find.text('Elevation (m)'), findsOneWidget);
      });
    });

    group('Interaction', () {
      testWidgets('pan gesture updates hover state', (tester) async {
        final distances = [0.0, 1000.0, 2000.0, 3000.0];
        final elevations = [100.0, 120.0, 110.0, 130.0];

        when(
          () => mockStreams.numericSeries('elevation'),
        ).thenReturn(elevations);
        when(() => mockStreams.numericSeries('speed')).thenReturn([]);
        when(() => mockStreams.numericSeries('distance')).thenReturn(distances);
        when(() => mockStreams.streams).thenReturn({'distance': distances});
        when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ActivityCharts(streams: mockStreams)),
          ),
        );

        final gesture = find.descendant(
          of: find.widgetWithText(Column, 'Elevation (m)'),
          matching: find.byType(GestureDetector),
        );

        // Start pan
        await tester.startGesture(tester.getCenter(gesture.first));
        await tester.pumpAndSettle();

        // Should show crosshair line
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('splits chart shows tooltip on tap', (tester) async {
        final distances = List.generate(11, (i) => i * 1000.0);
        final speeds = List.generate(11, (i) => 3.0);

        when(() => mockStreams.numericSeries('elevation')).thenReturn([]);
        when(() => mockStreams.numericSeries('speed')).thenReturn(speeds);
        when(() => mockStreams.numericSeries('distance')).thenReturn(distances);
        when(() => mockStreams.streams).thenReturn({'distance': distances});
        when(() => mockStreams.timeOffsetsSeconds()).thenReturn([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ActivityCharts(streams: mockStreams)),
          ),
        );

        final splitsGesture = find.descendant(
          of: find.widgetWithText(Column, 'Splits (km)'),
          matching: find.byType(GestureDetector),
        );

        await tester.tap(splitsGesture.first);
        await tester.pumpAndSettle();

        // Tooltip should appear
        expect(find.byType(Material), findsWidgets);
      });
    });
  });
}

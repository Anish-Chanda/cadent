import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:cadence/screens/recorder_screen.dart';

void main() {
  group('RecorderScreen - Basic UI Tests', () {
    testWidgets('displays all basic UI elements when idle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      // Verify map is displayed
      expect(find.byType(MapLibreMap), findsOneWidget);

      // Verify top status bar elements
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);

      // Verify bottom floating card is present
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);

      // Verify drag handle is present
      final dragHandle = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 40 &&
            widget.constraints?.maxHeight == 4,
      );
      expect(dragHandle, findsOneWidget);
    });

    testWidgets('displays activity type selector when idle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      // Verify activity type selector is present
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      // Default activity type should be displayed (could be Running, Cycling, etc.)
      // We just verify the dropdown exists
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).border != null,
        ),
        findsWidgets,
      );
    });

    testWidgets('displays time in initial state', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      // Initial time should be displayed (likely 00:00)
      expect(find.text('Time'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains(':'),
        ),
        findsWidgets,
      );
    });

    testWidgets('displays start button when idle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('back button is present', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('center location button is present', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('map has correct initial configuration', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      final mapWidget = tester.widget<MapLibreMap>(find.byType(MapLibreMap));

      // Verify map style
      expect(
        mapWidget.styleString,
        'https://tiles.openfreemap.org/styles/liberty',
      );

      // Verify location tracking is enabled
      expect(mapWidget.myLocationEnabled, true);
      expect(mapWidget.myLocationTrackingMode, MyLocationTrackingMode.tracking);
      expect(mapWidget.myLocationRenderMode, MyLocationRenderMode.normal);

      // Verify initial camera position
      expect(mapWidget.initialCameraPosition.zoom, 14.0);
    });

    testWidgets('floating card has correct styling', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      // Verify card container exists with rounded corners
      final cardContainer = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(20),
      );

      expect(cardContainer, findsWidgets);
    });

    testWidgets('does not show delete button when idle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      // Delete button should not be visible when idle
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('does not show distance and speed stats when idle', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      // Distance and Speed labels should not be visible when idle
      expect(find.text('Distance'), findsNothing);
      expect(find.text('Speed'), findsNothing);
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
                    MaterialPageRoute(builder: (_) => const RecorderScreen()),
                  );
                },
                child: const Text('Open Recorder'),
              ),
            ),
          ),
        ),
      );

      // Navigate to recorder screen
      await tester.tap(find.text('Open Recorder'));
      await tester.pumpAndSettle();

      // Verify we're on recorder screen
      expect(find.byType(RecorderScreen), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify we're back to original screen
      expect(find.byType(RecorderScreen), findsNothing);
      expect(find.text('Open Recorder'), findsOneWidget);
    });

    testWidgets('tapping floating card toggles expanded view', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      // Initially map should be visible
      expect(find.byType(MapLibreMap), findsOneWidget);

      // Find and tap the floating card (tap on the drag handle area)
      final dragHandle = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 40 &&
            widget.constraints?.maxHeight == 4,
      );

      await tester.tap(dragHandle);
      await tester.pumpAndSettle();

      // Map should be hidden in expanded view
      expect(find.byType(MapLibreMap), findsNothing);

      // Collapse button should be visible
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('tapping collapse button returns to map view', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      // Expand the view first
      final dragHandle = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 40 &&
            widget.constraints?.maxHeight == 4,
      );

      await tester.tap(dragHandle);
      await tester.pumpAndSettle();

      // Verify expanded view
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Tap collapse button
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Map should be visible again
      expect(find.byType(MapLibreMap), findsOneWidget);

      // Collapse button should be gone
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('activity type selector opens bottom sheet', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

      await tester.pumpAndSettle();

      // Tap activity type selector
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();

      // Verify bottom sheet is displayed
      expect(find.text('Select Activity Type'), findsOneWidget);
    });

    testWidgets('disposes controllers properly', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecorderScreen()));

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

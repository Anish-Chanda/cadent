import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/screens/finish_activity_screen.dart';

void main() {
  group('FinishActivityScreen', () {
    const testFormattedTime = '30:45';
    const testFormattedDistance = '5.2 km';
    const testActivityName = 'Running';

    testWidgets('displays all UI elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinishActivityScreen(
            formattedTime: testFormattedTime,
            formattedDistance: testFormattedDistance,
            activityName: testActivityName,
          ),
        ),
      );

      // Verify app bar elements
      expect(find.text('Save Activity'), findsNWidgets(2)); // AppBar + Button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Verify activity summary
      expect(find.text(testActivityName), findsOneWidget);
      expect(find.text(testFormattedTime), findsOneWidget);
      expect(find.text(testFormattedDistance), findsOneWidget);

      // Verify labels
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);

      // Verify form fields
      expect(find.byType(TextField), findsNWidgets(2));

      // Verify buttons
      expect(find.text('Discard'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNWidgets(2)); // Both PrimaryButtons use ElevatedButton internally
    });

    testWidgets('initializes title with default value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinishActivityScreen(
            formattedTime: testFormattedTime,
            formattedDistance: testFormattedDistance,
            activityName: testActivityName,
          ),
        ),
      );

      final titleField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Running Activity'),
      );
      expect(titleField.controller?.text, 'Running Activity');
    });

    testWidgets('title field has correct properties', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinishActivityScreen(
            formattedTime: testFormattedTime,
            formattedDistance: testFormattedDistance,
            activityName: testActivityName,
          ),
        ),
      );

      final titleField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Running Activity'),
      );

      expect(titleField.textInputAction, TextInputAction.next);
      expect(titleField.decoration?.hintText, 'Enter activity title');
    });

    testWidgets('description field has correct properties', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinishActivityScreen(
            formattedTime: testFormattedTime,
            formattedDistance: testFormattedDistance,
            activityName: testActivityName,
          ),
        ),
      );

      final descriptionFields = tester.widgetList<TextField>(
        find.byType(TextField),
      );
      final descriptionField = descriptionFields.elementAt(1);

      expect(descriptionField.maxLines, 4);
      expect(descriptionField.textInputAction, TextInputAction.done);
      expect(
        descriptionField.decoration?.hintText,
        'Add a description (optional)',
      );
    });

    testWidgets('returns resume action when back button is pressed', (
      tester,
    ) async {
      Map<String, dynamic>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FinishActivityScreen(
                        formattedTime: testFormattedTime,
                        formattedDistance: testFormattedDistance,
                        activityName: testActivityName,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify result
      expect(result, isNotNull);
      expect(result?['action'], 'resume');
    });

    testWidgets('handles system back button with PopScope', (tester) async {
      Map<String, dynamic>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FinishActivityScreen(
                        formattedTime: testFormattedTime,
                        formattedDistance: testFormattedDistance,
                        activityName: testActivityName,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Simulate system back button
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      // Verify resume action
      expect(result?['action'], 'resume');
    });

    testWidgets('focuses description field when title field submits', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinishActivityScreen(
            formattedTime: testFormattedTime,
            formattedDistance: testFormattedDistance,
            activityName: testActivityName,
          ),
        ),
      );

      // Focus title field
      await tester.tap(find.widgetWithText(TextField, 'Running Activity'));
      await tester.pumpAndSettle();

      // Submit title field
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // Verify description field is focused
      final descriptionFields = find.byType(TextField);
      final descriptionField = tester.widget<TextField>(
        descriptionFields.at(1),
      );
      expect(descriptionField.focusNode?.hasFocus, true);
    });

    testWidgets('displays summary stat cards correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinishActivityScreen(
            formattedTime: testFormattedTime,
            formattedDistance: testFormattedDistance,
            activityName: testActivityName,
          ),
        ),
      );

      // Verify both stat cards are present
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text(testFormattedTime), findsOneWidget);
      expect(find.text(testFormattedDistance), findsOneWidget);
    });

    testWidgets('disposes controllers properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinishActivityScreen(
            formattedTime: testFormattedTime,
            formattedDistance: testFormattedDistance,
            activityName: testActivityName,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Remove the widget to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Empty'))),
      );

      // If dispose wasn't handled properly, this would throw an error
      expect(tester.takeException(), isNull);
    });

    testWidgets('different activity names display correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinishActivityScreen(
            formattedTime: '1:15:30',
            formattedDistance: '25.5 km',
            activityName: 'Cycling',
          ),
        ),
      );

      expect(find.text('Cycling'), findsOneWidget);
      expect(find.text('1:15:30'), findsOneWidget);
      expect(find.text('25.5 km'), findsOneWidget);

      final titleField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Cycling Activity'),
      );
      expect(titleField.controller?.text, 'Cycling Activity');
    });
  });
}

import 'package:cadence/screens/home_screen.dart';
import 'package:cadence/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Mocks/mock_auth_provider.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/activities_provider.dart';
import 'package:cadence/providers/app_settings_provider.dart';
import 'package:cadence/providers/theme_provider.dart';
import 'package:cadence/utils/app_theme.dart';
import 'package:cadence/screens/recorder_screen.dart';
import 'package:cadence/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Initial Page is Home Screen', (WidgetTester tester) async {
    final authProvider = await MockAuthProvider.initialize();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => ActivitiesProvider()),
          ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(AppTheme.lightTheme),
          ),
        ],
        child: const MaterialApp(
          home: MainLayout(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('Change Screen to Settings', (WidgetTester tester) async {
    final authProvider = await MockAuthProvider.initialize();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => ActivitiesProvider()),
          ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(AppTheme.lightTheme),
          ),
        ],
        child: const MaterialApp(
          home: MainLayout(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('Change Screen to Home', (WidgetTester tester) async {
    final authProvider = await MockAuthProvider.initialize();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => ActivitiesProvider()),
          ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(AppTheme.lightTheme),
          ),
        ],
        child: const MaterialApp(
          home: MainLayout(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Change Screen to Recording', (WidgetTester tester) async {
    final authProvider = await MockAuthProvider.initialize();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => ActivitiesProvider()),
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(AppTheme.lightTheme),
          ),
        ],
        child: const MaterialApp(
          home: MainLayout(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(RecorderScreen), findsOneWidget);
  });
}

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Mocks/MockAuthProvider.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/activities_provider.dart';
import 'package:cadence/providers/theme_provider.dart';
import 'package:cadence/router.dart';
import 'package:cadence/utils/app_theme.dart';
import 'package:cadence/screens/activity_detail_screen.dart';
import 'package:cadence/screens/auth/login_screen.dart';
import 'package:cadence/main.dart';
import 'package:cadence/screens/finish_activity_screen.dart';
import 'package:cadence/screens/home_screen.dart';
import 'package:cadence/screens/recorder_screen.dart';
import 'package:cadence/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  testWidgets('Cadent test', (WidgetTester tester) async {
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
        child: const CadenceApp(),
      ),
    );

    await tester.pump(); // Let widgets rebuild with providers

    expect(1, equals(1));
  });

  testWidgets('Login Screen test', (WidgetTester tester) async {
    // TODO: Add proper tests with mocked providers
    await tester.pumpWidget(const LoginScreen());
    expect(1, equals(1));
  });
  testWidgets('HomeScreen test', (WidgetTester tester) async {
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
          home: HomeScreen(),
        ),
      ),
    );
  });
  testWidgets('SettingsScreen test', (WidgetTester tester) async {
    // TODO: Add proper tests with mocked providers
    await tester.pumpWidget(const SettingsScreen());
    expect(1, equals(1));
  });
  testWidgets('RecorderScreen test', (WidgetTester tester) async {
    // TODO: Add proper tests with mocked providers
    await tester.pumpWidget(const RecorderScreen());
    expect(1, equals(1));
  });
  testWidgets('ActivityDetailScreen test', (WidgetTester tester) async {
    // TODO: Add proper tests with mocked providers
    //await tester.pumpWidget(const ActivityDetailScreen(activity: activity));
    expect(1, equals(1));
  });
  testWidgets('FinishActivityScreen test', (WidgetTester tester) async {
    // TODO: Add proper tests with mocked providers
    await tester.pumpWidget(const FinishActivityScreen(formattedTime: '1:24:49', formattedDistance: '5 mi', activityName: "testActivity"));
    expect(1, equals(1));
  });
}

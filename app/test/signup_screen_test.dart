import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:cadence/screens/auth/signup_screen.dart';
import 'package:cadence/providers/auth_provider.dart';

import 'Mocks/mock_auth_provider.dart';

void main() {
  group('SignupScreen', () {
    late MockAuthProvider mockAuthProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();

      // Set up default stub behaviors
      when(() => mockAuthProvider.isLoading).thenReturn(false);
      when(
        () => mockAuthProvider.serverUrl,
      ).thenReturn('http://mock-server.test');
      when(() => mockAuthProvider.status).thenReturn(AuthStatus.unauthenticated);
      when(() => mockAuthProvider.email).thenReturn(null);

      // Stub async methods with default behavior
      when(
        () => mockAuthProvider.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => 'mock-user-id');

      when(
        () => mockAuthProvider.updateServerUrl(any()),
      ).thenAnswer((_) async {});
    });

    testWidgets('displays all UI elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const SignupScreen(),
          ),
        ),
      );

      // Verify main elements
      expect(find.text('Sign Up'), findsOneWidget); // AppBar title
      expect(find.text('Join Cadence'), findsOneWidget);
      expect(find.text('Create your account to get started'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text("Already have an account? "), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Logging into:'), findsOneWidget);

      // Verify form fields
      expect(
        find.byType(TextFormField),
        findsNWidgets(4),
      ); // Name, Email, Password, Confirm Password
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // Verify logo/icon
      expect(find.text('C'), findsOneWidget); // Logo letter
    });

    testWidgets('displays server URL at bottom', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const SignupScreen(),
          ),
        ),
      );

      expect(find.text('Logging into:'), findsOneWidget);
      expect(find.text('http://mock-server.test'), findsOneWidget);
    });

    testWidgets('updates server URL through dialog', (tester) async {
      // Override updateServerUrl to change the returned value
      when(
        () => mockAuthProvider.updateServerUrl('http://new-server.test'),
      ).thenAnswer((_) async {
        when(
          () => mockAuthProvider.serverUrl,
        ).thenReturn('http://new-server.test');
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const SignupScreen(),
          ),
        ),
      );

      // Open server URL dialog
      await tester.tap(find.text('http://mock-server.test'));
      await tester.pumpAndSettle();

      // Enter new server URL
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Server URL'),
        'http://new-server.test',
      );

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify updateServerUrl was called
      verify(
        () => mockAuthProvider.updateServerUrl('http://new-server.test'),
      ).called(1);

      // Verify server URL was updated
      expect(mockAuthProvider.serverUrl, 'http://new-server.test');
    });

    testWidgets('cancels server URL dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const SignupScreen(),
          ),
        ),
      );

      final originalUrl = mockAuthProvider.serverUrl;

      // Open server URL dialog
      await tester.tap(find.text('http://mock-server.test'));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify server URL was not changed
      expect(mockAuthProvider.serverUrl, originalUrl);
      // Verify dialog is closed
      expect(find.text('Server URL'), findsNothing);

      // Verify updateServerUrl was never called
      verifyNever(() => mockAuthProvider.updateServerUrl(any()));
    });
  });
}

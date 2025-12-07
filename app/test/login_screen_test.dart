import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:cadence/screens/auth/login_screen.dart';
import 'package:cadence/providers/auth_provider.dart';

import 'Mocks/mock_auth_provider.dart';

void main() {
  group('LoginScreen', () {
    late MockAuthProvider mockAuthProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();

      // Set up default stub behaviors
      when(() => mockAuthProvider.isLoading).thenReturn(false);
      when(
        () => mockAuthProvider.serverUrl,
      ).thenReturn('http://mock-server.test');
      when(() => mockAuthProvider.status).thenReturn(AuthStatus.unauthenticated);
      when(
        () => mockAuthProvider.email,
      ).thenReturn(null); // Nullable email

      // Stub async methods with default behavior
      when(
        () => mockAuthProvider.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockAuthProvider.updateServerUrl(any()),
      ).thenAnswer((_) async {});
    });

    testWidgets('displays all UI elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const LoginScreen(),
          ),
        ),
      );

      // Verify main elements
      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text("Don't have an account? "), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);
      expect(find.text('Logging into:'), findsOneWidget);

      // Verify form fields
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify logo
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('displays server URL at bottom', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const LoginScreen(),
          ),
        ),
      );

      expect(find.text('Logging into:'), findsOneWidget);
      expect(find.text('http://mock-server.test'), findsOneWidget);
    });

    testWidgets('validates empty email', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const LoginScreen(),
          ),
        ),
      );

      // Tap login without entering email
      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('validates invalid email format', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const LoginScreen(),
          ),
        ),
      );

      // Enter invalid email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'invalidemail',
      );
      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('validates empty password', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const LoginScreen(),
          ),
        ),
      );

      // Enter only email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('successfully logs in with valid credentials', (tester) async {
      // Override login behavior for successful login
      when(
        () => mockAuthProvider.login(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async {
        // Simulate successful login by updating the mock state
        when(() => mockAuthProvider.status).thenReturn(AuthStatus.authenticated);
        when(() => mockAuthProvider.email).thenReturn('test@example.com');
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const LoginScreen(),
          ),
        ),
      );

      // Enter valid credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      // Tap login button
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Verify login was called with correct credentials
      verify(
        () => mockAuthProvider.login(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).called(1);

      // Verify authentication state
      expect(mockAuthProvider.status, AuthStatus.authenticated);
      expect(mockAuthProvider.email, 'test@example.com');
    });

    testWidgets('shows error message on unsuccessful login', (tester) async {
      // Make login throw an exception
      when(
        () => mockAuthProvider.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(Exception('Invalid credentials'));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const LoginScreen(),
          ),
        ),
      );

      // Enter credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'wrong@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrongpassword',
      );

      // Tap login
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Verify error is shown and user is not logged in
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Login failed'), findsOneWidget);
      expect(mockAuthProvider.status, AuthStatus.unauthenticated);
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
            child: const LoginScreen(),
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
            child: const LoginScreen(),
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

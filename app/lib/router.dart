import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './providers/auth_provider.dart';
import './screens/home_screen.dart';
import './screens/auth/login_screen.dart';

// Main app navigation widget and handles auth state
class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper(
      authenticatedChild: HomeScreen(),
    );
  }
}


class AuthWrapper extends StatelessWidget {
  final Widget authenticatedChild;

  const AuthWrapper({super.key, required this.authenticatedChild});

  @override
  Widget build(BuildContext context) {
    log('Checking auth state in AuthWrapper');
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Show loading indicator while checking auth state
        if (auth.isCheckingAuthState) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Route based on authentication state
        if (auth.isAuthenticated) {
          log('User is authenticated, navigating to home screen');
          return authenticatedChild;
        } else {
          log('User is not authenticated, navigating to login screen');
          return const LoginScreen();
        }
      },
    );
  }
}

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './providers/auth_provider.dart';
import './widgets/main_layout.dart';
import './screens/auth/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        developer.log(
          'AuthWrapper: Rendering screen for auth status: ${authProvider.status}', 
          name: 'ferna.router'
        );
        
        switch (authProvider.status) {
          case AuthStatus.authenticated:
            developer.log('AuthWrapper: User is authenticated, showing home screen', name: 'ferna.router');
            return const MainLayout();
          
          case AuthStatus.unauthenticated:
            developer.log('AuthWrapper: User is not authenticated, showing auth screen', name: 'ferna.router');
            return const LoginScreen();
          
          case AuthStatus.unknown:
            developer.log('AuthWrapper: Auth status unknown, showing loading screen', name: 'ferna.router');
            return const _LoadingScreen();
        }
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

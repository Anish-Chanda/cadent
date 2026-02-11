import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './providers/auth_provider.dart';
import './providers/activities_provider.dart';
import './providers/app_settings_provider.dart';
import './providers/theme_provider.dart';
import './router.dart';
import './utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize auth provider
  final authProvider = await AuthProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ActivitiesProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(AppTheme.lightTheme),
        ),
      ],
      child: const CadenceApp(),
    ),
  );
}

class CadenceApp extends StatelessWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppSettingsProvider, ThemeProvider>(
      builder: (context, settingsController, themeProvider, child) {
        final ThemeData appTheme = settingsController.isDarkMode
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;

        // Keep ThemeProvider in sync for any other consumers that may use it
        if (themeProvider.getTheme() != appTheme) {
          // Avoid notifying during build if already equal
          WidgetsBinding.instance.addPostFrameCallback((_) {
            themeProvider.setTheme(appTheme);
          });
        }

        return MaterialApp(
          title: 'Cadent',
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

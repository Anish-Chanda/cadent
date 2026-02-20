import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './providers/auth_provider.dart';
import './providers/activities_provider.dart';
import './providers/app_settings_provider.dart';
import './providers/theme_provider.dart';
import './router.dart';
import './utils/app_theme.dart';
import './services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize auth provider
  final authProvider = await AuthProvider.initialize();

  await initializeService();

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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Cadent',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.getTheme(),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

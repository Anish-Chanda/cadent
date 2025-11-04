import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './providers/auth_provider.dart';
import './providers/activities_provider.dart';
import './router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize auth provider
   final authProvider = await AuthProvider.initialize();

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ChangeNotifierProvider<ActivitiesProvider>(create: (_) => ActivitiesProvider()),
  ], child: CadenceApp()));
}

class CadenceApp extends StatelessWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadence',
      debugShowCheckedModeBanner: false,
      // theme: CadenceTheme.light,
      // darkTheme: CadenceTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppNavigator(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './providers/auth_provider.dart';
import './router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize auth provider
   final authProvider = await AuthProvider.initialize();

   FlutterError.onError = (details) {
     FlutterError.presentError(details);
   };

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: authProvider)
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
      builder: (context, widget) {
        Widget error = const Text('...rendering error...');
        if(widget is Scaffold || widget is Navigator){
          error = Scaffold(body: Center(
              child:Column(
                children: [
                  error,
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child:Text('Go Back'),
                  )
                ],
          )));
        }
        ErrorWidget.builder = (errorDetails) => error;
        if(widget != null) return widget;
        throw StateError('widget is null');
      }

    );
  }
}

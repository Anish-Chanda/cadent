
import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0x0059c4f7),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    iconTheme: const IconThemeData(
      color: Colors.blue,
    )
  );

  static final ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0x0059c4f7),
      brightness: Brightness.dark,
    ),
      useMaterial3: true,
      iconTheme: const IconThemeData(
        color: Colors.blue,
      )
  );
}

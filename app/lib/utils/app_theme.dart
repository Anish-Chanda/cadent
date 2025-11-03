
import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: Colors.grey.shade300,
    primaryColor: Colors.blue,
    colorScheme: const ColorScheme.light(),
    iconTheme: const IconThemeData(color: Colors.blue, opacity: 0.8),
  );

  static final ThemeData darkTheme = ThemeData(
      scaffoldBackgroundColor: Colors.black,
      primaryColor: Colors.blueGrey,
      colorScheme: const ColorScheme.dark(),
      iconTheme: const IconThemeData(color: Colors.blue, opacity: 0.8));
}

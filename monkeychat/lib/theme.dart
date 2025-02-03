import 'package:flutter/material.dart';

final darkTheme = ThemeData(
  primarySwatch: Colors.blueGrey,
  scaffoldBackgroundColor: const Color(0xFF121212),
  colorScheme: ColorScheme.dark(
    primary: Colors.blueGrey,
    secondary: Colors.blueGrey[300]!,
  ),
  appBarTheme: const AppBarTheme(
    color: Color(0xFF1E1E1E),
  ),
  dividerColor: Colors.white24,
);

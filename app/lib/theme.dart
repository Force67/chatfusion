import 'package:flutter/material.dart';

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0F1113), // Deeper Black

  colorScheme: ColorScheme.dark(
    primary: const Color(0xFF5469D4), // More muted primary color
    secondary: const Color(0xFF7881A5), // Muted secondary color
    surface: const Color(0xFF1A1E21), // A softer background color
    background: const Color(0xFF0F1113),
    error: const Color(0xFFCF6679),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
    onBackground: Colors.white,
    onError: Colors.black,

    surfaceVariant: const Color(0xFF262C31), //Even darker for Input Fields
  ),

  appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F1113), // Consistent AppBar,
      elevation: 0, //Remove the shadow on the AppBar

      titleTextStyle: TextStyle(
        fontFamily: 'SFProDisplay',
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Colors.white)),

  textTheme: const TextTheme(
      bodyLarge: TextStyle(
          color: Colors.white,
          fontFamily: 'SFProDisplay',
          fontSize: 16), //More readable defaults
      bodyMedium: TextStyle(
          color: Colors.white70, fontFamily: 'SFProDisplay', fontSize: 14),
      bodySmall: TextStyle(
          color: Colors.white54, fontFamily: 'SFProDisplay', fontSize: 12),
      headlineLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontFamily: 'SFProDisplay',
          fontSize: 32),
      headlineMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontFamily: 'SFProDisplay',
          fontSize: 24),
      headlineSmall: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontFamily: 'SFProDisplay',
          fontSize: 20),
      titleLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontFamily: 'SFProDisplay',
          fontSize: 18),
      titleMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontFamily: 'SFProDisplay',
          fontSize: 16),
      titleSmall: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontFamily: 'SFProDisplay',
          fontSize: 14),
      labelLarge: TextStyle(
          color: Colors.white,
          fontFamily: 'SFUIDisplay',
          fontWeight: FontWeight.w600,
          fontSize: 16),
      labelMedium: TextStyle(
          color: Colors.white,
          fontFamily: 'SFUIDisplay',
          fontWeight: FontWeight.w600,
          fontSize: 14),
      labelSmall: TextStyle(
          color: Colors.white,
          fontFamily: 'SFUIDisplay',
          fontWeight: FontWeight.w500,
          fontSize: 12)),

  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8), // Smaller Radius for sleekness
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: const Color(0xFF262C31),
    labelStyle: const TextStyle(
        color: Colors.white70, fontFamily: 'SFProDisplay'), //Use font
    hintStyle:
        const TextStyle(color: Colors.white54, fontFamily: 'SFProDisplay'),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 12), // Adjusted padding
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF5469D4), //Primary button color
      foregroundColor: Colors.white,
      textStyle: const TextStyle(
          fontWeight: FontWeight.w600, fontFamily: 'SFUIDisplay'), //font
      padding: const EdgeInsets.symmetric(
          vertical: 12, horizontal: 20), // Adjusted padding
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // Smaller Radius
      ),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF7881A5), //Muted secondary for outline
      side: const BorderSide(color: Color(0xFF7881A5)),
      textStyle: const TextStyle(
          fontWeight: FontWeight.w600, fontFamily: 'SFUIDisplay'), //font
      padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 20), //Adjusted
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),

  cardTheme: const CardTheme(
    color: Color(0xFF1A1E21), //Softer card color
    elevation: 0, //Remove Elevation
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)), //Small radius
    ),
  ),

  dialogTheme: const DialogTheme(
    backgroundColor: Color(0xFF1A1E21),
    titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'SFProDisplay'), //Fonts

    contentTextStyle:
        TextStyle(color: Colors.white70, fontFamily: 'SFProDisplay'),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),

  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFF1A1E21),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
          top: Radius.circular(12)), //Slightly bigger on the bottom sheets
    ),
  ),

  dividerColor: Colors.white12, // More subtle divider

  useMaterial3: true,
);

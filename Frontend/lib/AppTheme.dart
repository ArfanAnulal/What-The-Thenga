import 'package:flutter/material.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    // Define a fun and vibrant color scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.orangeAccent,
      primary: Colors.orangeAccent,
      secondary: Colors.lightBlueAccent,
      background: Colors.yellow[100]!,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.yellow[100],

    // Update AppBar theme
    appBarTheme: const AppBarTheme(
      color: Colors.transparent, // Make it transparent to show the gradient
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'NoyhR',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      actionsPadding: EdgeInsets.all(8),
    ),

    // Define fun text themes
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontFamily: 'NoyhR',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        shadows: [
          Shadow(
            blurRadius: 10.0,
            color: Colors.white,
            offset: Offset(2.0, 2.0),
          ),
        ],
      ),
      bodyMedium: TextStyle(
        fontFamily: 'NoyhR',
        fontSize: 16,
        color: Colors.black54,
      ),
    ),
  );
}

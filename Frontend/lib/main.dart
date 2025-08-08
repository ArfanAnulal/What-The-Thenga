import 'package:coconut/appTheme.dart';
import 'package:coconut/homepage.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'What the Thenga',
      theme: AppTheme.lightTheme,
      home: const MyHomePage(title: 'What the Thenga'),
    );
  }
}


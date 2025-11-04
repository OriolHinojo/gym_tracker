import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  const Color seed = Color(0xFF3E8E7E);
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: seed);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

ThemeData buildDarkTheme() {
  const Color seed = Color(0xFF3E8E7E);
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}



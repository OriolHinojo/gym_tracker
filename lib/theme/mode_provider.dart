import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current theme mode (system by default)
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

/// Helper to cycle system -> light -> dark -> system
ThemeMode nextThemeMode(ThemeMode current) {
  switch (current) {
    case ThemeMode.system:
      return ThemeMode.light;
    case ThemeMode.light:
      return ThemeMode.dark;
    case ThemeMode.dark:
      return ThemeMode.system;
  }
}

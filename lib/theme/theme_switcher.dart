import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mode_provider.dart';

class ThemeSwitcher extends ConsumerWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    IconData icon;
    String tooltip;

    switch (mode) {
      case ThemeMode.system:
        icon = Icons.brightness_auto_rounded;
        tooltip = 'System theme';
        break;
      case ThemeMode.light:
        icon = Icons.light_mode_rounded;
        tooltip = 'Light theme';
        break;
      case ThemeMode.dark:
        icon = Icons.dark_mode_rounded;
        tooltip = 'Dark theme';
        break;
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: () =>
          ref.read(themeModeProvider.notifier).state = nextThemeMode(mode),
      icon: Icon(icon),
    );
  }
}

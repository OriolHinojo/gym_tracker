import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/theme.dart';
import 'theme/mode_provider.dart';

class IronPulseApp extends ConsumerWidget {
  const IronPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final ThemeData light = buildLightTheme();
    final ThemeData dark = buildDarkTheme();
    final ThemeMode mode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'GainzTracker',
      theme: light,
      darkTheme: dark,
      themeMode: mode, // <-- controlled by Riverpod
      routerConfig: router,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return SafeArea(
          top: true,
          bottom: false,
          left: true,
          right: true,
          child: child,
        );
      },
    );
  }
}

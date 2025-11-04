import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/theme.dart';

class IronPulseApp extends ConsumerWidget {
  const IronPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final ThemeData light = buildLightTheme();
    final ThemeData dark = buildDarkTheme();

    return MaterialApp.router(
      title: 'IronPulse',
      theme: light,
      darkTheme: dark,
      routerConfig: router,
    );
  }
}



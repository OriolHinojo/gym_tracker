import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/home/home_screen.dart';
import 'screens/library/exercise_detail_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/log/log_screen.dart';
import 'screens/log/workout_detail_screen.dart';
import 'screens/more/more_screen.dart';
import 'screens/progress/progress_screen.dart';

final Provider<GoRouter> appRouterProvider = Provider((ref) {
  final GlobalKey<NavigatorState> rootKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return WillPopScope(
            onWillPop: () async {
              final router = GoRouter.of(context);
              if (router.canPop()) {
                router.pop();
                return false;
              }
              if (navigationShell.currentIndex != 0) {
                navigationShell.goBranch(0);
                return false;
              }
              return true;
            },
            child: Scaffold(
              body: navigationShell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                destinations: const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.edit_outlined),
                    selectedIcon: Icon(Icons.edit),
                    label: 'Log',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.show_chart_outlined),
                    selectedIcon: Icon(Icons.show_chart),
                    label: 'Progress',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.fitness_center_outlined),
                    selectedIcon: Icon(Icons.fitness_center),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    selectedIcon: Icon(Icons.more_horiz),
                    label: 'More',
                  ),
                ],
                onDestinationSelected: navigationShell.goBranch,
              ),
            ),
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: '/log',
              name: 'log',
              builder: (context, state) {
                final extra = state.extra;
                int? templateId;
                int? editWorkoutId;
                if (extra is Map) {
                  if (extra['templateId'] is int) {
                    templateId = extra['templateId'] as int;
                  }
                  if (extra['editWorkoutId'] is int) {
                    editWorkoutId = extra['editWorkoutId'] as int;
                  }
                }
                return LogScreen(templateId: templateId, editWorkoutId: editWorkoutId);
              },
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: '/progress',
              name: 'progress',
              builder: (context, state) => const ProgressScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: '/library',
              name: 'library',
              builder: (context, state) => const LibraryScreen(),
            ),
            GoRoute(
              path: '/library/exercise/:id',
              name: 'exerciseDetail',
              builder: (context, state) =>
                  ExerciseDetailScreen(id: int.parse(state.pathParameters['id']!)),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: '/more',
              name: 'more',
              builder: (context, state) => const MoreScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/sessions/:id',
        name: 'sessionDetail',
        builder: (context, state) =>
            WorkoutDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      // Keep deep link to open an existing workout id (optional)
      GoRoute(
        path: '/workout/:id',
        name: 'workout',
        builder: (context, state) =>
            LogScreen(workoutId: state.pathParameters['id']),
      ),
    ],
  );
});

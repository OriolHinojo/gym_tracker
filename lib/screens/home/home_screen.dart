// HomeScreen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/models/home_highlight.dart';
import 'package:gym_tracker/screens/home/home_calendar_sheet.dart';
import 'package:gym_tracker/screens/home/home_highlights_sheet.dart';
import 'package:gym_tracker/shared/formatting.dart';
import 'package:gym_tracker/shared/weight_units.dart';
import 'package:gym_tracker/shared/session_detail.dart';
import 'package:gym_tracker/theme/theme.dart' show BrandColors;
import 'package:gym_tracker/widgets/session_preview_sheet.dart';

/// Home Screen
class HomeScreen extends StatelessWidget {
  /// Constructor
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final brand = Theme.of(context).extension<BrandColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GainzTracker'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  brand.gradientStart,
                  brand.gradientEnd,
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Overview', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          // === Rebuild when preferred_exercise_id changes ===
          ValueListenableBuilder<int?>(
            valueListenable: LocalStore.instance.preferredExerciseIdListenable,
            builder: (context, _, __) {
              return ValueListenableBuilder<WeightUnit>(
                valueListenable: LocalStore.instance.weightUnitListenable,
                builder: (context, unit, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: LocalStore.instance.workoutsRevisionListenable,
                    builder: (context, __, _) {
                      return FutureBuilder<HomeStats>(
                        future: LocalStore.instance.getHomeStats(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 120,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snap.hasError) {
                            return const SizedBox(
                              height: 120,
                              child: Center(child: Text('Failed to load stats')),
                            );
                          }
                          final stats = snap.data ?? const HomeStats(0, 0.0, '—', null, '—');
                          final items = stats.toItems(
                            unit: unit,
                            onTapWeekly: (ctx) => showHomeCalendarSheet(ctx),
                          );
                          return _SummaryGrid(items: items);
                        },
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 16),
          const _RecentSessionsCard(),
          const SizedBox(height: 16),
          const _Highlights(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_fab',
        onPressed: () => context.go('/log'),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Quick Start'),
      ),
    );
  }
}

// ---------- HomeStats Extension ----------

extension on HomeStats {
  String get lastWorkoutTitle {
    if (lastWorkoutName == '—') return '—';
    final trimmed = lastWorkoutName.trim();
    return trimmed.isEmpty ? 'Workout' : trimmed;
  }

  String? get lastWorkoutSubtitle {
    if (lastWorkoutName == '—') return null;
    final dt = lastWorkoutStartedAt?.toLocal();
    if (dt == null) return 'Unknown date';
    return '${formatDateYmd(dt)} · ${formatTimeHm(dt)}';
  }

  String get lastWorkoutRoute {
    final id = lastWorkoutId;
    if (lastWorkoutName == '—' || id == null) return '/log';
    return '/sessions/$id';
  }

  List<_StatItem> toItems({
    void Function(BuildContext context)? onTapWeekly,
    required WeightUnit unit,
  }) =>
      [
        _StatItem(
          'This Week',
          weeklySessions.toString(),
          'sessions',
          Icons.calendar_today_rounded,
          '/',
          onTap: onTapWeekly,
        ),
        _StatItem(
          'Trend — $favouriteExercise',
          formatWeightDelta(e1rmDelta, unit),
          '${unit.label} e1RM',
          Icons.show_chart_rounded,
          '/progress',
          positive: e1rmDelta >= 0,
        ),
        _StatItem(
          'Last Session',
          lastWorkoutTitle,
          null,
          Icons.fitness_center_rounded,
          lastWorkoutRoute,
          textOnly: true,
          subtitle: lastWorkoutSubtitle,
        ),
      ];
}

// ---------- Recent Sessions ----------

class _RecentSessionsCard extends StatelessWidget {
  const _RecentSessionsCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<int>(
      valueListenable: LocalStore.instance.workoutsRevisionListenable,
      builder: (context, __, ___) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: LocalStore.instance.listRecentWorkoutsRaw(limit: 5),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return Card(
                child: SizedBox(
                  height: 140,
                  child: Center(
                    child: CircularProgressIndicator(color: scheme.primary),
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not load recent sessions.',
                    style: textTheme.bodyMedium,
                  ),
                ),
              );
            }

            final sessions = (snap.data ?? const <Map<String, dynamic>>[])
                .where((s) => s['id'] != null)
                .toList();

            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Sessions',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    if (sessions.isEmpty)
                      Text(
                        'Log a workout to see it listed here.',
                        style: textTheme.bodyMedium,
                      )
                    else
                      ..._buildSessionTiles(context, sessions, scheme, textTheme),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildSessionTiles(
    BuildContext context,
    List<Map<String, dynamic>> sessions,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final tiles = <Widget>[];
    for (int i = 0; i < sessions.length; i++) {
      final workout = sessions[i];
      final id = (workout['id'] as num).toInt();
      final name = (workout['name'] ?? '').toString().trim().isEmpty
          ? 'Workout'
          : (workout['name'] ?? '').toString();
      final started = (workout['started_at'] ?? '').toString();

      tiles.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(name, style: textTheme.bodyLarge),
          subtitle: Text(_formatTimestamp(started), style: textTheme.bodySmall),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/sessions/$id'),
        ),
      );

      if (i < sessions.length - 1) {
        tiles.add(const Divider(height: 1));
      }
    }
    return tiles;
  }

  String _formatTimestamp(String iso) =>
      formatIso8601ToLocal(iso, separator: ' · ');
}

// ---------- Summary Grid ----------

class _SummaryGrid extends StatelessWidget {
  final List<_StatItem> items;
  const _SummaryGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final viewportWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = viewportWidth >= 920
            ? 3
            : viewportWidth >= 620
                ? 2
                : 1;
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = columns <= 1
            ? viewportWidth
            : ((viewportWidth - totalSpacing) > 0
                    ? (viewportWidth - totalSpacing)
                    : viewportWidth) /
                columns;

        return Wrap(
          spacing: columns > 1 ? spacing : 0,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _StatCard(item),
              ),
          ],
        );
      },
    );
  }
}

class _StatItem {
  const _StatItem(this.title, this.value, this.suffix, this.icon, this.route,
      {this.positive, this.textOnly = false, this.subtitle, this.onTap});
  final String title;
  final String value;
  final String? suffix;
  final IconData icon;
  final String route;
  final bool? positive;
  final bool textOnly;
  final String? subtitle;
  final void Function(BuildContext context)? onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.item);
  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final brand = Theme.of(context).extension<BrandColors>()!;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (item.onTap != null) {
          item.onTap!(context);
          return;
        }
        if (item.route.startsWith('/sessions/')) {
          context.push(item.route);
        } else {
          context.go(item.route);
        }
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              brand.gradientStart.withOpacity(0.16),
              brand.gradientEnd.withOpacity(0.16),
            ],
          ),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer.withOpacity(0.6),
                ),
                child: Icon(item.icon, size: 20, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: t.titleMedium),
                    const SizedBox(height: 4),
                    item.textOnly
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.value, style: t.bodyLarge),
                              if ((item.subtitle ?? '').isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle!,
                                  style: t.bodySmall?.copyWith(
                                    color: scheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              Text(item.value,
                                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                              if (item.suffix != null) ...[
                                const SizedBox(width: 6),
                                Text(item.suffix!, style: t.titleSmall),
                              ],
                              if (item.positive != null) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  item.positive!
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 18,
                                  color: item.positive!
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                              ],
                            ],
                          ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Highlights ----------

class _Highlights extends StatelessWidget {
  const _Highlights();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return ValueListenableBuilder<int>(
      valueListenable: LocalStore.instance.workoutsRevisionListenable,
      builder: (context, __, ___) {
        return ValueListenableBuilder<WeightUnit>(
          valueListenable: LocalStore.instance.weightUnitListenable,
          builder: (context, ___, ____) {
            return FutureBuilder<List<HomeHighlight>>(
              future: LocalStore.instance.listHomeHighlights(),
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
                final highlights = snapshot.data ?? const <HomeHighlight>[];

                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surface.withOpacity(0.35),
                        border: Border.all(color: scheme.outlineVariant.withOpacity(0.25)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Highlights',
                                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: highlights.isEmpty
                                      ? null
                                      : () => showHomeHighlightsSheet(context),
                                  child: const Text('See all'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (isLoading)
                              SizedBox(
                                height: 96,
                                child: Center(
                                  child: CircularProgressIndicator(color: scheme.primary),
                                ),
                              )
                            else if (highlights.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Log a workout to unlock highlights.',
                                  style: t.bodyMedium,
                                ),
                              )
                            else
                              ..._buildHighlightTiles(highlights, scheme, t),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _buildHighlightTiles(
    List<HomeHighlight> highlights,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final tiles = <Widget>[];
    for (int i = 0; i < highlights.length; i++) {
      final item = highlights[i];
      tiles.add(
        ListTile(
          dense: true,
          leading: Icon(_iconForType(item.type)),
          title: Text(item.title, style: textTheme.titleSmall),
          subtitle: Text(item.subtitle, style: textTheme.bodySmall),
        ),
      );
      if (i < highlights.length - 1) {
        tiles.add(Divider(color: scheme.outlineVariant.withOpacity(0.25)));
      }
    }
    return tiles;
  }

  IconData _iconForType(HomeHighlightType type) {
    switch (type) {
      case HomeHighlightType.pr:
        return Icons.emoji_events_outlined;
      case HomeHighlightType.trend:
        return Icons.trending_up_rounded;
      case HomeHighlightType.consistency:
        return Icons.auto_graph_rounded;
    }
  }
}

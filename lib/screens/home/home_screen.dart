// HomeScreen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/theme/theme.dart' show BrandColors;
import 'package:gym_tracker/data/local/local_store.dart';

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
        title: const Text('IronPulse'),
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
            builder: (context, favId, _) {
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
                  return _SummaryGrid(items: stats.toItems());
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
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${dt.year}-${two(dt.month)}-${two(dt.day)}';
    final time = '${two(dt.hour)}:${two(dt.minute)}';
    return '$date · $time';
  }

  String get lastWorkoutRoute {
    final id = lastWorkoutId;
    if (lastWorkoutName == '—' || id == null) return '/log';
    return '/sessions/$id';
  }

  List<_StatItem> toItems() => [
        _StatItem(
          'This Week',
          weeklySessions.toString(),
          'sessions',
          Icons.calendar_today_rounded,
          '/',
        ),
        _StatItem(
          'Trend — $favouriteExercise',
          '${e1rmDelta >= 0 ? '+' : ''}$e1rmDelta',
          'kg e1RM',
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
          trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
          onTap: () => context.go('/sessions/$id'),
        ),
      );

      if (i < sessions.length - 1) {
        tiles.add(const Divider(height: 1));
      }
    }
    return tiles;
  }

  String _formatTimestamp(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Unknown date';
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${dt.year}-${two(dt.month)}-${two(dt.day)}';
    final time = '${two(dt.hour)}:${two(dt.minute)}';
    return '$date · $time';
  }
}

// ---------- Summary Grid ----------

class _SummaryGrid extends StatelessWidget {
  final List<_StatItem> items;
  const _SummaryGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cross = c.maxWidth >= 560 ? 3 : 1;
      return GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cross == 1 ? 2.8 : 1.9,
        ),
        itemBuilder: (_, i) => _StatCard(items[i]),
      );
    });
  }
}

class _StatItem {
  const _StatItem(this.title, this.value, this.suffix, this.icon, this.route,
      {this.positive, this.textOnly = false, this.subtitle});
  final String title;
  final String value;
  final String? suffix;
  final IconData icon;
  final String route;
  final bool? positive;
  final bool textOnly;
  final String? subtitle;
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
      onTap: () => context.go(item.route),
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
              Expanded(
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
                Row(children: [
                  Text('Highlights',
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(onPressed: () {}, child: const Text('See all')),
                ]),
                const SizedBox(height: 8),
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.emoji_events_outlined),
                  title: Text('New 5RM PR on Bench'),
                  subtitle: Text('Great job! Keep the momentum.'),
                ),
                Divider(color: scheme.outlineVariant.withOpacity(0.25)),
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.trending_up_rounded),
                  title: Text('e1RM +2.5 kg on Squat'),
                  subtitle: Text('Progress trending up this week.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

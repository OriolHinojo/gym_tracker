import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/theme/theme_switcher.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IronPulse'),
        actions: const [
          ThemeSwitcher(), // 🌗 toggle light/dark/system
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withOpacity(0.4),
                  scheme.secondary.withOpacity(0.25),
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
          const _SummaryGrid(),
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

// ---------- Summary ----------

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid();

  @override
  Widget build(BuildContext context) {
    final items = const [
      _StatItem('This Week', '3', 'sessions', Icons.calendar_today_rounded, '/'),
      _StatItem('Trend', '+2.5', 'kg e1RM', Icons.show_chart_rounded, '/progress', positive: true),
      _StatItem('Last Session', 'Bench, Squat', null, Icons.fitness_center_rounded, '/log', textOnly: true),
    ];

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
      {this.positive, this.textOnly = false});
  final String title;
  final String value;
  final String? suffix;
  final IconData icon;
  final String route;
  final bool? positive;
  final bool textOnly;
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.item, {super.key});
  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go(item.route),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.surfaceVariant.withOpacity(0.35), scheme.primary.withOpacity(0.12)],
          ),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
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
                        ? Text(item.value, style: t.bodyLarge)
                        : Row(
                            children: [
                              Text(item.value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                              if (item.suffix != null) ...[
                                const SizedBox(width: 6),
                                Text(item.suffix!, style: t.titleSmall),
                              ],
                              if (item.positive != null) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  item.positive! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  size: 18,
                                  color: item.positive! ? Colors.greenAccent : Colors.redAccent,
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
                  Text('Highlights', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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

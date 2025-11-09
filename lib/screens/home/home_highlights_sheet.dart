import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/models/home_highlight.dart';
import 'package:gym_tracker/shared/formatting.dart';

/// Presents the full highlight list in a modal sheet.
Future<void> showHomeHighlightsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const FractionallySizedBox(
      heightFactor: 0.85,
      child: _HomeHighlightsSheet(),
    ),
  );
}

class _HomeHighlightsSheet extends StatefulWidget {
  const _HomeHighlightsSheet();

  @override
  State<_HomeHighlightsSheet> createState() => _HomeHighlightsSheetState();
}

class _HomeHighlightsSheetState extends State<_HomeHighlightsSheet> {
  late Future<List<HomeHighlight>> _future;

  @override
  void initState() {
    super.initState();
    _future = LocalStore.instance.listHomeHighlights(limit: null);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<HomeHighlight>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _SheetScaffold(
                title: 'Highlights',
                onClose: () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Text(
                    'We couldn’t load your highlights right now.',
                    style: textTheme.bodyMedium,
                  ),
                ),
              );
            }

            final highlights = snapshot.data ?? const <HomeHighlight>[];
            if (highlights.isEmpty) {
              return _SheetScaffold(
                title: 'Highlights',
                onClose: () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Text(
                    'Log a few workouts to unlock highlight insights.',
                    style: textTheme.bodyMedium,
                  ),
                ),
              );
            }

            return _SheetScaffold(
              title: 'Highlights',
              onClose: () => Navigator.of(context).maybePop(),
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 16),
                itemBuilder: (context, index) => _HighlightTile(
                  highlight: highlights[index],
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                separatorBuilder: (context, _) =>
                    Divider(color: colorScheme.outlineVariant.withOpacity(0.25)),
                itemCount: highlights.length,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.highlight,
    required this.textTheme,
    required this.colorScheme,
  });

  final HomeHighlight highlight;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

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

  @override
  Widget build(BuildContext context) {
    final localTime = highlight.createdAt.toLocal();
    final timestamp = '${formatDateYmd(localTime)} · ${formatTimeHm(localTime)}';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary.withOpacity(0.12),
        foregroundColor: colorScheme.primary,
        child: Icon(_iconForType(highlight.type)),
      ),
      title: Text(highlight.title, style: textTheme.titleMedium),
      subtitle: Text(
        '${highlight.subtitle}\n$timestamp',
        style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
      ),
      isThreeLine: true,
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
          ],
        ),
        Expanded(child: child),
      ],
    );
  }
}

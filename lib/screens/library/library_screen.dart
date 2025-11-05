import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/screens/log/log_screen.dart';
import 'package:gym_tracker/shared/progress_calculator.dart';
import 'package:gym_tracker/shared/progress_types.dart';
import 'package:gym_tracker/widgets/progress_filters.dart';
import 'package:gym_tracker/widgets/progress_line_chart.dart';
import 'package:gym_tracker/widgets/progress_points_recap.dart';
import 'package:gym_tracker/widgets/create_exercise_dialog.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  String _query = '';
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Exercises'),
            Tab(text: 'Workouts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ExercisesTab(query: _query, onQuery: (s) => setState(() => _query = s)),
          const _WorkoutsTab(),
        ],
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton(
              onPressed: () => _showCreateExerciseDialog(context),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              onPressed: () => _showCreateTemplateDialog(context),
              child: const Icon(Icons.playlist_add),
            ),
    );
  }

  Future<void> _showCreateExerciseDialog(BuildContext context) async {
    final created = await showCreateExerciseDialog(context);
    if (created != null) {
      setState(() {});
    }
  }

  Future<void> _showCreateTemplateDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final exercises = await LocalStore.instance.listExercisesRaw();
    final selected = <int>{};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New Workout Template'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Template name')),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: exercises.map((e) {
                      final id = (e['id'] as num).toInt();
                      final name = (e['name'] ?? '').toString();
                      final checked = selected.contains(id);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(name),
                        onChanged: (v) => setD(() {
                          if (v == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty || selected.isEmpty) return;
                await LocalStore.instance
                    .createWorkoutTemplate(name: name, exerciseIds: selected.toList());
                if (context.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------- Exercises ------------------------------- */

class _ExercisesTab extends StatelessWidget {
  const _ExercisesTab({required this.query, required this.onQuery});
  final String query;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration:
                const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search exercises'),
            onChanged: (v) => onQuery(v.trim()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: LocalStore.instance.listExercisesRaw(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading exercises:\n${snapshot.error}'));
              }
              final exercises = snapshot.data ?? [];
              final q = query.toLowerCase();
              final filtered = q.isEmpty
                  ? exercises
                  : exercises.where((e) {
                      final name = (e['name'] ?? '').toString().toLowerCase();
                      final cat = (e['category'] ?? 'Unknown').toString().toLowerCase();
                      return name.contains(q) || cat.contains(q);
                    }).toList();

              if (filtered.isEmpty) return const Center(child: Text('No exercises found'));

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = filtered[index];
                  final id = (e['id'] as num?)?.toInt();
                  final name = (e['name'] ?? 'Exercise').toString();
                  final category = (e['category'] ?? 'Unknown').toString();

                  return ListTile(
                    leading: const Icon(Icons.fitness_center_outlined),
                    title: Text(name),
                    subtitle: Text('Primary: $category'),
                    onTap: id == null
                        ? null
                        : () => context.pushNamed(
                              'exerciseDetail',
                              pathParameters: {'id': id.toString()},
                            ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/* -------------------------------- Workouts -------------------------------- */

class _WorkoutsTab extends StatelessWidget {
  const _WorkoutsTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalStore.instance.listWorkoutTemplatesRaw(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error loading workouts:\n${snap.error}'));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No workout templates yet'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final w = items[i];
            final id = (w['id'] as num).toInt();
            final name = (w['name'] ?? '').toString();
            final List<dynamic> ids = (w['exercise_ids'] ?? []) as List<dynamic>;
            return ListTile(
              leading: const Icon(Icons.playlist_play),
              title: Text(name),
              subtitle: Text('Exercises: ${ids.length}'),
              onTap: () {
                // Start Log with this template via go_router extra
                context.pushNamed('log', extra: {'templateId': id});
              },
              trailing: IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: 'Preview',
                onPressed: () {
                  // Optional quick preview using a dialog
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: Text(name),
                      content:
                          Text('Exercises: ${ids.length}\n\nTap row to start the workout.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Close'),
                        )
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/* ---------------------- Exercise Detail (unchanged route) ---------------------- */

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  ProgressAggMode _mode = ProgressAggMode.avgPerSession;
  ProgressRange _range = ProgressRange.w8;
  int? _preferredId;
  final ProgressCalculator _calculator = const ProgressCalculator();
  late Future<_ExerciseVM> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ExerciseVM> _load() async {
    final ex = await LocalStore.instance.getExerciseRaw(widget.id);
    final sets = await LocalStore.instance.listSetsForExerciseRaw(widget.id);
    _preferredId = await LocalStore.instance.getPreferredExerciseId();
    final name = (ex?['name'] ?? 'Exercise').toString();
    final category = (ex?['category'] ?? 'Unknown').toString();
    final points = _calculator.buildSeries(
      sets,
      mode: _mode,
      range: _range,
    );
    return _ExerciseVM(id: widget.id, name: name, category: category, series: points);
  }

  void _reload({ProgressAggMode? mode, ProgressRange? range}) {
    if (mode != null) _mode = mode;
    if (range != null) _range = range;
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ExerciseVM>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text('Error loading exercise:\n${snap.error}')));
        }
        final vm = snap.data!;
        final isFav = _preferredId == vm.id;

        return Scaffold(
          appBar: AppBar(title: Text(vm.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              ListTile(
                title: Text(vm.name, style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text('Category: ${vm.category}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Favourite'),
                    Checkbox(
                      value: isFav,
                      onChanged: (checked) async {
                        await LocalStore.instance
                            .setPreferredExerciseId(checked == true ? vm.id : null);
                        _preferredId = await LocalStore.instance.getPreferredExerciseId();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ProgressFilters(
                mode: _mode,
                range: _range,
                onModeChanged: (m) => _reload(mode: m),
                onRangeChanged: (r) => _reload(range: r),
              ),
              const SizedBox(height: 12),
              Card(
                child: SizedBox(
                  height: 260,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weight Trend',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          _mode == ProgressAggMode.avgPerSession
                              ? 'Average weight per session'
                              : 'Set order: ${_mode.label}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ProgressLineChart(points: vm.series),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ProgressPointsRecap(points: vm.series),
            ],
          ),
        );
      },
    );
  }
}

/* --------------------------------- Models -------------------------------- */

/// View model for the exercise detail analytics screen.
class _ExerciseVM {
  final int id;
  final String name;
  final String category;
  final List<ProgressPoint> series;
  _ExerciseVM({
    required this.id,
    required this.name,
    required this.category,
    required this.series,
  });
}

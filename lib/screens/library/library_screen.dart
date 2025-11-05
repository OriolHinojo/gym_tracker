import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/screens/log/log_screen.dart';

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
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'other');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await LocalStore.instance.createExercise(name: name, category: catCtrl.text.trim());
              if (context.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
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
                      final cat = (e['category'] ?? '').toString().toLowerCase();
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
                  final category = (e['category'] ?? '—').toString();

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
                    builder: (_) => AlertDialog(
                      title: Text(name),
                      content: Text('Exercises: ${ids.length}\n\nTap row to start the workout.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
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
  _AggMode _mode = _AggMode.avgPerSession;
  _Range _range = _Range.w8;
  int? _preferredId;
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
    final category = (ex?['category'] ?? '—').toString();
    final points = _buildSeries(sets, _mode, _range);
    return _ExerciseVM(id: widget.id, name: name, category: category, series: points);
  }

  List<_DataPoint> _buildSeries(
    List<Map<String, dynamic>> rawSets,
    _AggMode mode,
    _Range range,
  ) {
    if (rawSets.isEmpty) return const [];
    final parsed = rawSets
        .map((s) {
          final dt = DateTime.parse((s['created_at'] ?? s['started_at']).toString()).toUtc();
          return _SetRow(
            workoutId: (s['workout_id'] as num?)?.toInt() ?? -1,
            createdAt: dt,
            weight: (s['weight'] as num?)?.toDouble() ?? 0,
            reps: (s['reps'] as num?)?.toInt() ?? 0,
            ordinal: (s['ordinal'] as num?)?.toInt() ?? 0,
          );
        })
        .where((s) => s.weight > 0 && s.reps > 0)
        .toList();

    final now = DateTime.now().toUtc();
    DateTime? start;
    switch (range) {
      case _Range.w4:
        start = now.subtract(const Duration(days: 28));
        break;
      case _Range.w8:
        start = now.subtract(const Duration(days: 56));
        break;
      case _Range.w12:
        start = now.subtract(const Duration(days: 84));
        break;
      case _Range.all:
        start = null;
        break;
    }
    final ranged =
        start == null ? parsed : parsed.where((s) => !s.createdAt.isBefore(start!)).toList();

    final byWorkout = <int, List<_SetRow>>{};
    for (final s in ranged) {
      byWorkout.putIfAbsent(s.workoutId, () => []).add(s);
    }

    List<_DataPoint> points;
    if (_mode == _AggMode.avgPerSession) {
      points = byWorkout.entries.map((e) {
        final list = e.value;
        final date =
            list.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
        final avgW = list.fold<double>(0, (p, s) => p + s.weight) / list.length;
        list.sort((a, b) => b.weight.compareTo(a.weight));
        final repsOfHeaviest = list.first.reps;
        return _DataPoint(date: date, yWeight: avgW, reps: repsOfHeaviest);
      }).toList();
    } else {
      final target = switch (_mode) {
        _AggMode.set1 => 1,
        _AggMode.set2 => 2,
        _AggMode.set3 => 3,
        _ => 1
      };
      final picks = byWorkout.values.map((list) {
        list.sort((a, b) => a.ordinal.compareTo(b.ordinal));
        return list.firstWhere((s) => s.ordinal == target, orElse: () => list.first);
      }).toList();
      points = picks
          .map((s) => _DataPoint(date: s.createdAt, yWeight: s.weight, reps: s.reps))
          .toList();
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  void _reload({_AggMode? mode, _Range? range}) {
    if (mode != null) _mode = mode;
    if (range != null) _range = range;
    setState(() => _future = _load());
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 6,
                    children: _AggMode.values.map((m) {
                      final selected = m == _mode;
                      return ChoiceChip(
                        label: Text(m.short),
                        selected: selected,
                        onSelected: (_) => _reload(mode: m),
                      );
                    }).toList(),
                  ),
                  Wrap(
                    spacing: 6,
                    children: _Range.values.map((r) {
                      final selected = r == _range;
                      return ChoiceChip(
                        label: Text(r.label),
                        selected: selected,
                        onSelected: (_) => _reload(range: r),
                      );
                    }).toList(),
                  ),
                ],
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
                          _mode == _AggMode.avgPerSession
                              ? 'Average weight per session'
                              : 'Set order: ${_mode.label}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        _MiniLineChart(points: vm.series),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ------------------------------- Mini Chart ------------------------------- */

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({required this.points});
  final List<_DataPoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(points),
      child: Container(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.points);
  final List<_DataPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paintAxis = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = 1;

    final paintLine = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.fill;

    final tpStyle = const TextStyle(color: Color(0xFF333333), fontSize: 11);

    const leftPad = 36.0;
    const bottomPad = 22.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;

    canvas.drawLine(Offset(leftPad, 0), Offset(leftPad, chartH), paintAxis);
    canvas.drawLine(Offset(leftPad, chartH), Offset(size.width, chartH), paintAxis);

    if (points.isEmpty) return;

    double minY =
        points.map((p) => p.yWeight).reduce((a, b) => a < b ? a : b);
    double maxY =
        points.map((p) => p.yWeight).reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final yRange = (maxY - minY).clamp(1e-6, double.infinity);

    final minX = points.first.date.millisecondsSinceEpoch.toDouble();
    final maxX = points.last.date.millisecondsSinceEpoch.toDouble();
    final xRange = (maxX - minX).clamp(1, double.infinity);

    double xFor(DateTime d) =>
        leftPad + ((d.millisecondsSinceEpoch - minX) / xRange) * chartW;
    double yFor(double weight) =>
        chartH - ((weight - minY) / yRange) * chartH;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = xFor(p.date);
      final y = yFor(p.yWeight);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paintLine);

    for (final p in points) {
      final x = xFor(p.date);
      final y = yFor(p.yWeight);
      canvas.drawCircle(Offset(x, y), 3.5, paintDot);

      final weightText = TextPainter(
        text: TextSpan(
          text: p.yWeight.toStringAsFixed(0),
          style: tpStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      weightText.paint(canvas, Offset(x - weightText.width / 2, y - 18));

      final repsText = TextPainter(
        text: TextSpan(
          text: '${p.reps}r',
          style: tpStyle.copyWith(fontSize: 10, color: const Color(0xFF666666)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      repsText.paint(canvas, Offset(x - repsText.width / 2, y + 4));
    }

    final ticks = [minY, (minY + maxY) / 2, maxY];
    for (final t in ticks) {
      final y = yFor(t);
      final label = TextPainter(
        text: TextSpan(text: t.toStringAsFixed(0), style: tpStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(leftPad - label.width - 6, y - label.height / 2));
      final guide = Paint()
        ..color = const Color(0xFFEFEFEF)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(leftPad + 1, y), Offset(size.width, y), guide);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

/* --------------------------------- Models -------------------------------- */

enum _AggMode { avgPerSession, set1, set2, set3 }

extension on _AggMode {
  String get label => switch (this) {
        _AggMode.avgPerSession => 'Avg per session',
        _AggMode.set1 => '1st set',
        _AggMode.set2 => '2nd set',
        _AggMode.set3 => '3rd set',
      };
  String get short => switch (this) {
        _AggMode.avgPerSession => 'Avg',
        _AggMode.set1 => 'Set 1',
        _AggMode.set2 => 'Set 2',
        _AggMode.set3 => 'Set 3'
      };
}

enum _Range { w4, w8, w12, all }

extension on _Range {
  String get label => switch (this) {
        _Range.w4 => '4w',
        _Range.w8 => '8w',
        _Range.w12 => '12w',
        _Range.all => 'All'
      };
}

class _SetRow {
  final int workoutId;
  final DateTime createdAt;
  final double weight;
  final int reps;
  final int ordinal;
  _SetRow({
    required this.workoutId,
    required this.createdAt,
    required this.weight,
    required this.reps,
    required this.ordinal,
  });
}

class _DataPoint {
  final DateTime date;
  final double yWeight;
  final int reps;
  _DataPoint({required this.date, required this.yWeight, required this.reps});
}

class _ExerciseVM {
  final int id;
  final String name;
  final String category;
  final List<_DataPoint> series;
  _ExerciseVM({
    required this.id,
    required this.name,
    required this.category,
    required this.series,
  });
}

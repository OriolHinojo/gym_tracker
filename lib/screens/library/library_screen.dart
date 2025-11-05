import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search exercises',
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
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
                  return Center(
                    child: Text('Error loading exercises:\n${snapshot.error}'),
                  );
                }

                final exercises = snapshot.data ?? [];
                final q = _query.toLowerCase();
                final filtered = q.isEmpty
                    ? exercises
                    : exercises.where((e) {
                        final name = (e['name'] ?? '').toString().toLowerCase();
                        final cat = (e['category'] ?? '').toString().toLowerCase();
                        return name.contains(q) || cat.contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No exercises found'));
                }

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
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExerciseDetailScreen(id: id),
                                ),
                              ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add "create exercise" or import logic
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/* ------------------------ Exercise Detail + Trends ------------------------ */

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  _AggMode _mode = _AggMode.avgPerSession;
  _Range _range = _Range.w8;
  int? _preferredId; // for checkbox state

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

    return _ExerciseVM(
      id: widget.id,
      name: name,
      category: category,
      series: points,
    );
  }

  List<_DataPoint> _buildSeries(
    List<Map<String, dynamic>> rawSets,
    _AggMode mode,
    _Range range,
  ) {
    if (rawSets.isEmpty) return const [];

    final parsed = rawSets.map((s) {
      final dt = DateTime.parse((s['created_at'] ?? s['started_at']).toString()).toUtc();
      return _SetRow(
        workoutId: (s['workout_id'] as num?)?.toInt() ?? -1,
        createdAt: dt,
        weight: (s['weight'] as num?)?.toDouble() ?? 0,
        reps: (s['reps'] as num?)?.toInt() ?? 0,
        ordinal: (s['ordinal'] as num?)?.toInt() ?? 0,
      );
    }).where((s) => s.weight > 0 && s.reps > 0).toList();

    if (parsed.isEmpty) return const [];

    // Time range filter
    final now = DateTime.now().toUtc();
    DateTime? start;
    switch (range) {
      case _Range.w4: start = now.subtract(const Duration(days: 28)); break;
      case _Range.w8: start = now.subtract(const Duration(days: 56)); break;
      case _Range.w12: start = now.subtract(const Duration(days: 84)); break;
      case _Range.all: start = null; break;
    }
    final ranged = start == null ? parsed : parsed.where((s) => !s.createdAt.isBefore(start!)).toList();
    if (ranged.isEmpty) return const [];

    // Group by workout
    final byWorkout = <int, List<_SetRow>>{};
    for (final s in ranged) {
      byWorkout.putIfAbsent(s.workoutId, () => []).add(s);
    }

    List<_DataPoint> points;
    if (mode == _AggMode.avgPerSession) {
      // Average weight per workout (weight is primary)
      points = byWorkout.entries.map((e) {
        final list = e.value;
        final date = list.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
        final avgW = list.fold<double>(0, (p, s) => p + s.weight) / list.length;
        list.sort((a, b) => b.weight.compareTo(a.weight));
        final repsOfHeaviest = list.first.reps;
        return _DataPoint(date: date, yWeight: avgW, reps: repsOfHeaviest);
      }).toList();
    } else {
      // Specific set order
      final target = switch (mode) { _AggMode.set1 => 1, _AggMode.set2 => 2, _AggMode.set3 => 3, _ => 1 };
      final ordinalSets = byWorkout.values.map((list) {
        list.sort((a, b) => a.ordinal.compareTo(b.ordinal));
        final m = list.firstWhere(
          (s) => s.ordinal == target,
          orElse: () => list.first,
        );
        return m;
      }).where((s) => s.weight > 0 && s.reps > 0).toList();

      points = ordinalSets.map((s) => _DataPoint(date: s.createdAt, yWeight: s.weight, reps: s.reps)).toList();
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  void _reload({_AggMode? mode, _Range? range}) {
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
                        await LocalStore.instance.setPreferredExerciseId(checked == true ? vm.id : null);
                        _preferredId = await LocalStore.instance.getPreferredExerciseId();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Controls (same as Progress screen)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
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

              // Trend chart (weight primary, reps secondary labels)
              Card(
                child: SizedBox(
                  height: 260,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weight Trend', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          _mode == _AggMode.avgPerSession
                              ? 'Average weight per session'
                              : 'Set order: ${_mode.label}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _MiniLineChart(points: vm.series)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Table recap
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      title: Text('Data points'),
                      subtitle: Text('Weight is primary; reps shown as secondary'),
                    ),
                    const Divider(height: 1),
                    if (vm.series.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No data in the selected range'),
                      )
                    else
                      ...vm.series.map((p) => ListTile(
                            dense: true,
                            title: Text('${_fmtDate(p.date)} — ${p.yWeight.toStringAsFixed(1)}'),
                            trailing: Text('${p.reps} reps'),
                          )),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Card(
                child: ListTile(
                  title: Text('Auto-progression settings'),
                  subtitle: Text('Automatically nudge targets based on performance (coming soon)'),
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
      ..color = const Color(0xFF1565C0) // weight line (primary)
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

    // Axes
    canvas.drawLine(Offset(leftPad, 0), Offset(leftPad, chartH), paintAxis);
    canvas.drawLine(Offset(leftPad, chartH), Offset(size.width, chartH), paintAxis);

    if (points.isEmpty) return;

    // Y scale (weight)
    double minY = points.map((p) => p.yWeight).reduce((a, b) => a < b ? a : b);
    double maxY = points.map((p) => p.yWeight).reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final yRange = (maxY - minY).clamp(1e-6, double.infinity);

    // X scale (time)
    final minX = points.first.date.millisecondsSinceEpoch.toDouble();
    final maxX = points.last.date.millisecondsSinceEpoch.toDouble();
    final xRange = (maxX - minX).clamp(1, double.infinity);

    double xFor(DateTime d) => leftPad + ((d.millisecondsSinceEpoch - minX) / xRange) * chartW;
    double yFor(double weight) => chartH - ((weight - minY) / yRange) * chartH;

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

    // Dots & labels
    for (final p in points) {
      final x = xFor(p.date);
      final y = yFor(p.yWeight);
      canvas.drawCircle(Offset(x, y), 3.5, paintDot);

      final weightText = TextPainter(
        text: TextSpan(text: p.yWeight.toStringAsFixed(0), style: tpStyle.copyWith(fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      weightText.paint(canvas, Offset(x - weightText.width / 2, y - 18));

      final repsText = TextPainter(
        text: TextSpan(text: '${p.reps}r', style: tpStyle.copyWith(fontSize: 10, color: const Color(0xFF666666))),
        textDirection: TextDirection.ltr,
      )..layout();
      repsText.paint(canvas, Offset(x - repsText.width / 2, y + 4));
    }

    // Y ticks
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
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.points != points;
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
        _AggMode.set3 => 'Set 3',
      };
}

enum _Range { w4, w8, w12, all }

extension on _Range {
  String get label => switch (this) {
        _Range.w4 => '4w',
        _Range.w8 => '8w',
        _Range.w12 => '12w',
        _Range.all => 'All',
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
  final double yWeight; // primary
  final int reps; // secondary label
  _DataPoint({
    required this.date,
    required this.yWeight,
    required this.reps,
  });
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

/* --------------------------------- Utils --------------------------------- */

String _fmtDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

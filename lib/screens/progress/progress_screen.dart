import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';

// lib/screens/progress/progress_screen.dart
class ProgressScreen extends StatefulWidget {
  // ProgressScreen widget
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int? _selectedExerciseId;
  String _selectedExerciseName = '';
  _AggMode _mode = _AggMode.avgPerSession;
  _Range _range = _Range.w8;

  late Future<_ProgressVM> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProgressVM> _load() async {
    // Load exercises and pick default
    final exercises = await LocalStore.instance.listExercisesRaw();
    exercises.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    int? exId = _selectedExerciseId;
    String exName = _selectedExerciseName;
    if (exId == null && exercises.isNotEmpty) {
      exId = (exercises.first['id'] as num?)?.toInt();
      exName = (exercises.first['name'] ?? '').toString();
    }

    // Load sets for selected exercise
    final sets = exId == null
        ? <Map<String, dynamic>>[]
        : await LocalStore.instance.listSetsForExerciseRaw(exId);

    final vm = _ProgressVM(
      exercises: exercises.map((e) => _ExerciseRow(
        id: (e['id'] as num).toInt(),
        name: (e['name'] ?? '').toString(),
        category: (e['category'] ?? '').toString(),
      )).toList(),
      selectedId: exId,
      selectedName: exName,
      mode: _mode,
      range: _range,
      series: _buildSeries(sets, _mode, _range),
    );

    // save selection for UI state
    _selectedExerciseId = exId;
    _selectedExerciseName = exName;

    return vm;
  }

  List<_DataPoint> _buildSeries(
    List<Map<String, dynamic>> rawSets,
    _AggMode mode,
    _Range range,
  ) {
    if (rawSets.isEmpty) return const [];

    // Parse sets -> typed
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
    final ranged = start == null ? parsed : parsed.where((s) => !s.createdAt.isBefore(start!)).toList();

    if (ranged.isEmpty) return const [];

    // Group by workout for per-session aggregations
    final byWorkout = <int, List<_SetRow>>{};
    for (final s in ranged) {
      byWorkout.putIfAbsent(s.workoutId, () => []).add(s);
    }

    List<_DataPoint> points;
    if (mode == _AggMode.avgPerSession) {
      // Average weight per workout (weight is primary value)
      points = byWorkout.entries.map((e) {
        final sets = e.value;
        final date = sets.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
        final avgWeight = sets.map((s) => s.weight).fold<double>(0, (p, w) => p + w) / sets.length;
        // For display, show reps of the heaviest set that day (secondary)
        sets.sort((a, b) => b.weight.compareTo(a.weight));
        final repsOfHeaviest = sets.first.reps;
        return _DataPoint(date: date, yWeight: avgWeight, reps: repsOfHeaviest, label: avgWeight.toStringAsFixed(1));
      }).toList();
    } else {
      // Fine-grained by set order (1st, 2nd, 3rd)
      final targetOrdinal = switch (mode) {
        _AggMode.set1 => 1,
        _AggMode.set2 => 2,
        _AggMode.set3 => 3,
        _ => 1,
      };
      final ordinalSets = byWorkout.values.map((sets) {
        sets.sort((a, b) => a.ordinal.compareTo(b.ordinal));
        final match = sets.firstWhere(
          (s) => s.ordinal == targetOrdinal,
          orElse: () => sets.isNotEmpty ? sets.first : _SetRow(workoutId: -1, createdAt: DateTime.now().toUtc(), weight: 0, reps: 0, ordinal: 0),
        );
        return match;
      }).where((s) => s.weight > 0 && s.reps > 0).toList();

      points = ordinalSets.map((s) => _DataPoint(
        date: s.createdAt,
        yWeight: s.weight,
        reps: s.reps,
        label: s.weight.toStringAsFixed(1),
      )).toList();
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  void _reload({int? exerciseId, String? exerciseName, _AggMode? mode, _Range? range}) {
    if (exerciseId != null) _selectedExerciseId = exerciseId;
    if (exerciseName != null) _selectedExerciseName = exerciseName;
    if (mode != null) _mode = mode;
    if (range != null) _range = range;
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProgressVM>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;
        final error = snap.hasError ? snap.error : null;
        final vm = snap.data;

        return Scaffold(
          appBar: AppBar(title: const Text('Progress')),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text('Failed to load progress:\n$error'))
                  : vm == null
                      ? const Center(child: Text('No data'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            // Controls
                            _ControlsBar(
                              vm: vm,
                              onExerciseChanged: (id, name) => _reload(exerciseId: id, exerciseName: name),
                              onModeChanged: (m) => _reload(mode: m),
                              onRangeChanged: (r) => _reload(range: r),
                            ),
                            const SizedBox(height: 16),

                            // Main chart: Weight first-class (y-axis), reps secondary in labels
                            _ChartCard(
                              title: 'Weight Trend',
                              subtitle: vm.mode == _AggMode.avgPerSession
                                  ? 'Average weight per session'
                                  : 'Set order: ${vm.mode.label}',
                              points: vm.series,
                            ),

                            const SizedBox(height: 16),
                            // Tabular recap to show exact weights & reps
                            _PointsRecap(points: vm.series),
                          ],
                        ),
        );
      },
    );
  }
}

/* ============================= UI Pieces ============================== */

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.vm,
    required this.onExerciseChanged,
    required this.onModeChanged,
    required this.onRangeChanged,
  });

  final _ProgressVM vm;
  final void Function(int id, String name) onExerciseChanged;
  final void Function(_AggMode mode) onModeChanged;
  final void Function(_Range range) onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        // Exercise selector
        DropdownButton<int>(
          value: vm.selectedId,
          items: vm.exercises
              .map((e) => DropdownMenuItem<int>(
                    value: e.id,
                    child: Text(e.name),
                  ))
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final name = vm.exercises.firstWhere((e) => e.id == id).name;
            onExerciseChanged(id, name);
          },
        ),

        // Aggregation mode (weight prioritized, reps secondary)
        Wrap(
          spacing: 6,
          children: _AggMode.values.map((m) {
            final selected = m == vm.mode;
            return ChoiceChip(
              label: Text(m.short),
              selected: selected,
              onSelected: (_) => onModeChanged(m),
            );
          }).toList(),
        ),

        // Time range
        Wrap(
          spacing: 6,
          children: _Range.values.map((r) {
            final selected = r == vm.range;
            return ChoiceChip(
              label: Text(r.label),
              selected: selected,
              onSelected: (_) => onRangeChanged(r),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.points,
  });
  final String title;
  final String subtitle;
  final List<_DataPoint> points;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 260,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Expanded(
                child: _MiniLineChart(points: points),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsRecap extends StatelessWidget {
  const _PointsRecap({required this.points});
  final List<_DataPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Card(child: ListTile(title: Text('No data in the selected range')));
    }
    return Card(
      child: Column(
        children: [
          const ListTile(
            title: Text('Data points'),
            subtitle: Text('Weight is primary; reps shown as secondary'),
          ),
          const Divider(height: 1),
          ...points.map((p) => ListTile(
                dense: true,
                title: Text('${_fmtDate(p.date)} — ${p.yWeight.toStringAsFixed(1)}'),
                trailing: Text('${p.reps} reps'),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/* ============================= Mini Line Chart ============================== */

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

    // Text style for labels
    final tpStyle = const TextStyle(color: Color(0xFF333333), fontSize: 11);

    // Padding for axes & labels
    const leftPad = 36.0;
    const bottomPad = 22.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;

    // Axes
    canvas.drawLine(const Offset(leftPad, 0), Offset(leftPad, chartH), paintAxis);
    canvas.drawLine(Offset(leftPad, chartH), Offset(size.width, chartH), paintAxis);

    if (points.isEmpty) return;

    // Y scale (weight)
    double minY = points.map((p) => p.yWeight).reduce((a, b) => a < b ? a : b);
    double maxY = points.map((p) => p.yWeight).reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      // widen a bit for flat lines
      minY -= 1;
      maxY += 1;
    }
    final yRange = (maxY - minY).clamp(1e-6, double.infinity);

    // X scale (time)
    final minX = points.first.date.millisecondsSinceEpoch.toDouble();
    final maxX = points.last.date.millisecondsSinceEpoch.toDouble();
    final xRange = (maxX - minX).clamp(1, double.infinity);

    // Helper mappers
    double xFor(DateTime d) => leftPad + ((d.millisecondsSinceEpoch - minX) / xRange) * chartW;
    double yFor(double weight) => chartH - ((weight - minY) / yRange) * chartH;

    // Path
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

    // Dots & labels (weight primary, reps secondary)
    for (final p in points) {
      final x = xFor(p.date);
      final y = yFor(p.yWeight);
      canvas.drawCircle(Offset(x, y), 3.5, paintDot);

      // Weight label above, reps smaller below
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

    // Y tick labels (min/mid/max)
    final ticks = [minY, (minY + maxY) / 2, maxY];
    for (final t in ticks) {
      final y = yFor(t);
      final label = TextPainter(
        text: TextSpan(text: t.toStringAsFixed(0), style: tpStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(leftPad - label.width - 6, y - label.height / 2));
      // light guide
      final guide = Paint()
        ..color = const Color(0xFFEFEFEF)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(leftPad + 1, y), Offset(size.width, y), guide);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

/* ============================= Models ============================== */

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

class _ExerciseRow {
  final int id;
  final String name;
  final String category;
  _ExerciseRow({required this.id, required this.name, required this.category});
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
  final double yWeight; // primary metric
  final int reps; // secondary metric for labels
  final String label; // optional string for the point
  _DataPoint({
    required this.date,
    required this.yWeight,
    required this.reps,
    required this.label,
  });
}

class _ProgressVM {
  final List<_ExerciseRow> exercises;
  final int? selectedId;
  final String selectedName;
  final _AggMode mode;
  final _Range range;
  final List<_DataPoint> series;

  _ProgressVM({
    required this.exercises,
    required this.selectedId,
    required this.selectedName,
    required this.mode,
    required this.range,
    required this.series,
  });
}

/* ============================= Utils ============================== */

String _fmtDate(DateTime d) {
  // Basic yyyy-mm-dd
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

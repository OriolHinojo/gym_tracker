import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/shared/progress_calculator.dart';
import 'package:gym_tracker/shared/progress_types.dart';
import 'package:gym_tracker/widgets/progress_filters.dart';
import 'package:gym_tracker/widgets/progress_line_chart.dart';
import 'package:gym_tracker/widgets/progress_points_recap.dart';

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
  ProgressAggMode _mode = ProgressAggMode.avgPerSession;
  ProgressRange _range = ProgressRange.w8;

  final ProgressCalculator _calculator = const ProgressCalculator();
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
      series: _calculator.buildSeries(
        sets,
        mode: _mode,
        range: _range,
      ),
    );

    // save selection for UI state
    _selectedExerciseId = exId;
    _selectedExerciseName = exName;

    return vm;
  }

  void _reload({int? exerciseId, String? exerciseName, ProgressAggMode? mode, ProgressRange? range}) {
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
                            ProgressFilters(
                              mode: vm.mode,
                              range: vm.range,
                              onModeChanged: (m) => _reload(mode: m),
                              onRangeChanged: (r) => _reload(range: r),
                              leading: [
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
                                    _reload(exerciseId: id, exerciseName: name);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Main chart: Weight first-class (y-axis), reps secondary in labels
                            _ChartCard(
                              title: 'Weight Trend',
                              subtitle: vm.mode == ProgressAggMode.avgPerSession
                                  ? 'Average weight per session'
                                  : 'Set order: ${vm.mode.label}',
                              points: vm.series,
                            ),

                            const SizedBox(height: 16),
                            // Tabular recap to show exact weights & reps
                            ProgressPointsRecap(points: vm.series),
                          ],
                        ),
        );
      },
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
  final List<ProgressPoint> points;

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
                child: ProgressLineChart(points: points),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================= Models ============================== */

/// Lightweight projection of exercise metadata to populate the dropdown.
class _ExerciseRow {
  final int id;
  final String name;
  final String category;
  _ExerciseRow({required this.id, required this.name, required this.category});
}

/// Aggregated data ready for the Progress screen widgets.
class _ProgressVM {
  final List<_ExerciseRow> exercises;
  final int? selectedId;
  final String selectedName;
  final ProgressAggMode mode;
  final ProgressRange range;
  final List<ProgressPoint> series;

  _ProgressVM({
    required this.exercises,
    required this.selectedId,
    required this.selectedName,
    required this.mode,
    required this.range,
    required this.series,
  });
}

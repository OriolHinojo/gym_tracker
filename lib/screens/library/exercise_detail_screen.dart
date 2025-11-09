import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/shared/formatting.dart';
import 'package:gym_tracker/shared/progress_calculator.dart';
import 'package:gym_tracker/shared/progress_types.dart';
import 'package:gym_tracker/shared/weight_units.dart';
import 'package:gym_tracker/widgets/progress_filters.dart';
import 'package:gym_tracker/widgets/progress_line_chart.dart';
import 'package:gym_tracker/widgets/progress_points_recap.dart';

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  ProgressAggMode _mode = ProgressAggMode.avgPerSession;
  ProgressRange _range = ProgressRange.w8;
  ProgressMetric _metric = ProgressMetric.weight;
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
      metric: _metric,
    );
    final bestOneRm = _computeBestOneRm(sets);
    return _ExerciseVM(
      id: widget.id,
      name: name,
      category: category,
      series: points,
      metric: _metric,
      bestOneRmKilos: bestOneRm,
    );
  }

  void _reload({ProgressAggMode? mode, ProgressRange? range, ProgressMetric? metric}) {
    if (mode != null) _mode = mode;
    if (range != null) _range = range;
    if (metric != null) _metric = metric;
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
                metric: _metric,
                metricOptions: ProgressMetric.values,
                onModeChanged: (m) => _reload(mode: m),
                onRangeChanged: (r) => _reload(range: r),
                onMetricChanged: (m) => _reload(metric: m),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<WeightUnit>(
                valueListenable: LocalStore.instance.weightUnitListenable,
                builder: (context, unit, _) => Column(
                  children: [
                    if (vm.bestOneRmKilos != null) ...[
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.show_chart_outlined),
                          title: const Text('Best estimated 1RM'),
                          subtitle: Text(
                            '${formatSetWeight(vm.bestOneRmKilos!, unit)} ${unit.label}',
                          ),
                          trailing: IconButton(
                            tooltip: 'How is this calculated?',
                            icon: const Icon(Icons.info_outline),
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  title: const Text('Estimated 1RM'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'We use the Epley formula to estimate your one-rep max from the heaviest set you have logged for this exercise.',
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Formula',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('1RM ≈ weight × (1 + reps ÷ 30)'),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Disclaimer',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'This is a statistical estimate based on your logged data. Always lift responsibly and adjust loads according to how you feel.',
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Card(
                      child: SizedBox(
                        height: 260,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _metric == ProgressMetric.weight
                                    ? 'Weight Trend'
                                    : 'Estimated 1RM Trend',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _metric == ProgressMetric.weight
                                    ? (_mode == ProgressAggMode.avgPerSession
                                        ? 'Average weight per session'
                                        : 'Set order: ${_mode.label}')
                                    : (_mode == ProgressAggMode.avgPerSession
                                        ? 'Heaviest set estimate (Epley)'
                                        : 'Set order: ${_mode.label} · Epley estimate'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Flexible(
                                fit: FlexFit.tight,
                                child: ProgressLineChart(
                                  points: vm.series,
                                  weightUnit: unit,
                                  metric: vm.metric,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ProgressPointsRecap(points: vm.series, weightUnit: unit, metric: vm.metric),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double? _computeBestOneRm(List<Map<String, dynamic>> sets) {
    double? best;
    for (final row in sets) {
      final weight = (row['weight'] as num?)?.toDouble();
      final reps = (row['reps'] as num?)?.toInt();
      if (weight == null || weight <= 0 || reps == null || reps <= 0) continue;
      final estimate = _estimateOneRm(weight, reps);
      if (best == null || estimate > best) {
        best = estimate;
      }
    }
    return best;
  }

  double _estimateOneRm(double weight, int reps) {
    if (reps <= 1) return weight;
    return weight * (1 + reps / 30);
  }
}

class _ExerciseVM {
  final int id;
  final String name;
  final String category;
  final List<ProgressPoint> series;
  final ProgressMetric metric;
  final double? bestOneRmKilos;
  _ExerciseVM({
    required this.id,
    required this.name,
    required this.category,
    required this.series,
    required this.metric,
    required this.bestOneRmKilos,
  });
}

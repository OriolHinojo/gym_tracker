import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/services/analytics/analytics_models.dart';
import 'package:gym_tracker/services/analytics/analytics_service.dart';
import 'package:gym_tracker/shared/progress_calculator.dart';
import 'package:gym_tracker/shared/progress_types.dart';
import 'package:gym_tracker/shared/set_tags.dart';
import 'package:gym_tracker/widgets/progress_filters.dart';
import 'package:gym_tracker/widgets/progress_line_chart.dart';
import 'package:gym_tracker/widgets/progress_points_recap.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ProgressCalculator _calculator = const ProgressCalculator();
  final AnalyticsService _analytics = AnalyticsService();

  int? _selectedExerciseId;
  String _selectedExerciseName = '';
  int? _selectedTemplateId;
  ProgressAggMode _mode = ProgressAggMode.avgPerSession;
  ProgressRange _range = ProgressRange.w8;
  final Set<SetTag> _tagFilters = <SetTag>{};
  final Set<TimeOfDayBucket> _timeFilters = <TimeOfDayBucket>{};

  late Future<_ProgressVM> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProgressVM> _load() async {
    final exercisesRaw = await LocalStore.instance.listExercisesRaw();
    exercisesRaw.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    final templatesRaw = await LocalStore.instance.listWorkoutTemplatesRaw()
      ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    int? selectedExercise = _selectedExerciseId;
    String selectedExerciseName = _selectedExerciseName;
    if (selectedExercise == null && exercisesRaw.isNotEmpty) {
      selectedExercise = (exercisesRaw.first['id'] as num?)?.toInt();
      selectedExerciseName = (exercisesRaw.first['name'] ?? '').toString();
    }

    final exerciseSets = selectedExercise == null
        ? <Map<String, dynamic>>[]
        : await LocalStore.instance.listSetsForExerciseRaw(selectedExercise);

    final analytics = await _analytics.snapshot(
      filters: AnalyticsFilters(
        templateIds: _selectedTemplateId == null ? null : {_selectedTemplateId!},
        tags: _tagFilters.isEmpty ? null : _tagFilters,
        timeOfDayBuckets: _timeFilters.isEmpty ? null : _timeFilters,
      ),
    );

    final series = _calculator.buildSeries(
      exerciseSets,
      mode: _mode,
      range: _range,
    );

    _selectedExerciseId = selectedExercise;
    _selectedExerciseName = selectedExerciseName;

    return _ProgressVM(
      exercises: exercisesRaw
          .map((row) => _ExerciseRow(
                id: (row['id'] as num).toInt(),
                name: (row['name'] ?? '').toString(),
                category: (row['category'] ?? '').toString(),
              ))
          .toList(),
      templates: templatesRaw
          .map((tpl) => _TemplateRow(
                id: (tpl['id'] as num).toInt(),
                name: (tpl['name'] ?? '').toString(),
              ))
          .toList(),
      selectedExerciseId: selectedExercise,
      selectedExerciseName: selectedExerciseName,
      selectedTemplateId: _selectedTemplateId,
      mode: _mode,
      range: _range,
      series: series,
      analytics: analytics,
    );
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

  void _reloadFilters() {
    setState(() {
      _future = _load();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedTemplateId = null;
      _tagFilters.clear();
      _timeFilters.clear();
      _future = _load();
    });
  }

  bool get _hasActiveFilters =>
      _selectedTemplateId != null || _tagFilters.isNotEmpty || _timeFilters.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProgressVM>(
      future: _future,
      builder: (context, snapshot) {
        final vm = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final error = snapshot.error;

        return Scaffold(
          appBar: AppBar(title: const Text('Progress')),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text('Failed to load progress:\n$error'))
                  : vm == null
                      ? const Center(child: Text('No data yet. Log a session to see insights.'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _FilterBar(
                              vm: vm,
                              selectedTemplateId: _selectedTemplateId,
                              tagFilters: _tagFilters,
                              timeFilters: _timeFilters,
                              hasActiveFilters: _hasActiveFilters,
                              onTemplateChanged: (id) {
                                _selectedTemplateId = id;
                                _reloadFilters();
                              },
                              onOpenFilters: () => _showFilterSheet(vm),
                              onClearFilters: _hasActiveFilters ? _clearFilters : null,
                            ),
                            const SizedBox(height: 16),
                            _SummaryCard(snapshot: vm.analytics),
                            const SizedBox(height: 12),
                            if (vm.analytics.volumeTrend.isNotEmpty) ...[
                              _VolumeTrendCard(points: vm.analytics.volumeTrend),
                              const SizedBox(height: 12),
                            ],
                            if (vm.analytics.volumeByTimeOfDay.isNotEmpty) ...[
                              _TimeOfDayCard(entries: vm.analytics.volumeByTimeOfDay),
                              const SizedBox(height: 12),
                            ],
                            if (vm.analytics.personalRecords.isNotEmpty) ...[
                              _PrCard(records: vm.analytics.personalRecords),
                              const SizedBox(height: 12),
                            ],
                            _SectionHeader(title: 'Exercise Weight Trend'),
                            const SizedBox(height: 8),
                            ProgressFilters(
                              mode: vm.mode,
                              range: vm.range,
                              onModeChanged: (mode) => _reload(mode: mode),
                              onRangeChanged: (range) => _reload(range: range),
                              leading: [
                                DropdownButton<int>(
                                  value: vm.selectedExerciseId,
                                  items: vm.exercises
                                      .map(
                                        (exercise) => DropdownMenuItem<int>(
                                          value: exercise.id,
                                          child: Text(exercise.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    final name = vm.exercises.firstWhere((e) => e.id == value).name;
                                    _reload(exerciseId: value, exerciseName: name);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _ChartCard(
                              title: 'Weight Trend — ${vm.selectedExerciseName}',
                              subtitle: vm.mode == ProgressAggMode.avgPerSession
                                  ? 'Average weight per session'
                                  : 'Set order: ${vm.mode.label}',
                              points: vm.series,
                            ),
                            const SizedBox(height: 16),
                            ProgressPointsRecap(points: vm.series),
                          ],
                        ),
        );
      },
    );
  }

  Future<void> _showFilterSheet(_ProgressVM vm) async {
    final localTags = Set<SetTag>.from(_tagFilters);
    final localTimes = Set<TimeOfDayBucket>.from(_timeFilters);
    int? localTemplate = _selectedTemplateId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) => StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filters', style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Template', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                DropdownButton<int?>(
                  value: localTemplate,
                  hint: const Text('All templates'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All templates')),
                    ...vm.templates.map(
                      (tpl) => DropdownMenuItem<int?>(
                        value: tpl.id,
                        child: Text(tpl.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setModalState(() => localTemplate = value),
                ),
                const SizedBox(height: 16),
                Text('Time of day', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: TimeOfDayBucket.values
                      .map(
                        (bucket) => FilterChip(
                          label: Text(bucket.label),
                          selected: localTimes.contains(bucket),
                          onSelected: (selected) => setModalState(() {
                            if (selected) {
                              localTimes.add(bucket);
                            } else {
                              localTimes.remove(bucket);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text('Set tags', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: kAvailableSetTags
                      .map(
                        (tag) => FilterChip(
                          label: Text(tag.label),
                          selected: localTags.contains(tag),
                          onSelected: (selected) => setModalState(() {
                            if (selected) {
                              localTags.add(tag);
                            } else {
                              localTags.remove(tag);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        localTemplate = null;
                        localTags.clear();
                        localTimes.clear();
                        Navigator.pop(context);
                        _clearFilters();
                      },
                      child: const Text('Clear all'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _selectedTemplateId = localTemplate;
                        _tagFilters
                          ..clear()
                          ..addAll(localTags);
                        _timeFilters
                          ..clear()
                          ..addAll(localTimes);
                        _reloadFilters();
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.vm,
    required this.selectedTemplateId,
    required this.tagFilters,
    required this.timeFilters,
    required this.hasActiveFilters,
    required this.onTemplateChanged,
    required this.onOpenFilters,
    this.onClearFilters,
  });

  final _ProgressVM vm;
  final int? selectedTemplateId;
  final Set<SetTag> tagFilters;
  final Set<TimeOfDayBucket> timeFilters;
  final bool hasActiveFilters;
  final ValueChanged<int?> onTemplateChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final tag in tagFilters) {
      chips.add(Chip(
        avatar: const Icon(Icons.local_offer_outlined, size: 16),
        label: Text(tag.label),
      ));
    }
    for (final bucket in timeFilters) {
      chips.add(Chip(
        avatar: const Icon(Icons.access_time, size: 16),
        label: Text(bucket.label),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: selectedTemplateId,
                decoration: const InputDecoration(
                  labelText: 'Template',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All templates')),
                  ...vm.templates.map(
                    (tpl) => DropdownMenuItem<int?>(
                      value: tpl.id,
                      child: Text(tpl.name),
                    ),
                  ),
                ],
                onChanged: onTemplateChanged,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onOpenFilters,
              child: const Text('More filters'),
            ),
            if (hasActiveFilters && onClearFilters != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onClearFilters,
                child: const Text('Clear'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        chips.isEmpty
            ? Text(
                'No additional filters applied',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              )
            : Wrap(
                spacing: 8,
                runSpacing: -8,
                children: chips,
              ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.primaryContainer.withOpacity(0.18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MetricTile(label: 'Sessions', value: snapshot.sessionCount.toString()),
                _MetricTile(label: 'Total volume', value: _formatWeight(snapshot.totalVolume)),
                _MetricTile(label: 'Avg / session', value: _formatWeight(snapshot.averageVolumePerSession)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _VolumeTrendCard extends StatelessWidget {
  const _VolumeTrendCard({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Volume trend', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: _VolumeMiniChart(points: points),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeMiniChart extends StatelessWidget {
  const _VolumeMiniChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('No volume logged'));
    }
    final maxValue = points.map((p) => p.value).fold<double>(0, max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points.map((point) {
        final proportion = maxValue == 0 ? 0.05 : (point.value / maxValue).clamp(0.05, 1.0);
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 120 * proportion,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.6),
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimeOfDayCard extends StatelessWidget {
  const _TimeOfDayCard({required this.entries});

  final List<TimeOfDayVolume> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVolume = entries.map((e) => e.volume).fold<double>(0, max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Volume by time of day', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...entries.map((entry) {
              final double ratio = maxVolume == 0 ? 0.0 : entry.volume / maxVolume;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.bucket.label),
                        Text(_formatWeight(entry.volume), style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: ratio),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PrCard extends StatelessWidget {
  const _PrCard({required this.records});

  final List<PersonalRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent PRs', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...records.map(
              (record) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(record.exerciseName),
                subtitle: Text(
                  '${_formatWeight(record.weight)} · ${record.reps} reps · 1RM ${record.estimatedOneRm.toStringAsFixed(1)}',
                ),
                trailing: Text(_formatDate(record.achievedAt)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
    final theme = Theme.of(context);
    return Card(
      child: SizedBox(
        height: 260,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall),
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

class _ExerciseRow {
  _ExerciseRow({required this.id, required this.name, required this.category});
  final int id;
  final String name;
  final String category;
}

class _TemplateRow {
  _TemplateRow({required this.id, required this.name});
  final int id;
  final String name;
}

class _ProgressVM {
  _ProgressVM({
    required this.exercises,
    required this.templates,
    required this.selectedExerciseId,
    required this.selectedExerciseName,
    required this.selectedTemplateId,
    required this.mode,
    required this.range,
    required this.series,
    required this.analytics,
  });

  final List<_ExerciseRow> exercises;
  final List<_TemplateRow> templates;
  final int? selectedExerciseId;
  final String selectedExerciseName;
  final int? selectedTemplateId;
  final ProgressAggMode mode;
  final ProgressRange range;
  final List<ProgressPoint> series;
  final AnalyticsSnapshot analytics;
}

String _formatWeight(double kilos) {
  if (kilos >= 1000) return '${(kilos / 1000).toStringAsFixed(1)}k kg';
  if (kilos >= 100) return '${kilos.toStringAsFixed(0)} kg';
  return '${kilos.toStringAsFixed(1)} kg';
}

String _formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

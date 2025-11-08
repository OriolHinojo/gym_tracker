import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/services/analytics/analytics_models.dart';
import 'package:gym_tracker/services/analytics/analytics_service.dart';
import 'package:gym_tracker/shared/formatting.dart';
import 'package:gym_tracker/shared/progress_calculator.dart';
import 'package:gym_tracker/shared/progress_types.dart';
import 'package:gym_tracker/shared/weight_units.dart';
import 'package:gym_tracker/shared/set_tags.dart';
import 'package:gym_tracker/widgets/progress_filters.dart';
import 'package:gym_tracker/widgets/progress_line_chart.dart';
import 'package:gym_tracker/widgets/progress_points_recap.dart';

/// Multi-tab analytics dashboard.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with TickerProviderStateMixin {
  final AnalyticsService _analytics = AnalyticsService();
  final ProgressCalculator _calculator = const ProgressCalculator();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WeightUnit>(
      valueListenable: LocalStore.instance.weightUnitListenable,
      builder: (context, unit, _) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Progress'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Templates'),
                Tab(text: 'Exercises'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _TemplatesTab(analytics: _analytics, weightUnit: unit),
              _ExercisesTab(analytics: _analytics, calculator: _calculator, weightUnit: unit),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               TEMPLATES TAB                                */
/* -------------------------------------------------------------------------- */

class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab({required this.analytics, required this.weightUnit});

  final AnalyticsService analytics;
  final WeightUnit weightUnit;

  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  static const int _allTemplates = -1;

  int? _selectedTemplateId;
  final Set<SetTag> _tagFilters = <SetTag>{};
  final Set<TimeOfDayBucket> _timeFilters = <TimeOfDayBucket>{};

  late Future<_TemplateVM> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TemplateVM> _load() async {
    final templatesRaw = await LocalStore.instance.listWorkoutTemplatesRaw()
      ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    final templates = templatesRaw
        .map(
          (tpl) => _TemplateRow(
            id: (tpl['id'] as num).toInt(),
            name: (tpl['name'] ?? 'Template').toString(),
          ),
        )
        .toList();

    int selected = _selectedTemplateId ?? (templates.isEmpty ? _allTemplates : templates.first.id);
    final int? templateFilter = selected == _allTemplates ? null : selected;

    final analytics = await widget.analytics.snapshot(
      filters: AnalyticsFilters(
        templateIds: templateFilter == null ? null : {templateFilter},
        tags: _tagFilters.isEmpty ? null : _tagFilters,
        timeOfDayBuckets: _timeFilters.isEmpty ? null : _timeFilters,
        includeZeroVolumeSessions: true,
      ),
    );

    final allSets = await LocalStore.instance.listAllSetsRaw();
    final setsByWorkout = <int, List<Map<String, dynamic>>>{};
    for (final raw in allSets) {
      final wid = (raw['workout_id'] as num?)?.toInt();
      if (wid == null) continue;
      setsByWorkout.putIfAbsent(wid, () => <Map<String, dynamic>>[]).add(raw);
    }

    final recentRaw = await LocalStore.instance.listRecentWorkoutsRaw(limit: 40);
    final sessions = <_TemplateSessionRow>[];
    for (final workout in recentRaw) {
      final wid = (workout['id'] as num?)?.toInt();
      if (wid == null) continue;

      final templateId = (workout['template_id'] as num?)?.toInt();
      if (templateFilter != null && templateId != templateFilter) continue;

      final startedAt = DateTime.tryParse((workout['started_at'] ?? '').toString())?.toLocal();
      if (startedAt == null) continue;

      final bucket = TimeOfDayBucketX.classify(startedAt);
      if (_timeFilters.isNotEmpty && !_timeFilters.contains(bucket)) continue;

      final sets = setsByWorkout[wid] ?? const <Map<String, dynamic>>[];
      double volume = 0;
      int setCount = 0;
      bool matchedSet = false;

      for (final set in sets) {
        final tag = setTagFromStorage(set['tag']?.toString());
        if (_tagFilters.isNotEmpty && !_tagFilters.contains(tag)) continue;

        final weight = (set['weight'] as num?)?.toDouble();
        final reps = (set['reps'] as num?)?.toInt();
        if (weight == null || reps == null) continue;

        matchedSet = true;
        volume += weight * reps;
        setCount++;
      }

      if (_tagFilters.isNotEmpty && !matchedSet) continue;

      sessions.add(
        _TemplateSessionRow(
          name: _normalizeName((workout['name'] ?? '').toString()),
          startedAt: startedAt,
          volume: volume,
          setCount: setCount,
        ),
      );
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    _selectedTemplateId = selected;
    return _TemplateVM(
      templates: templates,
      selectedTemplateId: selected,
      analytics: analytics,
      sessions: sessions,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _openFiltersBottomSheet(_TemplateVM vm) async {
    final localTags = Set<SetTag>.from(_tagFilters);
    final localTimes = Set<TimeOfDayBucket>.from(_timeFilters);

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
                const SizedBox(height: 12),
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
                        localTags.clear();
                        localTimes.clear();
                        Navigator.pop(context);
                        setState(() {
                          _tagFilters.clear();
                          _timeFilters.clear();
                          _future = _load();
                        });
                      },
                      child: const Text('Clear all'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _tagFilters
                            ..clear()
                            ..addAll(localTags);
                          _timeFilters
                            ..clear()
                            ..addAll(localTimes);
                          _future = _load();
                        });
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TemplateVM>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load template analytics.\n${snapshot.error}'));
        }
        final vm = snapshot.data;
        if (vm == null) {
          return const Center(child: Text('No templates yet. Create one in Library → Workouts.'));
        }

        final templateOptions = [
          const _DropdownOption(value: _allTemplates, label: 'All templates'),
          ...vm.templates.map(
            (tpl) => _DropdownOption(value: tpl.id, label: tpl.name),
          ),
        ];
        final contextLabel = templateOptions
            .firstWhere(
              (option) => option.value == vm.selectedTemplateId,
              orElse: () => templateOptions.first,
            )
            .label;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: DropdownButtonFormField<int>(
                    value: vm.selectedTemplateId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Template',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: templateOptions
                        .map(
                          (option) => DropdownMenuItem<int>(
                            value: option.value,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => templateOptions
                        .map(
                          (option) => Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              option.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTemplateId = value;
                        _future = _load();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: () => _openFiltersBottomSheet(vm),
                  child: const Text('More filters'),
                ),
                if (_tagFilters.isNotEmpty || _timeFilters.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear filters',
                    icon: const Icon(Icons.filter_alt_off),
                    onPressed: _clearSelections,
                  ),
                ],
              ],
            ),
            if (_tagFilters.isNotEmpty || _timeFilters.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._tagFilters.map(
                    (tag) => Chip(
                      avatar: const Icon(Icons.local_offer_outlined, size: 16),
                      label: Text(tag.label),
                    ),
                  ),
                  ..._timeFilters.map(
                    (bucket) => Chip(
                      avatar: const Icon(Icons.access_time, size: 16),
                      label: Text(bucket.label),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _SummaryCard(
              snapshot: vm.analytics,
              contextLabel: contextLabel,
              lastSessionWeight: vm.sessions.isEmpty ? null : vm.sessions.first.volume,
              weightUnit: widget.weightUnit,
            ),
            const SizedBox(height: 12),
            if (vm.analytics.volumeTrend.isNotEmpty) ...[
              _VolumeTrendCard(points: vm.analytics.volumeTrend),
              const SizedBox(height: 12),
            ],
            if (vm.analytics.volumeByTimeOfDay.isNotEmpty) ...[
              _SectionHeader(title: 'Volume insights'),
              const SizedBox(height: 8),
              _TimeOfDayCard(
                entries: vm.analytics.volumeByTimeOfDay,
                weightUnit: widget.weightUnit,
              ),
              const SizedBox(height: 12),
            ],
            if (vm.analytics.personalRecords.isNotEmpty) ...[
              _PrCard(
                records: vm.analytics.personalRecords,
                weightUnit: widget.weightUnit,
              ),
              const SizedBox(height: 12),
            ],
            _SectionHeader(title: 'Recent sessions'),
            const SizedBox(height: 8),
            if (vm.sessions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No recent sessions match these filters.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...vm.sessions.map(
                (session) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fitness_center_outlined),
                  title: Text(session.name),
                  subtitle: Text(formatDateYmd(session.startedAt)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatWeight(session.volume, widget.weightUnit)),
                      Text('${session.setCount} sets', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _clearSelections() {
    setState(() {
      _tagFilters.clear();
      _timeFilters.clear();
      _future = _load();
    });
  }
}

/* -------------------------------------------------------------------------- */
/*                               EXERCISES TAB                                */
/* -------------------------------------------------------------------------- */

class _ExercisesTab extends StatefulWidget {
  const _ExercisesTab({
    required this.analytics,
    required this.calculator,
    required this.weightUnit,
  });

  final AnalyticsService analytics;
  final ProgressCalculator calculator;
  final WeightUnit weightUnit;

  @override
  State<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<_ExercisesTab> {
  int? _selectedExerciseId;
  String _selectedExerciseName = '';
  ProgressAggMode _mode = ProgressAggMode.avgPerSession;
  ProgressRange _range = ProgressRange.w8;
  ProgressMetric _metric = ProgressMetric.weight;
  final Set<SetTag> _tagFilters = <SetTag>{};
  final Set<TimeOfDayBucket> _timeFilters = <TimeOfDayBucket>{};

  late Future<_ExerciseVM> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ExerciseVM> _load() async {
    final exercisesRaw = await LocalStore.instance.listExercisesRaw()
      ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    int? selected = _selectedExerciseId;
    String name = _selectedExerciseName;
    if (selected == null && exercisesRaw.isNotEmpty) {
      selected = (exercisesRaw.first['id'] as num?)?.toInt();
      name = (exercisesRaw.first['name'] ?? '').toString();
    }

    final sets = selected == null
        ? <Map<String, dynamic>>[]
        : await LocalStore.instance.listSetsForExerciseRaw(selected);

    final analytics = await widget.analytics.snapshot(
      filters: AnalyticsFilters(
        exerciseIds: selected == null ? null : {selected},
        tags: _tagFilters.isEmpty ? null : _tagFilters,
        timeOfDayBuckets: _timeFilters.isEmpty ? null : _timeFilters,
      ),
    );

    final series = widget.calculator.buildSeries(
      sets,
      mode: _mode,
      range: _range,
      metric: _metric,
    );

    final aggregates = <int, _ExerciseSessionAggregate>{};

    for (final set in sets) {
      final dynamic raw = set['created_at'] ?? set['started_at'];
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed == null) continue;
      final local = parsed.toLocal();

      if (_timeFilters.isNotEmpty) {
        final bucket = TimeOfDayBucketX.classify(local);
        if (!_timeFilters.contains(bucket)) continue;
      }

      if (_tagFilters.isNotEmpty) {
        final tag = setTagFromStorage(set['tag']?.toString());
        if (!_tagFilters.contains(tag)) continue;
      }

      final wid = (set['workout_id'] as num?)?.toInt();
      if (wid == null) continue;

      final weight = (set['weight'] as num?)?.toDouble();
      if (weight == null) continue;
      final reps = (set['reps'] as num?)?.toInt() ?? 1;

      final aggregate = aggregates.putIfAbsent(
        wid,
        () => _ExerciseSessionAggregate(timestamp: local),
      );
      aggregate.timestamp = local.isAfter(aggregate.timestamp) ? local : aggregate.timestamp;
      aggregate.totalWeight += weight * reps;
    }

    DateTime? bestTimestamp;
    double? lastSessionWeight;
    aggregates.forEach((_, aggregate) {
      if (bestTimestamp == null || aggregate.timestamp.isAfter(bestTimestamp!)) {
        bestTimestamp = aggregate.timestamp;
        lastSessionWeight = aggregate.totalWeight;
      }
    });

    _selectedExerciseId = selected;
    _selectedExerciseName = name.isEmpty ? 'All exercises' : name;

    return _ExerciseVM(
      exercises: exercisesRaw
          .map(
            (row) => _ExerciseRow(
              id: (row['id'] as num).toInt(),
              name: (row['name'] ?? '').toString(),
              category: (row['category'] ?? '').toString(),
            ),
          )
          .toList(),
      selectedExerciseId: _selectedExerciseId,
      selectedExerciseName: _selectedExerciseName,
      mode: _mode,
      range: _range,
      metric: _metric,
      series: series,
      analytics: analytics,
      lastSessionWeight: lastSessionWeight,
    );
  }

  void _reload({
    int? exerciseId,
    String? exerciseName,
    ProgressAggMode? mode,
    ProgressRange? range,
    ProgressMetric? metric,
  }) {
    if (exerciseId != null) _selectedExerciseId = exerciseId;
    if (exerciseName != null) _selectedExerciseName = exerciseName;
    if (mode != null) _mode = mode;
    if (range != null) _range = range;
    if (metric != null) _metric = metric;
    setState(() {
      _future = _load();
    });
  }

  void _openFiltersBottomSheet() async {
    final localTags = Set<SetTag>.from(_tagFilters);
    final localTimes = Set<TimeOfDayBucket>.from(_timeFilters);

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
                const SizedBox(height: 12),
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
                        localTags.clear();
                        localTimes.clear();
                        Navigator.pop(context);
                        setState(() {
                          _tagFilters.clear();
                          _timeFilters.clear();
                          _future = _load();
                        });
                      },
                      child: const Text('Clear all'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _tagFilters
                            ..clear()
                            ..addAll(localTags);
                          _timeFilters
                            ..clear()
                            ..addAll(localTimes);
                          _future = _load();
                        });
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ExerciseVM>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load exercise analytics.\n${snapshot.error}'));
        }
        final vm = snapshot.data;
        if (vm == null) {
          return const Center(child: Text('No exercises yet. Create one to start logging.'));
        }

        final exerciseOptions = vm.exercises
            .map((exercise) => _DropdownOption(value: exercise.id, label: exercise.name))
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: DropdownButtonFormField<int>(
                    value: vm.selectedExerciseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Exercise',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: exerciseOptions
                        .map(
                          (option) => DropdownMenuItem<int>(
                            value: option.value,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => exerciseOptions
                        .map(
                          (option) => Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              option.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final name =
                          vm.exercises.firstWhere((exercise) => exercise.id == value).name;
                      _reload(exerciseId: value, exerciseName: name);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: _openFiltersBottomSheet,
                  child: const Text('More filters'),
                ),
                if (_tagFilters.isNotEmpty || _timeFilters.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear filters',
                    icon: const Icon(Icons.filter_alt_off),
                    onPressed: () {
                      setState(() {
                        _tagFilters.clear();
                        _timeFilters.clear();
                        _future = _load();
                      });
                    },
                  ),
                ],
              ],
            ),
            if (_tagFilters.isNotEmpty || _timeFilters.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._tagFilters.map(
                    (tag) => Chip(
                      avatar: const Icon(Icons.local_offer_outlined, size: 16),
                      label: Text(tag.label),
                    ),
                  ),
                  ..._timeFilters.map(
                    (bucket) => Chip(
                      avatar: const Icon(Icons.access_time, size: 16),
                      label: Text(bucket.label),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _SummaryCard(
              snapshot: vm.analytics,
              contextLabel: vm.selectedExerciseName,
              lastSessionWeight: vm.lastSessionWeight,
              weightUnit: widget.weightUnit,
            ),
            const SizedBox(height: 12),
            _ChartCard(
              title:
                  '${vm.metric == ProgressMetric.weight ? 'Weight' : 'Estimated 1RM'} Trend — ${vm.selectedExerciseName}',
              subtitle: vm.metric == ProgressMetric.weight
                  ? (vm.mode == ProgressAggMode.avgPerSession
                      ? 'Average weight per session'
                      : 'Set order: ${vm.mode.label}')
                  : (vm.mode == ProgressAggMode.avgPerSession
                      ? 'Heaviest set estimate (Epley)'
                      : 'Set order: ${vm.mode.label} · Epley estimate'),
              points: vm.series,
              weightUnit: widget.weightUnit,
              metric: vm.metric,
            ),
            const SizedBox(height: 16),
            ProgressFilters(
              mode: vm.mode,
              range: vm.range,
              metric: vm.metric,
              metricOptions: ProgressMetric.values,
              onModeChanged: (mode) => _reload(mode: mode),
              onRangeChanged: (range) => _reload(range: range),
              onMetricChanged: (metric) => _reload(metric: metric),
            ),
            const SizedBox(height: 16),
            if (vm.analytics.volumeByTimeOfDay.isNotEmpty) ...[
              _TimeOfDayCard(
                entries: vm.analytics.volumeByTimeOfDay,
                weightUnit: widget.weightUnit,
              ),
              const SizedBox(height: 12),
            ],
            if (vm.analytics.personalRecords.isNotEmpty) ...[
              _PrCard(
                records: vm.analytics.personalRecords,
                weightUnit: widget.weightUnit,
              ),
              const SizedBox(height: 12),
            ],
            ProgressPointsRecap(
              points: vm.series,
              weightUnit: widget.weightUnit,
              metric: vm.metric,
            ),
          ],
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                           SHARED HELPER WIDGETS                            */
/* -------------------------------------------------------------------------- */

class _DropdownOption {
  const _DropdownOption({required this.value, required this.label});

  final int value;
  final String label;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.snapshot,
    required this.contextLabel,
    required this.lastSessionWeight,
    required this.weightUnit,
  });

  final AnalyticsSnapshot snapshot;
  final String contextLabel;
  final double? lastSessionWeight;
  final WeightUnit weightUnit;

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
            Text('Overview — $contextLabel', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MetricTile(label: 'Sessions', value: snapshot.sessionCount.toString()),
                _MetricTile(
                  label: 'Avg / session',
                  value: snapshot.sessionCount == 0
                      ? '—'
                      : _formatWeight(snapshot.averageVolumePerSession, weightUnit),
                ),
                _MetricTile(
                  label: 'Last session',
                  value: lastSessionWeight == null ? '—' : _formatWeight(lastSessionWeight!, weightUnit),
                ),
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
        final double proportion = maxValue == 0 ? 0.05 : (point.value / maxValue).clamp(0.05, 1.0);
        return Flexible(
          fit: FlexFit.tight,
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
  const _TimeOfDayCard({required this.entries, required this.weightUnit});

  final List<TimeOfDayVolume> entries;
  final WeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVolume = entries
        .map((e) => max(e.averageVolume, e.lastSessionVolume))
        .fold<double>(0, max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Volume by time of day', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (entries.isEmpty || maxVolume == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No volume logged for these time slots yet.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...[
              Builder(
                builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  final averageColor = scheme.primary;
                  final lastColor = Color.lerp(scheme.primary, scheme.primaryContainer, 0.45)!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _LegendItem(label: 'Average', swatchColor: averageColor),
                          const SizedBox(width: 16),
                          _LegendItem(label: 'Last session', swatchColor: lastColor),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _TimeOfDayBarChart(
                        entries: entries,
                        maxVolume: maxVolume,
                        primaryColor: averageColor,
                        secondaryColor: lastColor,
                        textTheme: theme.textTheme,
                        weightUnit: weightUnit,
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeOfDayBarChart extends StatelessWidget {
  const _TimeOfDayBarChart({
    required this.entries,
    required this.maxVolume,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textTheme,
    required this.weightUnit,
  });

  final List<TimeOfDayVolume> entries;
  final double maxVolume;
  final Color primaryColor;
  final Color secondaryColor;
  final TextTheme textTheme;
  final WeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    const double chartHeight = 140;
    final ticks = _buildTicks(maxVolume);

    return SizedBox(
      height: chartHeight + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _YAxis(
            ticks: ticks,
            chartHeight: chartHeight,
            textTheme: textTheme,
            weightUnit: weightUnit,
          ),
          const SizedBox(width: 16),
          Flexible(
            fit: FlexFit.tight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries
                  .map(
                    (entry) => Flexible(
                      fit: FlexFit.tight,
                      child: _TimeBucketBars(
                        entry: entry,
                        maxVolume: maxVolume,
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        textTheme: textTheme,
                        chartHeight: chartHeight,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _buildTicks(double maxVolume) {
    if (maxVolume <= 0) return const [0];
    final mid = maxVolume / 2;
    return [maxVolume, mid, 0];
  }
}

class _TimeBucketBars extends StatelessWidget {
  const _TimeBucketBars({
    required this.entry,
    required this.maxVolume,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textTheme,
    required this.chartHeight,
  });

  final TimeOfDayVolume entry;
  final double maxVolume;
  final Color primaryColor;
  final Color secondaryColor;
  final TextTheme textTheme;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final avgRatio = maxVolume == 0 ? 0.0 : entry.averageVolume / maxVolume;
    final lastRatio = maxVolume == 0 ? 0.0 : entry.lastSessionVolume / maxVolume;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: chartHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Bar(height: chartHeight * avgRatio, color: primaryColor),
                  const SizedBox(width: 6),
                  _Bar(height: chartHeight * lastRatio, color: secondaryColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(entry.bucket.label, style: textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height.isNaN || height.isNegative ? 0.0 : height;
    return Container(
      width: 14,
      height: effectiveHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.65),
            color.withOpacity(0.25),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: color.withOpacity(0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.swatchColor});

  final String label;
  final Color swatchColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: swatchColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: swatchColor.withOpacity(0.25)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _YAxis extends StatelessWidget {
  const _YAxis({
    required this.ticks,
    required this.chartHeight,
    required this.textTheme,
    required this.weightUnit,
  });

  final List<double> ticks;
  final double chartHeight;
  final TextTheme textTheme;
  final WeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    if (ticks.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 48,
      height: chartHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: ticks.map((tick) {
          final label = tick == 0 ? '0' : _formatWeight(tick, weightUnit);
          return Text(label, style: textTheme.bodySmall);
        }).toList(),
      ),
    );
  }
}

class _PrCard extends StatelessWidget {
  const _PrCard({required this.records, required this.weightUnit});

  final List<PersonalRecord> records;
  final WeightUnit weightUnit;

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
                  '${_formatWeight(record.weight, weightUnit)} · ${record.reps} reps · 1RM ${_formatWeight(record.estimatedOneRm, weightUnit)}',
                ),
                trailing: Text(formatDateYmd(record.achievedAt)),
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
    required this.weightUnit,
    required this.metric,
  });

  final String title;
  final String subtitle;
  final List<ProgressPoint> points;
  final WeightUnit weightUnit;
  final ProgressMetric metric;

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
              Flexible(
                fit: FlexFit.tight,
                child: ProgressLineChart(points: points, weightUnit: weightUnit, metric: metric),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   MODELS                                   */
/* -------------------------------------------------------------------------- */

class _TemplateVM {
  _TemplateVM({
    required this.templates,
    required this.selectedTemplateId,
    required this.analytics,
    required this.sessions,
  });

  final List<_TemplateRow> templates;
  final int selectedTemplateId;
  final AnalyticsSnapshot analytics;
  final List<_TemplateSessionRow> sessions;
}

class _TemplateRow {
  _TemplateRow({required this.id, required this.name});
  final int id;
  final String name;
}

class _TemplateSessionRow {
  _TemplateSessionRow({
    required this.name,
    required this.startedAt,
    required this.volume,
    required this.setCount,
  });

  final String name;
  final DateTime startedAt;
  final double volume;
  final int setCount;
}

class _ExerciseVM {
  _ExerciseVM({
    required this.exercises,
    required this.selectedExerciseId,
    required this.selectedExerciseName,
    required this.mode,
    required this.range,
    required this.metric,
    required this.series,
    required this.analytics,
    required this.lastSessionWeight,
  });

  final List<_ExerciseRow> exercises;
  final int? selectedExerciseId;
  final String selectedExerciseName;
  final ProgressAggMode mode;
  final ProgressRange range;
  final ProgressMetric metric;
  final List<ProgressPoint> series;
  final AnalyticsSnapshot analytics;
  final double? lastSessionWeight;
}

class _ExerciseRow {
  _ExerciseRow({required this.id, required this.name, required this.category});
  final int id;
  final String name;
  final String category;
}

class _ExerciseSessionAggregate {
  _ExerciseSessionAggregate({required this.timestamp});

  DateTime timestamp;
  double totalWeight = 0;
}

/* -------------------------------------------------------------------------- */
/*                                  HELPERS                                   */
/* -------------------------------------------------------------------------- */

String _normalizeName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == 'Workout') return 'Workout';
  return trimmed;
}

String _formatWeight(double kilos, WeightUnit unit) => formatCompactWeight(kilos, unit);

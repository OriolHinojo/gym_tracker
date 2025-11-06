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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Templates'),
              Tab(text: 'Exercises'),
              Tab(text: 'Tags & Time'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TemplatesTab(analytics: _analytics),
            _ExercisesTab(analytics: _analytics, calculator: _calculator),
            _TagsTab(analytics: _analytics),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               TEMPLATES TAB                                */
/* -------------------------------------------------------------------------- */

class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab({required this.analytics});

  final AnalyticsService analytics;

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

        final dropdownItems = [
          const DropdownMenuItem<int>(value: _allTemplates, child: Text('All templates')),
          ...vm.templates.map(
            (tpl) => DropdownMenuItem<int>(
              value: tpl.id,
              child: Text(tpl.name),
            ),
          ),
        ];
        final contextLabel = vm.selectedTemplateId == _allTemplates
            ? 'All templates'
            : vm.templates.firstWhere((tpl) => tpl.id == vm.selectedTemplateId, orElse: () {
                return _TemplateRow(id: vm.selectedTemplateId!, name: 'Template');
              }).name;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: vm.selectedTemplateId,
                    decoration: const InputDecoration(
                      labelText: 'Template',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: dropdownItems,
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
            _SummaryCard(snapshot: vm.analytics, contextLabel: contextLabel),
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
                  subtitle: Text(_formatDate(session.startedAt)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatWeight(session.volume)),
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
  const _ExercisesTab({required this.analytics, required this.calculator});

  final AnalyticsService analytics;
  final ProgressCalculator calculator;

  @override
  State<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<_ExercisesTab> {
  int? _selectedExerciseId;
  String _selectedExerciseName = '';
  ProgressAggMode _mode = ProgressAggMode.avgPerSession;
  ProgressRange _range = ProgressRange.w8;
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
    );

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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: vm.selectedExerciseId,
                    decoration: const InputDecoration(
                      labelText: 'Exercise',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
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
            _SummaryCard(snapshot: vm.analytics, contextLabel: vm.selectedExerciseName),
            const SizedBox(height: 12),
            if (vm.analytics.volumeByTimeOfDay.isNotEmpty) ...[
              _TimeOfDayCard(entries: vm.analytics.volumeByTimeOfDay),
              const SizedBox(height: 12),
            ],
            if (vm.analytics.personalRecords.isNotEmpty) ...[
              _PrCard(records: vm.analytics.personalRecords),
              const SizedBox(height: 12),
            ],
            _SectionHeader(title: 'Weight trend'),
            const SizedBox(height: 8),
            ProgressFilters(
              mode: vm.mode,
              range: vm.range,
              onModeChanged: (mode) => _reload(mode: mode),
              onRangeChanged: (range) => _reload(range: range),
            ),
            const SizedBox(height: 12),
            _ChartCard(
              title: 'Weight Trend — ${vm.selectedExerciseName}',
              subtitle:
                  vm.mode == ProgressAggMode.avgPerSession ? 'Average weight per session' : 'Set order: ${vm.mode.label}',
              points: vm.series,
            ),
            const SizedBox(height: 16),
            ProgressPointsRecap(points: vm.series),
          ],
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               TAGS / TIME TAB                              */
/* -------------------------------------------------------------------------- */

class _TagsTab extends StatefulWidget {
  const _TagsTab({required this.analytics});

  final AnalyticsService analytics;

  @override
  State<_TagsTab> createState() => _TagsTabState();
}

class _TagsTabState extends State<_TagsTab> {
  final Set<SetTag> _selectedTags = <SetTag>{};
  final Set<TimeOfDayBucket> _selectedTimeBuckets = <TimeOfDayBucket>{};

  late Future<_TagVM> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TagVM> _load() async {
    final analytics = await widget.analytics.snapshot(
      filters: AnalyticsFilters(
        tags: _selectedTags.isEmpty ? null : _selectedTags,
        timeOfDayBuckets: _selectedTimeBuckets.isEmpty ? null : _selectedTimeBuckets,
        includeZeroVolumeSessions: true,
      ),
    );
    return _TagVM(analytics: analytics);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TagVM>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load tag analytics.\n${snapshot.error}'));
        }
        final vm = snapshot.data!;
        final contextLabel = _buildContextLabel();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Set tags', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: kAvailableSetTags
                  .map(
                    (tag) => FilterChip(
                      label: Text(tag.label),
                      selected: _selectedTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                          _future = _load();
                        });
                      },
                    ),
                  )
                  .toList(),
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
                      selected: _selectedTimeBuckets.contains(bucket),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTimeBuckets.add(bucket);
                          } else {
                            _selectedTimeBuckets.remove(bucket);
                          }
                          _future = _load();
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (_selectedTags.isNotEmpty || _selectedTimeBuckets.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedTags.clear();
                      _selectedTimeBuckets.clear();
                      _future = _load();
                    });
                  },
                  child: const Text('Clear all'),
                ),
              ),
            const SizedBox(height: 12),
            _SummaryCard(snapshot: vm.analytics, contextLabel: contextLabel),
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
          ],
        );
      },
    );
  }

  String _buildContextLabel() {
    final tagPart = _selectedTags.map((t) => t.label).join(', ');
    final timePart = _selectedTimeBuckets.map((b) => b.label).join(', ');
    if (tagPart.isEmpty && timePart.isEmpty) return 'All sessions';
    if (tagPart.isNotEmpty && timePart.isNotEmpty) {
      return '$tagPart · $timePart';
    }
    return tagPart.isNotEmpty ? tagPart : timePart;
  }
}

/* -------------------------------------------------------------------------- */
/*                           SHARED HELPER WIDGETS                            */
/* -------------------------------------------------------------------------- */

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot, required this.contextLabel});

  final AnalyticsSnapshot snapshot;
  final String contextLabel;

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
        final double proportion = maxValue == 0 ? 0.05 : (point.value / maxValue).clamp(0.05, 1.0);
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
    required this.series,
    required this.analytics,
  });

  final List<_ExerciseRow> exercises;
  final int? selectedExerciseId;
  final String selectedExerciseName;
  final ProgressAggMode mode;
  final ProgressRange range;
  final List<ProgressPoint> series;
  final AnalyticsSnapshot analytics;
}

class _ExerciseRow {
  _ExerciseRow({required this.id, required this.name, required this.category});
  final int id;
  final String name;
  final String category;
}

class _TagVM {
  _TagVM({required this.analytics});
  final AnalyticsSnapshot analytics;
}

/* -------------------------------------------------------------------------- */
/*                                  HELPERS                                   */
/* -------------------------------------------------------------------------- */

String _normalizeName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == 'Workout') return 'Workout';
  return trimmed;
}

String _formatWeight(double kilos) {
  if (kilos >= 1000) return '${(kilos / 1000).toStringAsFixed(1)}k kg';
  if (kilos >= 100) return '${kilos.toStringAsFixed(0)} kg';
  return '${kilos.toStringAsFixed(1)} kg';
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

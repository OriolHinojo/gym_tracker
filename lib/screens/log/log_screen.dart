import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/screens/library/library_screen.dart';
import 'package:gym_tracker/shared/exercise_category_icons.dart';
import 'package:gym_tracker/widgets/create_exercise_dialog.dart';

enum SetTag { warmUp, dropSet, amrap }

extension SetTagX on SetTag {
  String get storage {
    switch (this) {
      case SetTag.warmUp:
        return 'warm_up';
      case SetTag.dropSet:
        return 'drop_set';
      case SetTag.amrap:
        return 'amrap';
    }
  }

  String get label {
    switch (this) {
      case SetTag.warmUp:
        return 'Warm-up';
      case SetTag.dropSet:
        return 'Drop set';
      case SetTag.amrap:
        return 'AMRAP';
    }
  }

  static SetTag? fromStorage(String? value) {
    switch (value) {
      case 'warm_up':
        return SetTag.warmUp;
      case 'drop_set':
        return SetTag.dropSet;
      case 'amrap':
        return SetTag.amrap;
      default:
        return null;
    }
  }
}

String? tagLabelFromStorage(String? storage) {
  final tag = SetTagX.fromStorage(storage);
  return tag?.label;
}

const List<SetTag> _setTagOptions = <SetTag>[SetTag.warmUp, SetTag.dropSet, SetTag.amrap];

class LogScreen extends StatefulWidget {
  const LogScreen({super.key, this.templateId, this.workoutId, this.editWorkoutId});
  final int? templateId; // when repeating a template (passed via go_router extra)
  final String? workoutId; // optional deep link '/workout/:id'
  final int? editWorkoutId; // when opening from session detail for editing

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  Duration _elapsed = Duration.zero;
  late final Ticker _ticker;
  bool _running = true;

  final List<_ExerciseDraft> _exercises = [];
  int? _expandedExerciseId;
  bool _choiceMade = false;
  int? _editingWorkoutId;
  String _editingWorkoutName = 'Workout';
  DateTime? _editingStartedAt;
  int? _activeTemplateId;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      // Always reflect what the stopwatch says; pausing is handled inside Ticker.
      if (mounted) setState(() => _elapsed = elapsed);
    })
      ..start(); // start running immediately

    _initializeFromRoute();
  }

  Future<void> _initializeFromRoute() async {
    if (widget.templateId != null) {
      await _applyTemplate(widget.templateId!);
      return;
    }
    final editId = widget.editWorkoutId ?? int.tryParse(widget.workoutId ?? '');
    if (editId != null) {
      await _loadWorkoutFromId(editId, markChoice: true, enableEditing: true);
    }
  }

  Future<void> _applyTemplate(int templateId) async {
    final tpl = await LocalStore.instance.getWorkoutTemplateRaw(templateId);
    if (tpl == null) return;
    final ids = ((tpl['exercise_ids'] ?? []) as List).map((e) => (e as num).toInt()).toList();
    final all = await LocalStore.instance.listExercisesRaw();

    final drafts = <_ExerciseDraft>[];
    for (final id in ids) {
      final ex = all.firstWhere(
        (e) => (e['id'] as num).toInt() == id,
        orElse: () => const {'name': 'Unknown', 'category': 'other'},
      );
      final history = await LocalStore.instance.listLatestSetsForExerciseRaw(
        id,
        templateId: templateId,
      );
      final setData = _buildSetDraftsFromRaw(history, asPlaceholder: true);
      drafts.add(_ExerciseDraft(
        id: id,
        name: (ex['name'] ?? 'Exercise').toString(),
        category: (ex['category'] ?? 'other').toString(),
        sets: setData.drafts,
        history: setData.history,
      ));
    }

    if (!mounted) return;
    for (final ex in _exercises) {
      ex.dispose();
    }
    setState(() {
      _exercises
        ..clear()
        ..addAll(drafts);
      for (final exercise in _exercises) {
        exercise.refreshFocusDebugLabels();
      }
      _expandedExerciseId = _exercises.isNotEmpty ? _exercises.first.id : null;
      _choiceMade = true;
      _editingWorkoutId = null;
      _editingWorkoutName = 'Workout';
      _editingStartedAt = null;
      _activeTemplateId = templateId;
      _running = true;
    });
    if (_expandedExerciseId != null && _exercises.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final exercise = _exercises.firstWhere((e) => e.id == _expandedExerciseId, orElse: () => _exercises.first);
        _focusFirstEmptyField(exercise);
      });
    }
  }

  Future<void> _loadWorkoutFromId(
    int workoutId, {
    bool markChoice = false,
    bool usePlaceholders = false,
    bool enableEditing = false,
  }) async {
    final workoutMeta = await LocalStore.instance.getWorkoutRaw(workoutId);
    if (workoutMeta == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Workout not found')));
      }
      return;
    }

    final sets = await LocalStore.instance.listSetsForWorkoutRaw(workoutId);
    if (sets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Previous workout has no logged sets')));
      }
      return;
    }
    final exercises = await LocalStore.instance.listExercisesRaw();
    final exerciseMap = <int, Map<String, dynamic>>{
      for (final e in exercises) (e['id'] as num).toInt(): e,
    };
    final templateId = (workoutMeta['template_id'] as num?)?.toInt();

    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final raw in sets) {
      final exId = (raw['exercise_id'] as num?)?.toInt();
      if (exId == null) continue;
      grouped.putIfAbsent(exId, () => <Map<String, dynamic>>[]).add(raw);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        DateTime dateFor(List<Map<String, dynamic>> list) {
          final raw = list.isEmpty ? null : list.firstWhere(
                (s) => s['created_at'] != null,
                orElse: () => list.first,
              );
          return DateTime.tryParse((raw?['created_at'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
        }

        final da = dateFor(a.value);
        final db = dateFor(b.value);
        return da.compareTo(db);
      });

    final drafts = entries.map((entry) {
      final info = exerciseMap[entry.key] ?? const {'name': 'Exercise', 'category': 'other'};
      final setData = _buildSetDraftsFromRaw(entry.value, asPlaceholder: usePlaceholders);
      return _ExerciseDraft(
        id: entry.key,
        name: (info['name'] ?? 'Exercise').toString(),
        category: (info['category'] ?? 'other').toString(),
        sets: setData.drafts,
        history: setData.history,
      );
    }).toList();

    if (!mounted) return;
    for (final ex in _exercises) {
      ex.dispose();
    }
    setState(() {
      _exercises
        ..clear()
        ..addAll(drafts);
      for (final exercise in _exercises) {
        exercise.refreshFocusDebugLabels();
      }
      _expandedExerciseId = _exercises.isNotEmpty ? _exercises.first.id : null;
      if (markChoice || drafts.isNotEmpty) _choiceMade = true;
      _activeTemplateId = templateId;
      if (enableEditing) {
        _editingWorkoutId = workoutId;
        _editingWorkoutName = (workoutMeta['name'] ?? 'Workout').toString().trim().isEmpty
            ? 'Workout'
            : (workoutMeta['name'] ?? 'Workout').toString();
        _editingStartedAt =
            DateTime.tryParse((workoutMeta['started_at'] ?? '').toString())?.toUtc();
        _running = false;
      } else {
        _editingWorkoutId = null;
        _editingWorkoutName = 'Workout';
        _editingStartedAt = null;
        _running = true;
      }
    });
    if (enableEditing) {
      _ticker.pause();
    } else {
      _ticker.reset();
      _ticker.start();
    }
    if (!enableEditing && usePlaceholders && _exercises.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirstEmptyField(_exercises.first));
    }
  }

  void _startNewWorkout() {
    setState(() {
      _choiceMade = true;
      for (final ex in _exercises) {
        ex.dispose();
      }
      _exercises.clear();
      _expandedExerciseId = null;
      _running = true;
      _editingWorkoutId = null;
      _editingWorkoutName = 'Workout';
      _editingStartedAt = null;
      _activeTemplateId = null;
    });
    _ticker.reset();
    _ticker.start();
  }

  Future<void> _repeatPreviousFlow() async {
    final workouts = await LocalStore.instance.listRecentWorkoutsRaw(limit: 10);
    if (!mounted) return;
    if (workouts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No previous workouts found')));
      return;
    }

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Repeat previous workout'),
              subtitle: const Text('Pick one of your recent sessions'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 320,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: workouts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final w = workouts[index];
                  final wid = (w['id'] as num?)?.toInt();
                  final startedAt = (w['started_at'] ?? '').toString();
                  final label = _formatWorkoutDate(startedAt);
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                      w['name']?.toString().isNotEmpty == true ? w['name'].toString() : 'Workout',
                    ),
                    subtitle: Text(label),
                    onTap: wid == null ? null : () => Navigator.pop(ctx, wid),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedId == null) return;
    await _loadWorkoutFromId(selectedId, markChoice: true, usePlaceholders: true);
  }

  @override
  void dispose() {
    for (final ex in _exercises) {
      ex.dispose();
    }
    _ticker.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final int m = d.inMinutes % 60;
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatWorkoutDate(String isoString) {
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return 'Unknown date';
    final date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }

  String _formatNumber(num value) {
    final double dv = value.toDouble();
    if (dv == dv.roundToDouble()) {
      return dv.toInt().toString();
    }
    final formatted = dv.toStringAsFixed(2);
    return formatted.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatClock(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60) % 60;
    final seconds = totalSeconds % 60;
    final hours = totalSeconds ~/ 3600;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _focusNode(FocusNode node) {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(node);
  }

  void _focusFirstEmptyField(_ExerciseDraft exercise) {
    if (!mounted || exercise.sets.isEmpty) return;
    for (final set in exercise.sets) {
      if (set.weight.text.trim().isEmpty) {
        _focusNode(set.weightFocus);
        return;
      }
      if (set.reps.text.trim().isEmpty) {
        _focusNode(set.repsFocus);
        return;
      }
    }
    _focusNode(exercise.sets.first.weightFocus);
  }

  void _focusRepsField(_ExerciseDraft exercise, _SetDraft set) {
    if (!exercise.sets.contains(set)) return;
    _focusNode(set.repsFocus);
  }

  void _focusNextWeightField(_ExerciseDraft exercise, _SetDraft set) {
    final index = exercise.sets.indexOf(set);
    if (index == -1) return;
    if (index + 1 < exercise.sets.length) {
      _focusNode(exercise.sets[index + 1].weightFocus);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _addBlankSet(_ExerciseDraft exercise) {
    late _SetDraft newSet;
    setState(() {
      final ordinal = exercise.sets.length + 1;
      newSet = exercise.draftForOrdinal(ordinal);
      exercise.sets.add(newSet);
      exercise.refreshFocusDebugLabels();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode(newSet.weightFocus));
  }

  void _duplicateLastSet(_ExerciseDraft exercise) {
    if (exercise.sets.isEmpty) return;
    final last = exercise.sets.last;
    late _SetDraft duplicate;
    setState(() {
      duplicate = _SetDraft(
        weight: last.weight.text,
        reps: last.reps.text,
        weightHint: last.weightHint,
        repsHint: last.repsHint,
        tag: last.tag,
      );
      exercise.sets.add(duplicate);
      exercise.refreshFocusDebugLabels();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode(duplicate.weightFocus));
  }

  void _removeSet(_ExerciseDraft exercise, _SetDraft set) {
    setState(() {
      if (exercise.sets.remove(set)) {
        set.dispose();
        exercise.refreshFocusDebugLabels();
      }
    });
  }

  void _clearWorkoutState() {
    setState(() {
      for (final ex in _exercises) {
        ex.dispose();
      }
      _exercises.clear();
      _expandedExerciseId = null;
      _choiceMade = false;
      _editingWorkoutId = null;
      _editingWorkoutName = 'Workout';
      _editingStartedAt = null;
      _activeTemplateId = null;
      _running = true;
    });
    _ticker.reset();
    _ticker.start();
  }

  @visibleForTesting
  void debugAddExerciseForTest({
    required int id,
    String name = 'Exercise',
    String category = 'other',
    List<Map<String, String>>? presetSets,
  }) {
    final sets = presetSets == null
        ? null
        : presetSets
            .map(
              (entry) => _SetDraft(
                weight: entry['weight'],
                reps: entry['reps'],
                tag: SetTagX.fromStorage(entry['tag']),
              ),
            )
            .toList();
    final exercise = _ExerciseDraft(
      id: id,
      name: name,
      category: category,
      sets: sets,
    );
    setState(() {
      _exercises.add(exercise);
      _expandedExerciseId = id;
      _choiceMade = true;
      exercise.refreshFocusDebugLabels();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusFirstEmptyField(exercise);
    });
  }

  @visibleForTesting
  void debugFocusFirstEmptyForTest(int exerciseId) {
    final exercise = _exercises.firstWhere((e) => e.id == exerciseId, orElse: () => throw ArgumentError('Exercise not found'));
    _focusFirstEmptyField(exercise);
  }

  @visibleForTesting
  bool debugWeightHasFocus(int exerciseId, int ordinal) {
    final exercise = _exercises.firstWhere((e) => e.id == exerciseId, orElse: () => throw ArgumentError('Exercise not found'));
    if (ordinal <= 0 || ordinal > exercise.sets.length) return false;
    return exercise.sets[ordinal - 1].weightFocus.hasPrimaryFocus;
  }

  @visibleForTesting
  void debugDuplicateLastSetForTest(int exerciseId) {
    final exercise = _exercises.firstWhere((e) => e.id == exerciseId, orElse: () => throw ArgumentError('Exercise not found'));
    _duplicateLastSet(exercise);
  }

  Future<void> _discardCurrentWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('All unsaved changes will be lost. This does not delete any logged sessions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    _clearWorkoutState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout discarded')));
    context.go('/log');
  }

  @visibleForTesting
  List<Map<String, String>> debugExerciseSets(int exerciseId) {
    final exercise = _exercises.firstWhere((e) => e.id == exerciseId, orElse: () => throw ArgumentError('Exercise not found'));
    return exercise.sets
        .map(
          (s) => <String, String>{
            'weight': s.weight.text,
            'reps': s.reps.text,
            'tag': s.tag?.storage ?? '',
          },
        )
        .toList(growable: false);
  }

  _SetDraftData _buildSetDraftsFromRaw(List<Map<String, dynamic>> rawSets, {required bool asPlaceholder}) {
    final sorted = List<Map<String, dynamic>>.from(rawSets)
      ..sort((a, b) {
        final ao = (a['ordinal'] as num?)?.toInt() ?? 0;
        final bo = (b['ordinal'] as num?)?.toInt() ?? 0;
        return ao.compareTo(bo);
      });

    final historyEntries = <_SetHistoryEntry>[];
    final Map<int, DateTime?> createdByOrdinal = {};
    for (final set in sorted) {
      final weightVal = set['weight'] as num?;
      final repsVal = set['reps'] as num?;
      if (weightVal == null || repsVal == null) continue;
      final weightStr = _formatNumber(weightVal);
      final repsStr = _formatNumber(repsVal);
      final ordinal = (set['ordinal'] as num?)?.toInt();
      final effectiveOrdinal = ordinal ?? (historyEntries.isEmpty ? 1 : historyEntries.last.ordinal + 1);
      historyEntries.add(_SetHistoryEntry(
        ordinal: effectiveOrdinal,
        weightHint: weightStr,
        repsHint: repsStr,
        tag: set['tag'] == null ? null : set['tag'].toString(),
      ));
      createdByOrdinal[effectiveOrdinal] =
          DateTime.tryParse((set['created_at'] ?? '').toString())?.toUtc();
    }

    if (historyEntries.isEmpty) {
      final fallbackDrafts =
          asPlaceholder ? <_SetDraft>[_SetDraft(), _SetDraft()] : <_SetDraft>[_SetDraft()];
      return _SetDraftData(drafts: fallbackDrafts, history: const <_SetHistoryEntry>[]);
    }

    historyEntries.sort((a, b) => a.ordinal.compareTo(b.ordinal));
    final drafts = <_SetDraft>[];
    for (final entry in historyEntries) {
      final createdAt = createdByOrdinal[entry.ordinal];
      drafts.add(_SetDraft(
        weight: entry.weightHint,
        reps: entry.repsHint,
        weightHint: entry.weightHint,
        repsHint: entry.repsHint,
        done: !asPlaceholder,
        originalTimestamp: asPlaceholder ? null : createdAt,
        tag: SetTagX.fromStorage(entry.tag),
      ));
    }

    return _SetDraftData(drafts: drafts, history: historyEntries);
  }

  Widget _buildWorkoutBody(String time) {
    final editing = _editingWorkoutId != null;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final outline = colorScheme.outline;
    final children = <Widget>[];

    if (editing) {
      final started = _editingStartedAt?.toLocal();
      String subtitle;
      if (started == null) {
        subtitle = 'Review your logged sets below';
      } else {
        String two(int n) => n.toString().padLeft(2, '0');
        subtitle =
            'Started ${started.year}-${two(started.month)}-${two(started.day)} at ${two(started.hour)}:${two(started.minute)}';
      }
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Editing workout', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(subtitle, style: textTheme.bodySmall),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _addExerciseFlow,
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
          ],
        ),
      );
    } else {
      children.add(
        Row(
          children: <Widget>[
            Chip(label: Text('Timer: $time')),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                setState(() {
                  _running = !_running;
                  if (_running) {
                    _ticker.start();
                  } else {
                    _ticker.pause();
                  }
                });
              },
              icon: Icon(_running ? Icons.pause : Icons.play_arrow),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _addExerciseFlow,
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
          ],
        ),
      );
    }

    children.add(const SizedBox(height: 12));

    if (_exercises.isEmpty) {
      children.add(
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('No exercises yet'),
            subtitle: const Text('Add from Library or create on the fly'),
            trailing: FilledButton(onPressed: _addExerciseFlow, child: const Text('Add')),
          ),
        ),
      );
    }

    children.addAll(_exercises.map((ex) {
      final expanded = _expandedExerciseId == ex.id;
      return Card(
        child: Column(
          children: [
            ListTile(
              title: Text(ex.name),
              subtitle: Text(ex.category),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'History',
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ExerciseDetailScreen(id: ex.id),
                      ));
                    },
                    icon: const Icon(Icons.history),
                  ),
                  IconButton(
                    tooltip: expanded ? 'Save exercise' : 'Edit',
                    onPressed: () {
                      setState(() {
                        if (expanded) {
                          _expandedExerciseId = null;
                        } else {
                          _expandedExerciseId = ex.id;
                        }
                      });
                      if (!expanded) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _focusFirstEmptyField(ex);
                        });
                      }
                    },
                    icon: Icon(expanded ? Icons.save_outlined : Icons.edit),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => setState(() {
                      ex.dispose();
                      _exercises.remove(ex);
                      if (_expandedExerciseId == ex.id) {
                        _expandedExerciseId = null;
                      }
                      if (_exercises.isEmpty) {
                        _choiceMade = false;
                      }
                    }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            if (expanded) const Divider(height: 1),
            if (expanded)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final restElapsed = ex.restElapsed(now);
                    final overTarget = ex.restRunning && restElapsed > ex.restTarget;
                    final restColor = overTarget ? colorScheme.error : outline;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () {
                                setState(() {
                                  if (ex.restRunning) {
                                    ex.stopRest(DateTime.now());
                                  } else {
                                    ex.startRest(DateTime.now());
                                  }
                                });
                              },
                              icon: Icon(ex.restRunning ? Icons.stop_circle_outlined : Icons.play_arrow_rounded),
                              label: Text(ex.restRunning ? 'Stop rest' : 'Start rest'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Elapsed: ${_formatClock(restElapsed)}',
                                    style: textTheme.bodySmall?.copyWith(color: restColor),
                                  ),
                                  Text(
                                    'Target: ${_formatClock(ex.restTarget)}',
                                    style: textTheme.labelMedium,
                                  ),
                                  if (ex.lastRestDuration != null)
                                    Text(
                                      'Last: ${_formatClock(ex.lastRestDuration!)}',
                                      style: textTheme.labelSmall?.copyWith(color: outline),
                                    ),
                                  if (overTarget)
                                    Text(
                                      '+ ${_formatClock(restElapsed - ex.restTarget)} over target',
                                      style: textTheme.labelSmall?.copyWith(color: colorScheme.error),
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuButton<int>(
                              tooltip: 'Adjust target',
                              onSelected: (seconds) {
                                setState(() {
                                  ex.updateRestTarget(Duration(seconds: seconds));
                                });
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 60, child: Text('1:00')),
                                PopupMenuItem(value: 90, child: Text('1:30')),
                                PopupMenuItem(value: 120, child: Text('2:00')),
                                PopupMenuItem(value: 180, child: Text('3:00')),
                              ],
                              child: const Icon(Icons.timer_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...ex.sets.asMap().entries.map((entry) {
                          final index = entry.key;
                          final displayIndex = index + 1;
                          final s = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    SizedBox(width: 32, child: Center(child: Text('$displayIndex'))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: s.weight,
                                        focusNode: s.weightFocus,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.next,
                                        onSubmitted: (_) => _focusRepsField(ex, s),
                                        decoration: InputDecoration(
                                          labelText: 'Weight',
                                          hintText: s.weightHint,
                                          floatingLabelBehavior: FloatingLabelBehavior.always,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: s.reps,
                                        focusNode: s.repsFocus,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        onSubmitted: (_) => _focusNextWeightField(ex, s),
                                        decoration: InputDecoration(
                                          labelText: 'Reps',
                                          hintText: s.repsHint,
                                          floatingLabelBehavior: FloatingLabelBehavior.always,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Checkbox(
                                      value: s.done,
                                      onChanged: (v) => setState(() => s.done = v ?? false),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete set',
                                      onPressed: () => _removeSet(ex, s),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const SizedBox(width: 32),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Tag',
                                            border: OutlineInputBorder(),
                                          ),
                                          child: DropdownButton<SetTag?>(
                                            value: s.tag,
                                            isExpanded: true,
                                            onChanged: (value) {
                                              setState(() => s.tag = value);
                                            },
                                            items: [
                                              const DropdownMenuItem<SetTag?>(
                                                value: null,
                                                child: Text('No tag'),
                                              ),
                                              ..._setTagOptions.map(
                                                (tag) => DropdownMenuItem<SetTag?>(
                                                  value: tag,
                                                  child: Text(tag.label),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => _addBlankSet(ex),
                              child: const Text('Add set'),
                            ),
                            TextButton.icon(
                              onPressed: ex.sets.isEmpty ? null : () => _duplicateLastSet(ex),
                              icon: const Icon(Icons.copy),
                              label: const Text('Same as last'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      );
    }));

    children.add(const SizedBox(height: 80));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  Widget _buildStartOptions(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'How do you want to train today?',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.flash_on_outlined),
                title: const Text('Start new workout'),
                subtitle: const Text('Build a fresh session from scratch.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _startNewWorkout,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('Repeat previous workout'),
                subtitle: const Text('Load exercises and sets from a recent session.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _repeatPreviousFlow,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => context.push('/library'),
              icon: const Icon(Icons.fitness_center_outlined),
              label: const Text('Browse templates in Library'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addExerciseFlow() async {
    final all = await LocalStore.instance.listExercisesRaw();
    int? selectedId;
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setD) {
              final query = searchQuery.trim().toLowerCase();
              final filtered = all.where((e) {
                final name = (e['name'] ?? '').toString();
                if (query.isEmpty) return true;
                return name.toLowerCase().contains(query);
              }).toList();

              return SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Add Exercise',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search exercises',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => setD(() => searchQuery = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No exercises found'))
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final e = filtered[index];
                                final id = (e['id'] as num).toInt();
                                final name = (e['name'] ?? '').toString();
                                final category = (e['category'] ?? 'other').toString();
                                return RadioListTile<int>(
                                  value: id,
                                  groupValue: selectedId,
                                  onChanged: (value) => setD(() => selectedId = value),
                                  title: Text(name),
                                  secondary: Icon(exerciseCategoryIcon(category)),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Create new exercise'),
                      subtitle: const Text('Add and select immediately'),
                      onTap: () async {
                        final created = await showCreateExerciseDialog(context);
                        if (!mounted || created == null) return;
                        late _ExerciseDraft newExercise;
                        setState(() {
                          newExercise = _ExerciseDraft(
                            id: created.id,
                            name: created.name,
                            category: created.category,
                          );
                          _exercises.add(newExercise);
                          _expandedExerciseId = created.id;
                          _choiceMade = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _focusFirstEmptyField(newExercise);
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: selectedId == null
                                ? null
                                : () async {
                                    final id = selectedId!;
                                    final ex = all.firstWhere((e) => (e['id'] as num).toInt() == id);
                                    final name = (ex['name'] ?? 'Exercise').toString();
                                    final category = (ex['category'] ?? 'other').toString();
                                    final history = await LocalStore.instance
                                        .listLatestSetsForExerciseRaw(
                                      id,
                                      templateId: _activeTemplateId,
                                    );
                                    final setData = _buildSetDraftsFromRaw(
                                      history,
                                      asPlaceholder: true,
                                    );
                                    if (!mounted) return;
                                    late _ExerciseDraft newExercise;
                                    setState(() {
                                      newExercise = _ExerciseDraft(
                                        id: id,
                                        name: name,
                                        category: category,
                                        sets: setData.drafts,
                                        history: setData.history,
                                      );
                                      _exercises.add(newExercise);
                                      _expandedExerciseId = id;
                                      _choiceMade = true;
                                    });
                                    WidgetsBinding.instance.addPostFrameCallback(
                                      (_) => _focusFirstEmptyField(newExercise),
                                    );
                                    if (context.mounted) Navigator.pop(ctx);
                                  },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    searchController.dispose();
  }


  Future<void> _saveAsTemplateFlow() async {
    if (_exercises.isEmpty) return;
    final nameCtrl = TextEditingController(text: 'My Workout');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Workout Template'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Template name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final ids = _exercises.map((e) => e.id).toList();
              await LocalStore.instance.createWorkoutTemplate(
                name: nameCtrl.text.trim().isEmpty ? 'Workout' : nameCtrl.text.trim(),
                exerciseIds: ids,
              );
              if (context.mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved as template')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishAndPersist() async {
    if (_exercises.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one exercise')));
      }
      return;
    }

    // NOTE: Checkbox is a visual "done" marker only. We still save any set with valid numbers.
    final sets = <Map<String, dynamic>>[];
    final nowUtc = DateTime.now().toUtc();
    for (final ex in _exercises) {
      int ord = 1;
      for (final s in ex.sets) {
        final weight = double.tryParse(s.weight.text.trim());
        final reps = int.tryParse(s.reps.text.trim());
        if (weight == null || reps == null || weight <= 0 || reps <= 0) continue;
        final createdAt = s.originalTimestamp ??
            (_editingWorkoutId != null ? (_editingStartedAt ?? nowUtc) : nowUtc);
        sets.add({
          'exercise_id': ex.id,
          'ordinal': ord++,
          'reps': reps,
          'weight': weight,
          'created_at': createdAt,
          'tag': s.tagStorage,
        });
      }
    }

    if (sets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to save')));
      }
      return;
    }

    if (_editingWorkoutId != null) {
      final editingId = _editingWorkoutId!;
      await LocalStore.instance.updateWorkout(
        workoutId: editingId,
        name: _editingWorkoutName,
        notes: null,
        startedAtUtc: _editingStartedAt,
        sets: sets,
        templateId: _activeTemplateId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout updated')));
      context.go('/sessions/$editingId');
      return;
    }

    await LocalStore.instance.saveWorkout(
      userId: 1,
      name: 'Workout',
      sets: sets,
      templateId: _activeTemplateId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout saved')));
    _clearWorkoutState();

    // Go back to the Log tab explicitly
    context.go('/log');
  }

  @override
  Widget build(BuildContext context) {
    final String time = _format(_elapsed);
    final bool inWorkout = _choiceMade || _exercises.isNotEmpty;
    final bool editing = _editingWorkoutId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit $_editingWorkoutName' : 'Workout'),
        actions: inWorkout
            ? <Widget>[
                IconButton(
                  onPressed: _discardCurrentWorkout,
                  icon: const Icon(Icons.delete_forever_outlined),
                  tooltip: 'Discard workout',
                ),
                if (!editing)
                  IconButton(
                    onPressed: _saveAsTemplateFlow,
                    icon: const Icon(Icons.save_outlined),
                    tooltip: 'Save as template',
                  ),
                FilledButton(
                  onPressed: _finishAndPersist,
                  child: Text(editing ? 'Save' : 'Finish'),
                ),
              ]
            : null,
      ),
      body: inWorkout ? _buildWorkoutBody(time) : _buildStartOptions(context),
    );
  }
}

/* ---------------------------- Data in the screen ---------------------------- */

class _ExerciseDraft {
  _ExerciseDraft({
    required this.id,
    required this.name,
    required this.category,
    List<_SetDraft>? sets,
    List<_SetHistoryEntry>? history,
  })  : sets = sets ?? <_SetDraft>[_SetDraft(), _SetDraft()],
        _history = _prepareHistory(history),
        _historyByOrdinal = <int, _SetHistoryEntry>{} {
    for (final entry in _history) {
      _historyByOrdinal[entry.ordinal] = entry;
    }
    refreshFocusDebugLabels();
  }

  final int id;
  final String name;
  final String category;
  final List<_SetDraft> sets;
  final List<_SetHistoryEntry> _history;
  final Map<int, _SetHistoryEntry> _historyByOrdinal;

  Duration restTarget = const Duration(seconds: 90);
  Duration? lastRestDuration;
  DateTime? restStartedAt;

  bool get restRunning => restStartedAt != null;

  Duration restElapsed(DateTime now) {
    if (restStartedAt == null) return Duration.zero;
    return now.difference(restStartedAt!);
  }

  void startRest(DateTime now) {
    if (lastRestDuration != null) {
      restTarget = lastRestDuration!;
    }
    restStartedAt = now;
  }

  void stopRest(DateTime now) {
    if (restStartedAt == null) return;
    lastRestDuration = now.difference(restStartedAt!);
    restStartedAt = null;
  }

  void updateRestTarget(Duration target) {
    restTarget = target;
  }

  void refreshFocusDebugLabels() {
    for (var i = 0; i < sets.length; i++) {
      final ordinal = i + 1;
      sets[i].weightFocus.debugLabel = 'exercise-$id-set-$ordinal-weight';
      sets[i].repsFocus.debugLabel = 'exercise-$id-set-$ordinal-reps';
    }
  }

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }

  static List<_SetHistoryEntry> _prepareHistory(List<_SetHistoryEntry>? source) {
    final list = source != null ? List<_SetHistoryEntry>.from(source) : <_SetHistoryEntry>[];
    list.sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return list;
  }

  _SetDraft draftForOrdinal(int ordinal) {
    final exact = _historyByOrdinal[ordinal];
    if (exact != null) {
      return _SetDraft(
        weight: exact.weightHint,
        reps: exact.repsHint,
        weightHint: exact.weightHint,
        repsHint: exact.repsHint,
        tag: SetTagX.fromStorage(exact.tag),
      );
    }

    if (_history.isEmpty) {
      return _SetDraft();
    }
    final fallback = _history.last;
    return _SetDraft(
      weight: fallback.weightHint,
      reps: fallback.repsHint,
      weightHint: fallback.weightHint,
      repsHint: fallback.repsHint,
      tag: SetTagX.fromStorage(fallback.tag),
    );
  }
}

class _SetDraft {
  _SetDraft({
    String? weight,
    String? reps,
    this.weightHint,
    this.repsHint,
    this.done = false,
    this.originalTimestamp,
    SetTag? tag,
  }) : tag = tag {
    if (weight != null && weight.isNotEmpty) {
      this.weight.text = weight;
    }
    if (reps != null && reps.isNotEmpty) {
      this.reps.text = reps;
    }
  }

  final TextEditingController weight = TextEditingController();
  final TextEditingController reps = TextEditingController();
  final FocusNode weightFocus = FocusNode();
  final FocusNode repsFocus = FocusNode();
  final String? weightHint;
  final String? repsHint;
  bool done;
  final DateTime? originalTimestamp;
  SetTag? tag;

  String? get tagStorage => tag?.storage;

  void dispose() {
    weight.dispose();
    reps.dispose();
    weightFocus.dispose();
    repsFocus.dispose();
  }

  void applyFrom(_SetDraft other) {
    weight.text = other.weight.text;
    reps.text = other.reps.text;
    tag = other.tag;
    done = other.done;
  }
}

class _SetHistoryEntry {
  const _SetHistoryEntry({
    required this.ordinal,
    this.weightHint,
    this.repsHint,
    this.tag,
  });

  final int ordinal;
  final String? weightHint;
  final String? repsHint;
  final String? tag;
}

class _SetDraftData {
  _SetDraftData({required this.drafts, required this.history});

  final List<_SetDraft> drafts;
  final List<_SetHistoryEntry> history;
}

/* --------------------------------- Ticker --------------------------------- */

class Ticker {
  Ticker(this.onTick);
  final void Function(Duration) onTick;

  final Stopwatch _sw = Stopwatch();
  bool _loopActive = false;

  /// Start or resume the stopwatch (timer keeps its previous elapsed value).
  void start() {
    if (!_loopActive) {
      _loopActive = true;
      _tick();
    }
    _sw.start();
  }

  /// Pause the stopwatch (elapsed time is frozen until start() is called again).
  void pause() {
    _sw.stop();
  }

  /// Optional: reset the stopwatch to zero and pause it.
  void reset() {
    _sw
      ..reset()
      ..stop();
    onTick(Duration.zero);
  }

  void dispose() {
    _loopActive = false;
  }

  Future<void> _tick() async {
    // Single loop that drives UI updates; does not accumulate time while paused,
    // because Stopwatch doesn't advance when stopped.
    while (_loopActive) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      onTick(_sw.elapsed);
    }
  }
}

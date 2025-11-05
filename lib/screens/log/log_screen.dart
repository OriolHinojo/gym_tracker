import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/screens/library/library_screen.dart';
import 'package:gym_tracker/shared/exercise_category_icons.dart';
import 'package:gym_tracker/widgets/create_exercise_dialog.dart';

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
      final history = await LocalStore.instance.listLatestSetsForExerciseRaw(id);
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
    setState(() {
      _exercises
        ..clear()
        ..addAll(drafts);
      _expandedExerciseId = _exercises.isNotEmpty ? _exercises.first.id : null;
      _choiceMade = true;
      _editingWorkoutId = null;
      _editingWorkoutName = 'Workout';
      _editingStartedAt = null;
    });
  }

  Future<void> _loadWorkoutFromId(
    int workoutId, {
    bool markChoice = false,
    bool usePlaceholders = false,
    bool enableEditing = false,
  }) async {
    Map<String, dynamic>? workoutMeta;
    if (enableEditing) {
      workoutMeta = await LocalStore.instance.getWorkoutRaw(workoutId);
      if (workoutMeta == null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Workout not found')));
        }
        return;
      }
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
    setState(() {
      _exercises
        ..clear()
        ..addAll(drafts);
      _expandedExerciseId = _exercises.isNotEmpty ? _exercises.first.id : null;
      if (markChoice || drafts.isNotEmpty) _choiceMade = true;
      if (enableEditing) {
        _editingWorkoutId = workoutId;
        _editingWorkoutName = (workoutMeta?['name'] ?? 'Workout').toString().trim().isEmpty
            ? 'Workout'
            : (workoutMeta?['name'] ?? 'Workout').toString();
        _editingStartedAt =
            DateTime.tryParse((workoutMeta?['started_at'] ?? '').toString())?.toUtc();
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
  }

  void _startNewWorkout() {
    setState(() {
      _choiceMade = true;
      _exercises.clear();
      _expandedExerciseId = null;
      _running = true;
      _editingWorkoutId = null;
      _editingWorkoutName = 'Workout';
      _editingStartedAt = null;
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
      ));
    }

    return _SetDraftData(drafts: drafts, history: historyEntries);
  }

  Widget _buildWorkoutBody(String time) {
    final editing = _editingWorkoutId != null;
    final textTheme = Theme.of(context).textTheme;
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
                    onPressed: () => setState(() {
                      if (expanded) {
                        _expandedExerciseId = null;
                      } else {
                        _expandedExerciseId = ex.id;
                      }
                    }),
                    icon: Icon(expanded ? Icons.save_outlined : Icons.edit),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => setState(() => _exercises.removeWhere((e) => e.id == ex.id)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            if (expanded) const Divider(height: 1),
            if (expanded)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ...ex.sets.asMap().entries.map((entry) {
                      final i = entry.key + 1;
                      final s = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: <Widget>[
                            SizedBox(width: 32, child: Center(child: Text('$i'))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: s.weight,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Reps',
                                  hintText: s.repsHint,
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Checkbox(value: s.done, onChanged: (v) => setState(() => s.done = v ?? false)),
                            IconButton(
                              tooltip: 'Delete set',
                              onPressed: () => setState(() => ex.sets.remove(s)),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonal(
                        onPressed: () => setState(() {
                          final ordinal = ex.sets.length + 1;
                          ex.sets.add(ex.draftForOrdinal(ordinal));
                        }),
                        child: const Text('Add set'),
                      ),
                    ),
                  ],
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
                        setState(() {
                          _exercises.add(_ExerciseDraft(
                            id: created.id,
                            name: created.name,
                            category: created.category,
                          ));
                          _expandedExerciseId = created.id;
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
                                    final history =
                                        await LocalStore.instance.listLatestSetsForExerciseRaw(id);
                                    final setData = _buildSetDraftsFromRaw(
                                      history,
                                      asPlaceholder: true,
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _exercises.add(
                                        _ExerciseDraft(
                                          id: id,
                                          name: name,
                                          category: category,
                                          sets: setData.drafts,
                                          history: setData.history,
                                        ),
                                      );
                                      _expandedExerciseId = id;
                                    });
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
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout updated')));
      context.go('/sessions/$editingId');
      return;
    }

    await LocalStore.instance.saveWorkout(userId: 1, name: 'Workout', sets: sets);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout saved')));

    setState(() {
      _choiceMade = false;
      _exercises.clear();
      _expandedExerciseId = null;
      _running = true;
    });
    _ticker.reset();
    _ticker.start();

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
  })  : sets = sets ?? [_SetDraft(), _SetDraft()],
        _history = _prepareHistory(history),
        _historyByOrdinal = <int, _SetHistoryEntry>{} {
    for (final entry in _history) {
      _historyByOrdinal[entry.ordinal] = entry;
    }
  }

  final int id;
  final String name;
  final String category;
  final List<_SetDraft> sets;
  final List<_SetHistoryEntry> _history;
  final Map<int, _SetHistoryEntry> _historyByOrdinal;

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
  }) {
    if (weight != null && weight.isNotEmpty) {
      this.weight.text = weight;
    }
    if (reps != null && reps.isNotEmpty) {
      this.reps.text = reps;
    }
  }

  final TextEditingController weight = TextEditingController();
  final TextEditingController reps = TextEditingController();
  final String? weightHint;
  final String? repsHint;
  bool done;
  final DateTime? originalTimestamp;
}

class _SetHistoryEntry {
  const _SetHistoryEntry({
    required this.ordinal,
    this.weightHint,
    this.repsHint,
  });

  final int ordinal;
  final String? weightHint;
  final String? repsHint;
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

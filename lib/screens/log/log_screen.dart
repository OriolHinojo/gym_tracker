import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/screens/library/library_screen.dart';
import 'package:gym_tracker/widgets/create_exercise_dialog.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key, this.templateId, this.workoutId});
  final int? templateId; // when repeating a template (passed via go_router extra)
  final String? workoutId; // optional deep link '/workout/:id'

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  Duration _elapsed = Duration.zero;
  late final Ticker _ticker;
  bool _running = true;

  final List<_ExerciseDraft> _exercises = [];
  int? _expandedExerciseId;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      // Always reflect what the stopwatch says; pausing is handled inside Ticker.
      if (mounted) setState(() => _elapsed = elapsed);
    })
      ..start(); // start running immediately

    _prefillFromTemplateIfAny();
  }

  Future<void> _prefillFromTemplateIfAny() async {
    if (widget.templateId == null) return;
    final tpl = await LocalStore.instance.getWorkoutTemplateRaw(widget.templateId!);
    if (tpl == null) return;
    final ids = ((tpl['exercise_ids'] ?? []) as List).map((e) => (e as num).toInt()).toList();
    final all = await LocalStore.instance.listExercisesRaw();

    _exercises.clear();
    for (final id in ids) {
      final ex = all.firstWhere(
        (e) => (e['id'] as num).toInt() == id,
        orElse: () => const {'name': 'Unknown', 'category': 'other'},
      );
      _exercises.add(_ExerciseDraft(
        id: id,
        name: (ex['name'] ?? 'Exercise').toString(),
        category: (ex['category'] ?? 'other').toString(),
      ));
    }
    if (_exercises.isNotEmpty) {
      setState(() => _expandedExerciseId = _exercises.first.id);
    }
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
                                return RadioListTile<int>(
                                  value: id,
                                  groupValue: selectedId,
                                  onChanged: (value) => setD(() => selectedId = value),
                                  title: Text(name),
                                  secondary: const Icon(Icons.fitness_center_outlined),
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
                                    setState(() {
                                      _exercises.add(_ExerciseDraft(id: id, name: name, category: category));
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
    for (final ex in _exercises) {
      int ord = 1;
      for (final s in ex.sets) {
        final weight = double.tryParse(s.weight.text.trim());
        final reps = int.tryParse(s.reps.text.trim());
        if (weight == null || reps == null || weight <= 0 || reps <= 0) continue;
        sets.add({
          'exercise_id': ex.id,
          'ordinal': ord++,
          'reps': reps,
          'weight': weight,
          'created_at': DateTime.now().toUtc(),
        });
      }
    }

    if (sets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to save')));
      }
      return;
    }

    await LocalStore.instance.saveWorkout(userId: 1, name: 'Workout', sets: sets);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout saved')));

    // Go back to the Log tab explicitly
    context.go('/log');
  }

  @override
  Widget build(BuildContext context) {
    final String time = _format(_elapsed);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: <Widget>[
          IconButton(onPressed: _saveAsTemplateFlow, icon: const Icon(Icons.save_outlined), tooltip: 'Save as template'),
          FilledButton(onPressed: _finishAndPersist, child: const Text('Finish')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Chip(label: Text('Timer: $time')),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _running = !_running;
                    if (_running) {
                      _ticker.start(); // resumes the stopwatch
                    } else {
                      _ticker.pause(); // stops the stopwatch (elapsed freezes)
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
          const SizedBox(height: 12),

          if (_exercises.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('No exercises yet'),
                subtitle: const Text('Add from Library or create on the fly'),
                trailing: FilledButton(onPressed: _addExerciseFlow, child: const Text('Add')),
              ),
            ),

          ..._exercises.map((ex) {
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
                                      decoration: const InputDecoration(labelText: 'Weight'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: s.reps,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Reps'),
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
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => ex.sets.add(_SetDraft())),
                              icon: const Icon(Icons.add),
                              label: const Text('Add set'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/* ---------------------------- Data in the screen ---------------------------- */

class _ExerciseDraft {
  _ExerciseDraft({required this.id, required this.name, required this.category});
  final int id;
  final String name;
  final String category;
  final List<_SetDraft> sets = [_SetDraft(), _SetDraft()];
}

class _SetDraft {
  final TextEditingController weight = TextEditingController();
  final TextEditingController reps = TextEditingController();
  bool done = false;
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

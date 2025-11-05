import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/screens/library/library_screen.dart';

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
      if (!_running) return;
      setState(() => _elapsed = elapsed);
    })..start();

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
    String? newName;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setD) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text('Add Exercise', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: ListView(
                    children: [
                      ...all.map((e) {
                        final id = (e['id'] as num).toInt();
                        final name = (e['name'] ?? '').toString();
                        return RadioListTile<int>(
                          value: id,
                          groupValue: selectedId,
                          onChanged: (v) => setD(() => selectedId = v),
                          title: Text(name),
                          secondary: const Icon(Icons.fitness_center_outlined),
                        );
                      }),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Create new exercise'),
                        subtitle: const Text('Add and select immediately'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'New exercise name'),
                          onChanged: (v) => newName = v.trim(),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        int id;
                        String name;
                        String category = 'other';
                        if (selectedId != null) {
                          id = selectedId!;
                          final ex = all.firstWhere((e) => (e['id'] as num).toInt() == id);
                          name = (ex['name'] ?? 'Exercise').toString();
                          category = (ex['category'] ?? 'other').toString();
                        } else {
                          if (newName == null || newName!.isEmpty) return;
                          id = await LocalStore.instance.createExercise(name: newName!, category: category);
                          name = newName!;
                        }
                        setState(() {
                          _exercises.add(_ExerciseDraft(id: id, name: name, category: category));
                          _expandedExerciseId = id;
                        });
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Add'),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
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
    // If you want to only save sets marked done, add `&& s.done` in the condition below.
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
                onPressed: () => setState(() => _running = !_running),
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
                          // CHANGED: when expanded, show SAVE icon instead of arrow; when collapsed, show edit
                          tooltip: expanded ? 'Save exercise' : 'Edit',
                          onPressed: () => setState(() {
                            if (expanded) {
                              // could validate here; for now just collapse
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
                                  // Checkbox = user marks the set as "done" (purely visual; not required to save)
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
  final List<_SetDraft> sets = [ _SetDraft(), _SetDraft() ];
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
  Duration _elapsed = Duration.zero;
  bool _running = false;
  void start() { _running = true; _tick(); }
  void dispose() { _running = false; }
  Future<void> _tick() async {
    final Stopwatch sw = Stopwatch()..start();
    while (_running) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      _elapsed = sw.elapsed;
      onTick(_elapsed);
    }
  }
}
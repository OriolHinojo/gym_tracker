import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Future<_WorkoutDetailVM> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WorkoutDetailVM> _load() async {
    final workout = await LocalStore.instance.getWorkoutRaw(widget.id);
    if (workout == null) {
      throw StateError('Workout not found');
    }

    final sets = await LocalStore.instance.listSetsForWorkoutRaw(widget.id);
    final exercises = await LocalStore.instance.listExercisesRaw();
    final exerciseMap = {
      for (final ex in exercises) (ex['id'] as num).toInt(): (ex['name'] ?? 'Exercise').toString(),
    };

    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final set in sets) {
      final exId = (set['exercise_id'] as num?)?.toInt();
      if (exId == null) continue;
      grouped.putIfAbsent(exId, () => <Map<String, dynamic>>[]).add(set);
    }

    final exerciseVms = grouped.entries.map((entry) {
      final exName = exerciseMap[entry.key] ?? 'Exercise';
      final setVms = entry.value.map((row) {
        final ordinal = (row['ordinal'] as num?)?.toInt() ?? 0;
        final reps = (row['reps'] as num?)?.toInt() ?? 0;
        final weight = (row['weight'] as num?)?.toDouble() ?? 0;
        return _WorkoutSetVM(ordinal: ordinal, reps: reps, weight: weight);
      }).toList()
        ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      return _WorkoutExerciseVM(name: exName, sets: setVms);
    }).toList();

    return _WorkoutDetailVM(
      id: (workout['id'] as num).toInt(),
      name: (workout['name'] ?? 'Workout').toString().isEmpty ? 'Workout' : (workout['name'] ?? 'Workout').toString(),
      startedAt: DateTime.tryParse((workout['started_at'] ?? '').toString()),
      notes: (workout['notes'] ?? '').toString(),
      exercises: exerciseVms,
    );
  }

  Future<void> _confirmDelete(int workoutId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('This will remove the workout and its sets permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    await LocalStore.instance.deleteWorkout(workoutId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout deleted')));
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Session'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete workout',
            onPressed: () async {
              try {
                final vm = await _future;
                if (!mounted) return;
                await _confirmDelete(vm.id);
              } catch (_) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Workout not available')));
              }
            },
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<_WorkoutDetailVM>(
        future: _future,
        builder: (context, snapshot) {
          final vm = snapshot.data;
          if (vm == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => context.go('/log', extra: {'editWorkoutId': vm.id}),
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          );
        },
      ),
      body: FutureBuilder<_WorkoutDetailVM>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load workout.\n${snapshot.error}'));
          }

          final vm = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(vm: vm),
              const SizedBox(height: 16),
              if (vm.exercises.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No sets were logged for this session.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ...vm.exercises.map((ex) => _ExerciseCard(exercise: ex)),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.vm});

  final _WorkoutDetailVM vm;

  @override
  Widget build(BuildContext context) {
    final started = vm.startedAt?.toLocal();
    String subtitle = 'Started time unavailable';
    if (started != null) {
      String two(int n) => n.toString().padLeft(2, '0');
      subtitle = '${started.year}-${two(started.month)}-${two(started.day)} at ${two(started.hour)}:${two(started.minute)}';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vm.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            if (vm.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(vm.notes, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final _WorkoutExerciseVM exercise;

  String _formatWeight(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...exercise.sets.map((set) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  child: Text(set.ordinal.toString()),
                ),
                title: Text('${_formatWeight(set.weight)} kg'),
                trailing: Text('${set.reps} reps'),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _WorkoutDetailVM {
  _WorkoutDetailVM({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.notes,
    required this.exercises,
  });

  final int id;
  final String name;
  final DateTime? startedAt;
  final String notes;
  final List<_WorkoutExerciseVM> exercises;
}

class _WorkoutExerciseVM {
  _WorkoutExerciseVM({required this.name, required this.sets});

  final String name;
  final List<_WorkoutSetVM> sets;
}

class _WorkoutSetVM {
  _WorkoutSetVM({required this.ordinal, required this.reps, required this.weight});

  final int ordinal;
  final int reps;
  final double weight;
}

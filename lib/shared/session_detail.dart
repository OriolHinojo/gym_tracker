import 'package:gym_tracker/data/local/local_store.dart';

/// Represents a logged workout session with its exercises and sets.
class SessionDetail {
  const SessionDetail({
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
  final List<SessionExercise> exercises;
}

/// Exercise performed within a session.
class SessionExercise {
  const SessionExercise({required this.name, required this.sets});

  final String name;
  final List<SessionSet> sets;
}

/// Single set entry (weight/reps) of an exercise.
class SessionSet {
  const SessionSet({
    required this.ordinal,
    required this.reps,
    required this.weight,
  });

  final int ordinal;
  final int reps;
  final double weight;
}

/// Loads a full [SessionDetail] from the local store for the given workout id.
Future<SessionDetail> loadSessionDetail(int workoutId, {LocalStore? store}) async {
  final db = store ?? LocalStore.instance;
  final workout = await db.getWorkoutRaw(workoutId);
  if (workout == null) {
    throw StateError('Workout not found');
  }

  final sets = await db.listSetsForWorkoutRaw(workoutId);
  final exercises = await db.listExercisesRaw();
  final exerciseMap = <int, String>{
    for (final ex in exercises)
      if (ex['id'] != null)
        (ex['id'] as num).toInt(): (ex['name'] ?? 'Exercise').toString(),
  };

  final grouped = <int, List<Map<String, dynamic>>>{};
  for (final set in sets) {
    final exId = (set['exercise_id'] as num?)?.toInt();
    if (exId == null) continue;
    grouped.putIfAbsent(exId, () => <Map<String, dynamic>>[]).add(set);
  }

  final sessionExercises = grouped.entries.map((entry) {
    final exName = exerciseMap[entry.key] ?? 'Exercise';
    final setVms = entry.value.map((row) {
      final ordinal = (row['ordinal'] as num?)?.toInt() ?? 0;
      final reps = (row['reps'] as num?)?.toInt() ?? 0;
      final weight = (row['weight'] as num?)?.toDouble() ?? 0;
      return SessionSet(ordinal: ordinal, reps: reps, weight: weight);
    }).toList()
      ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return SessionExercise(name: exName, sets: setVms);
  }).toList();

  return SessionDetail(
    id: (workout['id'] as num).toInt(),
    name: (() {
      final rawName = (workout['name'] ?? 'Workout').toString();
      return rawName.trim().isEmpty ? 'Workout' : rawName;
    })(),
    startedAt: DateTime.tryParse((workout['started_at'] ?? '').toString()),
    notes: (workout['notes'] ?? '').toString(),
    exercises: sessionExercises,
  );
}

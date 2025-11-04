import 'dart:async';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../contracts/repos.dart';

class MockSeeder {
  MockSeeder(this._seedDate);
  final DateTime _seedDate;

  List<Exercise> seedExercises() {
    return <Exercise>[
      Exercise(
        id: 'ex-bench',
        name: 'Bench Press',
        equipment: Equipment.barbell,
        primaryMuscles: const <String>['Chest'],
        variationTags: const <String>['flat'],
        createdAt: _seedDate,
        updatedAt: _seedDate,
      ),
      Exercise(
        id: 'ex-squat',
        name: 'Back Squat',
        equipment: Equipment.barbell,
        primaryMuscles: const <String>['Quads'],
        variationTags: const <String>['high-bar'],
        createdAt: _seedDate,
        updatedAt: _seedDate,
      ),
    ];
  }
}

class InMemoryExerciseRepo implements ExerciseRepo {
  InMemoryExerciseRepo(List<Exercise> initial) {
    _exercises = List<Exercise>.from(initial);
    _controller.add(_exercises);
  }
  late List<Exercise> _exercises;
  final StreamController<List<Exercise>> _controller = StreamController<List<Exercise>>.broadcast();

  @override
  Future<void> add(Exercise exercise) async {
    _exercises.add(exercise);
    _controller.add(List<Exercise>.unmodifiable(_exercises));
  }

  @override
  Future<List<Exercise>> getAll() async => List<Exercise>.unmodifiable(_exercises);

  @override
  Future<Exercise?> getById(String id) async {
    for (final Exercise e in _exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Stream<List<Exercise>> watchAll() => _controller.stream;
}

class InMemoryWorkoutRepo implements WorkoutRepo {
  InMemoryWorkoutRepo() {
    _controller.add(_workouts);
  }
  final List<Workout> _workouts = <Workout>[];
  final StreamController<List<Workout>> _controller = StreamController<List<Workout>>.broadcast();

  @override
  Future<Workout> createDraft() async {
    final Workout w = Workout(id: 'w-${DateTime.now().millisecondsSinceEpoch}', startedAt: DateTime.now());
    _workouts.add(w);
    _controller.add(List<Workout>.unmodifiable(_workouts));
    return w;
  }

  @override
  Future<Workout?> getById(String id) async {
    for (final Workout w in _workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Stream<List<Workout>> watchAll() => _controller.stream;
}



import '../../models/models.dart';

abstract class ExerciseRepo {
  Stream<List<Exercise>> watchAll();
  Future<List<Exercise>> getAll();
  Future<Exercise?> getById(String id);
  Future<void> add(Exercise exercise);
}

abstract class WorkoutRepo {
  Stream<List<Workout>> watchAll();
  Future<Workout?> getById(String id);
  Future<Workout> createDraft();
}

abstract class SetRepo {
  Stream<List<SetEntry>> watchByExerciseInstance(String exerciseInstanceId);
  Future<void> add(SetEntry entry);
  Future<void> update(SetEntry entry);
  Future<void> remove(String id);
}

abstract class PRRepo {
  Stream<List<PRRecord>> watchByExercise(String exerciseId);
}

abstract class NextTargetRepo {
  Stream<List<NextTarget>> watchAll();
}



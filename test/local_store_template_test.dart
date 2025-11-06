import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/local/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStore template lineage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ironpulse_template_test_');
      await LocalStore.instance.resetForTests(deleteFile: true);
      LocalStore.instance.overrideAppDirectory(tempDir);
    });

    tearDown(() async {
      await LocalStore.instance.resetForTests(deleteFile: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveWorkout persists template id to workouts and sets', () async {
      final now = DateTime.now().toUtc();
      final workoutId = await LocalStore.instance.saveWorkout(
        userId: 1,
        name: 'Template Run',
        templateId: 42,
        startedAtUtc: now,
        sets: [
          {
            'exercise_id': 1,
            'ordinal': 1,
            'reps': 5,
            'weight': 100,
            'created_at': now,
            'tag': 'warm_up',
          },
        ],
      );

      final workout = await LocalStore.instance.getWorkoutRaw(workoutId);
      expect(workout?['template_id'], 42);

      final sets = await LocalStore.instance.listSetsForWorkoutRaw(workoutId);
      expect(sets, isNotEmpty);
      expect(sets.first['template_id'], 42);
      expect(sets.first['tag'], 'warm_up');
    });

    test('listLatestSetsForExerciseRaw prefers template-specific history', () async {
      final now = DateTime.now().toUtc();
      await LocalStore.instance.saveWorkout(
        userId: 1,
        name: 'Template One',
        templateId: 10,
        startedAtUtc: now.subtract(const Duration(days: 1)),
        sets: [
          {
            'exercise_id': 1,
            'ordinal': 1,
            'reps': 5,
            'weight': 80,
            'created_at': now.subtract(const Duration(days: 1)),
          },
        ],
      );

      await LocalStore.instance.saveWorkout(
        userId: 1,
        name: 'Template Two',
        templateId: 20,
        startedAtUtc: now.add(const Duration(hours: 1)),
        sets: [
          {
            'exercise_id': 1,
            'ordinal': 1,
            'reps': 5,
            'weight': 120,
            'created_at': now.add(const Duration(hours: 1)),
          },
        ],
      );

      final templateSpecific = await LocalStore.instance.listLatestSetsForExerciseRaw(
        1,
        templateId: 10,
      );
      expect(templateSpecific, isNotEmpty);
      expect(templateSpecific.first['weight'], 80);
      expect(templateSpecific.first['template_id'], 10);

      final fallback = await LocalStore.instance.listLatestSetsForExerciseRaw(
        1,
        templateId: 999,
      );
      expect(fallback, isNotEmpty);
      expect(fallback.first['weight'], 120);
      expect(fallback.first['template_id'], 20);
    });
  });
}

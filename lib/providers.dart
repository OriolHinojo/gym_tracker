import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/contracts/repos.dart';
import 'data/mocks/mock_repos.dart';
import 'models/models.dart';
import 'services/contracts/services.dart';
import 'services/mocks/mock_services.dart';

final Provider<ExerciseRepo> exerciseRepoProvider = Provider<ExerciseRepo>((ref) {
  final MockSeeder seeder = MockSeeder(DateTime(2025, 1, 1));
  return InMemoryExerciseRepo(seeder.seedExercises());
});

final Provider<WorkoutRepo> workoutRepoProvider = Provider<WorkoutRepo>((ref) => InMemoryWorkoutRepo());

final Provider<MetricsService> metricsServiceProvider = Provider<MetricsService>((ref) => MockMetricsService());

final Provider<SuggestionEngine> suggestionEngineProvider = Provider<SuggestionEngine>((ref) => MockSuggestionEngine());

// Convenience watches
final StreamProvider<List<Exercise>> exercisesStreamProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(exerciseRepoProvider).watchAll();
});



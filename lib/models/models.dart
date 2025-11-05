import 'enums.dart';

/// Data model classes
class Exercise {
  Exercise({
    required this.id,
    required this.name,
    required this.equipment,
    required this.primaryMuscles,
    required this.variationTags,
    this.notes,
    this.aggregationKey,
    this.progressionRule = ProgressionRule.simple,
    this.incrementStep = 2.5,
    this.microplates = const <double>[0.5, 1.25, 2.5],
    required this.createdAt,
    required this.updatedAt,
  });
  /// Unique identifier
  final String id;
  /// Exercise name
  final String name;
  /// Equipment type
  final Equipment equipment;
  /// Primary muscle groups
  final List<String> primaryMuscles;
  /// Variation tags
  final List<String> variationTags;
  /// Optional notes
  final String? notes;
  /// Optional aggregation key for grouping similar exercises
  final String? aggregationKey;
  /// Progression rule
  final ProgressionRule progressionRule;
  /// Increment step for weight progression
  final double incrementStep;
  /// Available microplates for weight adjustments
  final List<double> microplates;
  /// Creation timestamp
  final DateTime createdAt;
  /// Last updated timestamp
  final DateTime updatedAt;
}

/// Workout data model
class Workout {
  /// Workout session
  Workout({required this.id, required this.startedAt, this.finishedAt, this.name, this.notes});
  /// Unique identifier
  final String id;
  /// Start time
  final DateTime startedAt;
  /// Finish time
  final DateTime? finishedAt;
  /// Optional name
  final String? name;
  /// Optional notes
  final String? notes;
}

/// Exercise instance within a workout
class ExerciseInstance {
  /// Exercise instance in a workout
  ExerciseInstance({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.orderIndex,
    this.restSecondsDefault,
  });
  /// Unique identifier
  final String id;
  /// Associated workout ID
  final String workoutId;
  /// Associated exercise ID
  final String exerciseId;
  /// Order index within the workout
  final int orderIndex;
  /// Default rest time in seconds
  final int? restSecondsDefault;
}

/// Set entry within an exercise instance
class SetEntry {
  /// Individual set entry
  SetEntry({
    required this.id,
    required this.exerciseInstanceId,
    required this.setIndex,
    required this.weight,
    required this.reps,
    this.rpe,
    this.rir,
    this.repTarget,
    this.hitTarget,
    this.feltFlag,
    this.isDropsetParent = false,
    this.parentSetId,
    this.tempo,
    this.completedAt,
    this.notes,
  });
  /// Unique identifier
  final String id;
  /// Associated exercise instance ID
  final String exerciseInstanceId;
  /// Set index within the exercise instance
  final int setIndex;
  /// Weight lifted
  final double weight;
  /// Number of repetitions
  final int reps;
  /// Rate of Perceived Exertion
  final double? rpe;
  /// Reps in Reserve
  final double? rir;
  /// Target repetitions
  final int? repTarget;
  /// Whether the target was hit
  final bool? hitTarget;
  /// Felt difficulty flag
  final FeltFlag? feltFlag;
  /// Whether this set is a dropset parent
  final bool isDropsetParent;
  /// Parent set ID for dropsets
  final String? parentSetId;
  /// Tempo string
  final String? tempo;
  /// Completion timestamp
  final DateTime? completedAt;
  /// Optional notes
  final String? notes;
}

/// Personal Record (PR) entry
class PRRecord {
  /// Personal Record entry
  PRRecord({
    required this.id,
    required this.exerciseId,
    required this.prType,
    this.repCount,
    required this.value,
    required this.atDate,
  });
  /// Unique identifier
  final String id;
  /// Associated exercise ID
  final String exerciseId;
  /// Type of PR
  final PRType prType;
  /// Optional repetition count for the PR
  final int? repCount;
  /// PR value (e.g., weight)
  final double value;
  /// Date when the PR was achieved
  final DateTime atDate;
}

/// Next Target suggestion for an exercise
class NextTarget {
  /// Suggested next target for an exercise
  NextTarget({
    required this.id,
    required this.exerciseId,
    required this.suggestedWeight,
    required this.suggestedReps,
    required this.reason,
    required this.createdAt,
  });
  /// Unique identifier
  final String id;
  /// Associated exercise ID
  final String exerciseId;
  /// Suggested weight for the next session
  final double suggestedWeight;
  /// Suggested repetitions for the next session
  final int suggestedReps;
  /// Reason for the suggestion
  final String reason;
  /// Creation timestamp
  final DateTime createdAt;
}
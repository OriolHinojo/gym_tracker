import 'enums.dart';

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
  final String id;
  final String name;
  final Equipment equipment;
  final List<String> primaryMuscles;
  final List<String> variationTags;
  final String? notes;
  final String? aggregationKey;
  final ProgressionRule progressionRule;
  final double incrementStep;
  final List<double> microplates;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Workout {
  Workout({required this.id, required this.startedAt, this.finishedAt, this.name, this.notes});
  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? name;
  final String? notes;
}

class ExerciseInstance {
  ExerciseInstance({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.orderIndex,
    this.restSecondsDefault,
  });
  final String id;
  final String workoutId;
  final String exerciseId;
  final int orderIndex;
  final int? restSecondsDefault;
}

class SetEntry {
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
  final String id;
  final String exerciseInstanceId;
  final int setIndex;
  final double weight;
  final int reps;
  final double? rpe;
  final double? rir;
  final int? repTarget;
  final bool? hitTarget;
  final FeltFlag? feltFlag;
  final bool isDropsetParent;
  final String? parentSetId;
  final String? tempo;
  final DateTime? completedAt;
  final String? notes;
}

class PRRecord {
  PRRecord({
    required this.id,
    required this.exerciseId,
    required this.prType,
    this.repCount,
    required this.value,
    required this.atDate,
  });
  final String id;
  final String exerciseId;
  final PRType prType;
  final int? repCount;
  final double value;
  final DateTime atDate;
}

class NextTarget {
  NextTarget({
    required this.id,
    required this.exerciseId,
    required this.suggestedWeight,
    required this.suggestedReps,
    required this.reason,
    required this.createdAt,
  });
  final String id;
  final String exerciseId;
  final double suggestedWeight;
  final int suggestedReps;
  final String reason;
  final DateTime createdAt;
}



import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/services/analytics/analytics_models.dart';
import 'package:gym_tracker/shared/set_tags.dart';

class AnalyticsService {
  AnalyticsService({LocalStore? store}) : _store = store ?? LocalStore.instance;

  final LocalStore _store;

  Future<AnalyticsSnapshot> snapshot({
    AnalyticsFilters? filters,
    int personalRecordLimit = 5,
  }) async {
    final resolvedFilters = filters ?? const AnalyticsFilters();
    final workoutsRaw = await _store.listWorkoutsRaw();
    if (workoutsRaw.isEmpty) return AnalyticsSnapshot.empty;

    final exercisesRaw = await _store.listExercisesRaw();
    final exerciseNameById = <int, String>{
      for (final row in exercisesRaw)
        if (row['id'] != null)
          (row['id'] as num).toInt(): (row['name'] ?? 'Exercise').toString(),
    };

    final setsRaw = await _store.listAllSetsRaw();
    final setsByWorkout = <int, List<Map<String, dynamic>>>{};
    for (final set in setsRaw) {
      final wid = (set['workout_id'] as num?)?.toInt();
      if (wid == null) continue;
      setsByWorkout.putIfAbsent(wid, () => <Map<String, dynamic>>[]).add(set);
    }

    final List<_WorkoutAggregate> aggregates = [];
    final Map<int, _PersonalRecordCandidate> prCandidates = {};
    final Map<DateTime, double> trendVolume = {};
    final Map<TimeOfDayBucket, double> volumeByTime = {
      for (final bucket in TimeOfDayBucket.values) bucket: 0,
    };

    final DateTime? from = resolvedFilters.from?.toUtc();
    final DateTime? to = resolvedFilters.to?.toUtc();
    final Set<int>? templateFilters = resolvedFilters.templateIds;
    final Set<int>? exerciseFilters = resolvedFilters.exerciseIds;
    final Set<SetTag>? tagFilters = resolvedFilters.tags;
    final Set<TimeOfDayBucket>? timeFilters = resolvedFilters.timeOfDayBuckets;

    for (final workout in workoutsRaw) {
      final wid = (workout['id'] as num?)?.toInt();
      if (wid == null) continue;

      final startedAtRaw = workout['started_at'];
      final startedAtUtc = startedAtRaw == null ? null : DateTime.tryParse(startedAtRaw.toString())?.toUtc();
      if (startedAtUtc == null) continue;

      if (from != null && startedAtUtc.isBefore(from)) continue;
      if (to != null && startedAtUtc.isAfter(to)) continue;

      final templateId = (workout['template_id'] as num?)?.toInt();
      if (templateFilters != null && templateFilters.isNotEmpty && !templateFilters.contains(templateId)) {
        continue;
      }

      final localStart = startedAtUtc.toLocal();
      final bucket = TimeOfDayBucketX.classify(localStart);
      if (timeFilters != null && timeFilters.isNotEmpty && !timeFilters.contains(bucket)) continue;

      final setsForWorkout = setsByWorkout[wid] ?? const <Map<String, dynamic>>[];
      double sessionVolume = 0;
      bool matchedSet = false;

      for (final rawSet in setsForWorkout) {
        final exerciseId = (rawSet['exercise_id'] as num?)?.toInt();
        if (exerciseId == null) continue;
        if (exerciseFilters != null && exerciseFilters.isNotEmpty && !exerciseFilters.contains(exerciseId)) {
          continue;
        }

        final tag = setTagFromStorage(rawSet['tag']?.toString());
        if (tagFilters != null && tagFilters.isNotEmpty && !tagFilters.contains(tag)) {
          continue;
        }

        final weight = (rawSet['weight'] as num?)?.toDouble();
        final reps = (rawSet['reps'] as num?)?.toInt();
        if (weight == null || reps == null) continue;
        final volume = weight * reps;
        sessionVolume += volume;
        matchedSet = true;

        final createdRaw = rawSet['created_at'];
        final createdAtUtc = createdRaw == null ? startedAtUtc : DateTime.tryParse(createdRaw.toString())?.toUtc() ?? startedAtUtc;

        final estimatedOneRm = _estimateOneRm(weight, reps);
        final current = prCandidates[exerciseId];
        if (current == null || estimatedOneRm > current.estimatedOneRm) {
          prCandidates[exerciseId] = _PersonalRecordCandidate(
            exerciseId: exerciseId,
            weight: weight,
            reps: reps,
            estimatedOneRm: estimatedOneRm,
            achievedAt: createdAtUtc.toLocal(),
          );
        }
      }

      if (!matchedSet && !resolvedFilters.includeZeroVolumeSessions) {
        continue;
      }

      aggregates.add(
        _WorkoutAggregate(
          workoutId: wid,
          startedAt: localStart,
          volume: sessionVolume,
          templateId: templateId,
        ),
      );

      volumeByTime[bucket] = (volumeByTime[bucket] ?? 0) + sessionVolume;

      final trendKey = DateUtils.dateOnly(localStart);
      trendVolume[trendKey] = (trendVolume[trendKey] ?? 0) + sessionVolume;
    }

    if (aggregates.isEmpty) return AnalyticsSnapshot.empty;

    final totalVolume = aggregates.fold<double>(0, (sum, agg) => sum + agg.volume);
    final averageVolume = totalVolume / aggregates.length;

    final timeVolumes = volumeByTime.entries
        .where((entry) => entry.value > 0)
        .map((entry) => TimeOfDayVolume(bucket: entry.key, volume: entry.value))
        .toList();

    final trendPoints = trendVolume.entries
        .map((entry) => TrendPoint(periodStart: entry.key, value: entry.value))
        .toList()
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));

    final personalRecords = prCandidates.values
        .map((candidate) => PersonalRecord(
              exerciseId: candidate.exerciseId,
              exerciseName: exerciseNameById[candidate.exerciseId] ?? 'Exercise',
              weight: candidate.weight,
              reps: candidate.reps,
              estimatedOneRm: candidate.estimatedOneRm,
              achievedAt: candidate.achievedAt,
            ))
        .toList()
        .sortedByOneRm(take: personalRecordLimit);

    return AnalyticsSnapshot(
      sessionCount: aggregates.length,
      totalVolume: totalVolume,
      averageVolumePerSession: averageVolume,
      volumeByTimeOfDay: timeVolumes,
      volumeTrend: trendPoints,
      personalRecords: personalRecords,
    );
  }

  double _estimateOneRm(double weight, int reps) {
    if (reps <= 1) return weight;
    // Epley formula.
    return weight * (1 + reps / 30);
  }
}

class _WorkoutAggregate {
  _WorkoutAggregate({
    required this.workoutId,
    required this.startedAt,
    required this.volume,
    required this.templateId,
  });

  final int workoutId;
  final DateTime startedAt;
  final double volume;
  final int? templateId;
}

class _PersonalRecordCandidate {
  _PersonalRecordCandidate({
    required this.exerciseId,
    required this.weight,
    required this.reps,
    required this.estimatedOneRm,
    required this.achievedAt,
  });

  final int exerciseId;
  final double weight;
  final int reps;
  final double estimatedOneRm;
  final DateTime achievedAt;
}


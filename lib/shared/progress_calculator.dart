import 'progress_types.dart';

/// Helper responsible for turning raw database rows into chart-friendly points.
///
/// Keeping the aggregation logic in one place ensures that the Progress screen
/// and the exercise detail view always display matching numbers.
class ProgressCalculator {
  const ProgressCalculator();

  /// Compute a series of [ProgressPoint] items for the given raw sets.
  ///
  /// Only sets with a positive weight and repetition count are considered.
  /// When [mode] is [ProgressAggMode.avgPerSession], the returned point weight
  /// represents the average weight lifted across the workout, and repetitions
  /// indicate the heaviest set that day. For specific set modes we pick the
  /// requested ordinal (falling back to the first set when missing).
  List<ProgressPoint> buildSeries(
    List<Map<String, dynamic>> rawSets, {
    required ProgressAggMode mode,
    required ProgressRange range,
    required ProgressMetric metric,
  }) {
    if (rawSets.isEmpty) return const [];

    final parsed = rawSets
        .map(_parseSet)
        .where((set) => set.weight > 0 && set.reps > 0)
        .toList();
    if (parsed.isEmpty) return const [];

    final now = DateTime.now().toUtc();
    final start = range.startDateFrom(now);
    final filtered = start == null
        ? parsed
        : parsed.where((s) => !s.createdAt.isBefore(start)).toList();
    if (filtered.isEmpty) return const [];

    final byWorkout = <int, List<ProgressSet>>{};
    for (final set in filtered) {
      byWorkout.putIfAbsent(set.workoutId, () => []).add(set);
    }

    final points = switch (mode) {
      ProgressAggMode.avgPerSession => _buildAveragePerSessionPoints(byWorkout.values, metric),
      ProgressAggMode.set1 => _buildOrdinalPoints(byWorkout.values, metric, 1),
      ProgressAggMode.set2 => _buildOrdinalPoints(byWorkout.values, metric, 2),
      ProgressAggMode.set3 => _buildOrdinalPoints(byWorkout.values, metric, 3),
    };

    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  ProgressSet _parseSet(Map<String, dynamic> raw) {
    final createdRaw = raw['created_at'] ?? raw['started_at'];
    final createdAt = DateTime.parse(createdRaw.toString()).toUtc();
    return ProgressSet(
      workoutId: (raw['workout_id'] as num?)?.toInt() ?? -1,
      createdAt: createdAt,
      weight: (raw['weight'] as num?)?.toDouble() ?? 0,
      reps: (raw['reps'] as num?)?.toInt() ?? 0,
      ordinal: (raw['ordinal'] as num?)?.toInt() ?? 0,
    );
  }

  List<ProgressPoint> _buildAveragePerSessionPoints(
    Iterable<List<ProgressSet>> grouped,
    ProgressMetric metric,
  ) {
    return grouped.map((sets) {
      final latest = sets
          .map((s) => s.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      switch (metric) {
        case ProgressMetric.weight:
          final totalWeight = sets.fold<double>(0.0, (prev, set) => prev + set.weight);
          final totalReps = sets.fold<int>(0, (prev, set) => prev + set.reps);
          final double avgWeight = sets.isEmpty ? 0.0 : totalWeight / sets.length;
          final double avgReps = sets.isEmpty ? 0.0 : totalReps / sets.length;

          return ProgressPoint(
            date: latest,
            valueKg: avgWeight,
            reps: avgReps.round(),
            label: avgWeight.toStringAsFixed(1),
          );
        case ProgressMetric.estimatedOneRm:
          final best = sets.fold<ProgressSet?>(null, (prev, set) {
            if (prev == null) return set;
            return _estimateOneRm(set.weight, set.reps) > _estimateOneRm(prev.weight, prev.reps)
                ? set
                : prev;
          });
          final bestSet = best ?? sets.first;
          final estimate = _estimateOneRm(bestSet.weight, bestSet.reps);
          return ProgressPoint(
            date: latest,
            valueKg: estimate,
            reps: bestSet.reps,
            label: estimate.toStringAsFixed(1),
          );
      }
    }).toList();
  }

  List<ProgressPoint> _buildOrdinalPoints(
    Iterable<List<ProgressSet>> grouped,
    ProgressMetric metric,
    int targetOrdinal,
  ) {
    return grouped.map((sets) {
      sets.sort((a, b) => a.ordinal.compareTo(b.ordinal));
      final selected = sets.firstWhere(
        (s) => s.ordinal == targetOrdinal,
        orElse: () => sets.first,
      );
      switch (metric) {
        case ProgressMetric.weight:
          return ProgressPoint(
            date: selected.createdAt,
            valueKg: selected.weight,
            reps: selected.reps,
            label: selected.weight.toStringAsFixed(1),
          );
        case ProgressMetric.estimatedOneRm:
          final estimate = _estimateOneRm(selected.weight, selected.reps);
          return ProgressPoint(
            date: selected.createdAt,
            valueKg: estimate,
            reps: selected.reps,
            label: estimate.toStringAsFixed(1),
          );
      }
    }).toList();
  }

  double _estimateOneRm(double weight, int reps) {
    if (reps <= 1) return weight;
    return weight * (1 + reps / 30);
  }
}

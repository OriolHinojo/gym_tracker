import 'package:gym_tracker/shared/set_tags.dart';

enum TimeOfDayBucket { morning, midday, evening, late }

extension TimeOfDayBucketX on TimeOfDayBucket {
  String get label {
    switch (this) {
      case TimeOfDayBucket.morning:
        return 'Morning';
      case TimeOfDayBucket.midday:
        return 'Midday';
      case TimeOfDayBucket.evening:
        return 'Evening';
      case TimeOfDayBucket.late:
        return 'Late night';
    }
  }

  bool contains(DateTime dt) {
    final hour = dt.hour;
    switch (this) {
      case TimeOfDayBucket.morning:
        return hour >= 4 && hour < 11;
      case TimeOfDayBucket.midday:
        return hour >= 11 && hour < 16;
      case TimeOfDayBucket.evening:
        return hour >= 16 && hour < 21;
      case TimeOfDayBucket.late:
        return hour >= 21 || hour < 4;
    }
  }

  static TimeOfDayBucket classify(DateTime dt) {
    return TimeOfDayBucket.values.firstWhere(
      (bucket) => bucket.contains(dt),
      orElse: () => TimeOfDayBucket.midday,
    );
  }
}

class AnalyticsFilters {
  const AnalyticsFilters({
    this.from,
    this.to,
    this.templateIds,
    this.exerciseIds,
    this.tags,
    this.timeOfDayBuckets,
    this.includeZeroVolumeSessions = false,
  });

  final DateTime? from;
  final DateTime? to;
  final Set<int>? templateIds;
  final Set<int>? exerciseIds;
  final Set<SetTag>? tags;
  final Set<TimeOfDayBucket>? timeOfDayBuckets;
  final bool includeZeroVolumeSessions;

  bool get hasFilters =>
      (from != null) ||
      (to != null) ||
      (templateIds?.isNotEmpty ?? false) ||
      (exerciseIds?.isNotEmpty ?? false) ||
      (tags?.isNotEmpty ?? false) ||
      (timeOfDayBuckets?.isNotEmpty ?? false);
}

class TrendPoint {
  const TrendPoint({required this.periodStart, required this.value});
  final DateTime periodStart;
  final double value;
}

class TimeOfDayVolume {
  const TimeOfDayVolume({required this.bucket, required this.volume});
  final TimeOfDayBucket bucket;
  final double volume;
}

class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.estimatedOneRm,
    required this.achievedAt,
  });

  final int exerciseId;
  final String exerciseName;
  final double weight;
  final int reps;
  final double estimatedOneRm;
  final DateTime achievedAt;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.sessionCount,
    required this.totalVolume,
    required this.averageVolumePerSession,
    required this.volumeByTimeOfDay,
    required this.volumeTrend,
    required this.personalRecords,
  });

  final int sessionCount;
  final double totalVolume;
  final double averageVolumePerSession;
  final List<TimeOfDayVolume> volumeByTimeOfDay;
  final List<TrendPoint> volumeTrend;
  final List<PersonalRecord> personalRecords;

  static const AnalyticsSnapshot empty = AnalyticsSnapshot(
    sessionCount: 0,
    totalVolume: 0,
    averageVolumePerSession: 0,
    volumeByTimeOfDay: <TimeOfDayVolume>[],
    volumeTrend: <TrendPoint>[],
    personalRecords: <PersonalRecord>[],
  );
}

List<TrendPoint> sortTrendPointsByDate(Iterable<TrendPoint> points) {
  final sorted = points.toList()
    ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
  return sorted;
}

extension IterablePersonalRecordX on Iterable<PersonalRecord> {
  List<PersonalRecord> sortedByOneRm({int? take}) {
    final sorted = toList()
      ..sort((a, b) => b.estimatedOneRm.compareTo(a.estimatedOneRm));
    if (take != null && take < sorted.length) {
      return sorted.take(take).toList(growable: false);
    }
    return sorted;
  }
}

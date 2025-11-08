/// Shared types used to describe progress analytics across multiple screens.
///
/// Centralising these models and enums keeps the Progress and Library screens
/// consistent and reduces the chance of subtle behavioural drift.
enum ProgressAggMode { avgPerSession, set1, set2, set3 }

extension ProgressAggModeLabels on ProgressAggMode {
  /// Long label suited for helper text.
  String get label => switch (this) {
        ProgressAggMode.avgPerSession => 'Avg per session',
        ProgressAggMode.set1 => '1st set',
        ProgressAggMode.set2 => '2nd set',
        ProgressAggMode.set3 => '3rd set',
      };

  /// Short label suited for chips.
  String get short => switch (this) {
        ProgressAggMode.avgPerSession => 'Avg',
        ProgressAggMode.set1 => 'Set 1',
        ProgressAggMode.set2 => 'Set 2',
        ProgressAggMode.set3 => 'Set 3',
      };
}

/// Time window used when aggregating workout data.
enum ProgressRange { w4, w8, w12, all }

extension ProgressRangeLabels on ProgressRange {
  /// Compact label for filter chips.
  String get label => switch (this) {
        ProgressRange.w4 => '4w',
        ProgressRange.w8 => '8w',
        ProgressRange.w12 => '12w',
        ProgressRange.all => 'All',
      };

  /// Inclusive starting point (in UTC) for the time window, or `null` for all time.
  DateTime? startDateFrom(DateTime reference) => switch (this) {
        ProgressRange.w4 => reference.subtract(const Duration(days: 28)),
        ProgressRange.w8 => reference.subtract(const Duration(days: 56)),
        ProgressRange.w12 => reference.subtract(const Duration(days: 84)),
        ProgressRange.all => null,
      };
}

/// Metric that can be plotted in the progress charts.
enum ProgressMetric { weight, estimatedOneRm }

extension ProgressMetricLabels on ProgressMetric {
  String get label => switch (this) {
        ProgressMetric.weight => 'Weight',
        ProgressMetric.estimatedOneRm => 'Est. 1RM',
      };

  String get subtitle => switch (this) {
        ProgressMetric.weight => 'Average / selected set weight',
        ProgressMetric.estimatedOneRm => 'Epley-based estimate',
      };

  String get chipLabel => switch (this) {
        ProgressMetric.weight => 'Weight',
        ProgressMetric.estimatedOneRm => 'e1RM',
      };
}

/// Normalised set information parsed from the local store.
class ProgressSet {
  ProgressSet({
    required this.workoutId,
    required this.createdAt,
    required this.weight,
    required this.reps,
    required this.ordinal,
  });

  final int workoutId;
  final DateTime createdAt;
  final double weight;
  final int reps;
  final int ordinal;
}

/// Aggregated data point used by charts and recaps.
class ProgressPoint {
  const ProgressPoint({
    required this.date,
    required this.valueKg,
    required this.reps,
    this.label,
  });

  final DateTime date;
  final double valueKg;
  final int reps;
  final String? label;
}

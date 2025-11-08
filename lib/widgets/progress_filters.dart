import 'package:flutter/material.dart';

import '../shared/progress_types.dart';

/// Shared control bar for selecting aggregation mode and date range.
///
/// Screens can pass extra [leading] widgets (e.g. exercise dropdowns) that will
/// appear before the filter chips.
class ProgressFilters extends StatelessWidget {
  const ProgressFilters({
    super.key,
    required this.mode,
    required this.range,
    required this.onModeChanged,
    required this.onRangeChanged,
    this.leading = const <Widget>[],
    this.metric,
    this.metricOptions = const <ProgressMetric>[],
    this.onMetricChanged,
  });

  final ProgressAggMode mode;
  final ProgressRange range;
  final ValueChanged<ProgressAggMode> onModeChanged;
  final ValueChanged<ProgressRange> onRangeChanged;
  final List<Widget> leading;
  final ProgressMetric? metric;
  final List<ProgressMetric> metricOptions;
  final ValueChanged<ProgressMetric>? onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final shouldShowMetric = metric != null &&
        onMetricChanged != null &&
        metricOptions.isNotEmpty;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ...leading,
        Wrap(
          spacing: 6,
          children: ProgressAggMode.values
              .map(
                (modeOption) => ChoiceChip(
                  label: Text(modeOption.short),
                  selected: modeOption == mode,
                  onSelected: (_) => onModeChanged(modeOption),
                ),
              )
              .toList(),
        ),
        if (shouldShowMetric)
          Wrap(
            spacing: 6,
            children: metricOptions
                .map(
                  (metricOption) => ChoiceChip(
                        label: Text(metricOption.chipLabel),
                        selected: metricOption == metric,
                        onSelected: (_) => onMetricChanged?.call(metricOption),
                      ),
                )
                .toList(),
          ),
        Wrap(
          spacing: 6,
          children: ProgressRange.values
              .map(
                (rangeOption) => ChoiceChip(
                  label: Text(rangeOption.label),
                  selected: rangeOption == range,
                  onSelected: (_) => onRangeChanged(rangeOption),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

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
  });

  final ProgressAggMode mode;
  final ProgressRange range;
  final ValueChanged<ProgressAggMode> onModeChanged;
  final ValueChanged<ProgressRange> onRangeChanged;
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
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


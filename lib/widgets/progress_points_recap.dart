import 'package:flutter/material.dart';

import '../shared/formatting.dart';
import '../shared/progress_types.dart';
import '../shared/weight_units.dart';

/// Reusable card summarising the raw progress datapoints in a simple list.
class ProgressPointsRecap extends StatelessWidget {
  const ProgressPointsRecap({super.key, required this.points, required this.weightUnit});

  final List<ProgressPoint> points;
  final WeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Card(child: ListTile(title: Text('No data in the selected range')));
    }
    return Card(
      child: Column(
        children: [
          const ListTile(
            title: Text('Data points'),
            subtitle: Text('Weight is primary; reps shown as secondary'),
          ),
          const Divider(height: 1),
          ...points.map((p) => _buildTile(p)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTile(ProgressPoint point) {
    final date = formatDateYmd(point.date.toLocal());
    return ListTile(
      dense: true,
      title: Text('$date - ${formatCompactWeight(point.yWeight, weightUnit)}'),
      trailing: Text('${point.reps} reps'),
    );
  }
}

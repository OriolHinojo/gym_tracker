import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/progress_types.dart';
import '../shared/weight_units.dart';

/// Simple line chart used to visualise progress data.
///
/// The painter is kept intentionally lightweight so it can be reused anywhere
/// a small sparkline-style chart is needed.
class ProgressLineChart extends StatelessWidget {
  const ProgressLineChart({
    super.key,
    required this.points,
    required this.weightUnit,
    required this.metric,
  });

  final List<ProgressPoint> points;
  final WeightUnit weightUnit;
  final ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: _ProgressLineChartPainter(
        points: points,
        colorScheme: theme.colorScheme,
        textColor: theme.colorScheme.onSurface,
        subtleTextColor: theme.colorScheme.onSurfaceVariant,
        weightUnit: weightUnit,
        metric: metric,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ProgressLineChartPainter extends CustomPainter {
  _ProgressLineChartPainter({
    required this.points,
    required this.colorScheme,
    required this.textColor,
    required this.subtleTextColor,
    required this.weightUnit,
    required this.metric,
  });

  final List<ProgressPoint> points;
  final ColorScheme colorScheme;
  final Color textColor;
  final Color subtleTextColor;
  final WeightUnit weightUnit;
  final ProgressMetric metric;

  @override
  void paint(Canvas canvas, Size size) {
    final paintAxis = Paint()
      ..color = colorScheme.outlineVariant.withOpacity(0.35)
      ..strokeWidth = 1;

    final paintLine = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.fill;

    final baseTextStyle = TextStyle(color: textColor, fontSize: 11);

    const leftPad = 36.0;
    const bottomPad = 40.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;

    canvas.drawLine(const Offset(leftPad, 0), Offset(leftPad, chartH), paintAxis);
    canvas.drawLine(Offset(leftPad, chartH), Offset(size.width, chartH), paintAxis);

    if (points.isEmpty) return;

    final convertedWeights = points
        .map((p) => weightUnit.fromKilograms(p.valueKg))
        .toList(growable: false);
    double minY = convertedWeights.reduce((a, b) => a < b ? a : b);
    double maxY = convertedWeights.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final yRange = (maxY - minY).clamp(1e-6, double.infinity);

    final weekCounts = <DateTime, int>{};
    for (final point in points) {
      final week = _weekStart(point.date);
      weekCounts[week] = (weekCounts[week] ?? 0) + 1;
    }

    final earliestWeek = weekCounts.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    final weekOffsets = <DateTime, int>{};
    final ordinalPerWeek = <DateTime, int>{};
    final positions = List<double>.filled(points.length, 0);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final week = _weekStart(point.date);
      final base = weekOffsets.putIfAbsent(
        week,
        () => week.difference(earliestWeek).inDays ~/ 7,
      ).toDouble();
      final ordinal = ordinalPerWeek[week] ?? 0;
      final total = weekCounts[week]!;

      double offset = 0;
      if (total > 1) {
        final fraction = total == 1 ? 0.0 : ordinal / (total - 1);
        offset = (fraction - 0.5) * 0.6; // spread within the week slot
      }

      positions[i] = base + offset;
      ordinalPerWeek[week] = ordinal + 1;
    }

    final minPos = positions.reduce(math.min);
    final maxPos = positions.reduce(math.max);
    final posRange = maxPos - minPos;
    final denom = posRange.abs() < 1e-6 ? 1.0 : posRange;
    final xPositions = List<double>.generate(
      points.length,
      (index) => leftPad + ((positions[index] - minPos) / denom) * chartW,
    );

    if (posRange.abs() < 1e-6 && points.length == 1) {
      xPositions[0] = leftPad + chartW / 2;
    }
    double yFor(double weight) => chartH - ((weight - minY) / yRange) * chartH;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final valueInUnit = convertedWeights[i];
      final x = xPositions[i];
      final y = yFor(valueInUnit);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paintLine);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final valueInUnit = convertedWeights[i];
      final x = xPositions[i];
      final y = yFor(valueInUnit);
      canvas.drawCircle(Offset(x, y), 3.5, paintDot);

      final weightStyle = baseTextStyle.copyWith(fontWeight: FontWeight.w600);
      final weightText = TextPainter(
        text: TextSpan(text: formatSetWeight(point.valueKg, weightUnit), style: weightStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      weightText.paint(canvas, Offset(x - weightText.width / 2, y - 18));

      if (metric == ProgressMetric.weight) {
        final repsText = TextPainter(
          text: TextSpan(
            text: '${point.reps}r',
            style: baseTextStyle.copyWith(fontSize: 10, color: subtleTextColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        repsText.paint(canvas, Offset(x - repsText.width / 2, y + 4));
      } else {
        final detailText = TextPainter(
          text: TextSpan(
            text: '${point.reps}r (est)',
            style: baseTextStyle.copyWith(fontSize: 10, color: subtleTextColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        detailText.paint(canvas, Offset(x - detailText.width / 2, y + 4));
      }

      final dateText = TextPainter(
        text: TextSpan(
          text: _formatDate(point.date),
          style: baseTextStyle.copyWith(fontSize: 10, color: subtleTextColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(x, chartH + dateText.height + 6);
      canvas.rotate(-math.pi / 4);
      dateText.paint(canvas, Offset(-dateText.width, 0));
      canvas.restore();
    }

    final ticks = [minY, (minY + maxY) / 2, maxY];
    for (final tick in ticks) {
      final y = yFor(tick);
      final label = TextPainter(
        text: TextSpan(
          text: formatSetWeight(weightUnit.toKilograms(tick), weightUnit),
          style: baseTextStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(leftPad - label.width - 6, y - label.height / 2));

      final guide = Paint()
        ..color = colorScheme.outlineVariant.withOpacity(0.2)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(leftPad + 1, y), Offset(size.width, y), guide);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressLineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.textColor != textColor ||
      oldDelegate.subtleTextColor != subtleTextColor ||
      oldDelegate.weightUnit != weightUnit ||
      oldDelegate.metric != metric;
}

DateTime _weekStart(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return local.subtract(Duration(days: local.weekday - 1));
}

String _formatDate(DateTime date) => '${date.month}/${date.day}';

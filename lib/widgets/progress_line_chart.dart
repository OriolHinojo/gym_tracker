import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/progress_types.dart';

/// Simple line chart used to visualise progress data.
///
/// The painter is kept intentionally lightweight so it can be reused anywhere
/// a small sparkline-style chart is needed.
class ProgressLineChart extends StatelessWidget {
  const ProgressLineChart({super.key, required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ProgressLineChartPainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _ProgressLineChartPainter extends CustomPainter {
  _ProgressLineChartPainter(this.points);

  final List<ProgressPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paintAxis = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = 1;

    final paintLine = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.fill;

    final tpStyle = const TextStyle(color: Color(0xFF333333), fontSize: 11);

    const leftPad = 36.0;
    const bottomPad = 40.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;

    canvas.drawLine(const Offset(leftPad, 0), Offset(leftPad, chartH), paintAxis);
    canvas.drawLine(Offset(leftPad, chartH), Offset(size.width, chartH), paintAxis);

    if (points.isEmpty) return;

    double minY = points.map((p) => p.yWeight).reduce((a, b) => a < b ? a : b);
    double maxY = points.map((p) => p.yWeight).reduce((a, b) => a > b ? a : b);
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
      final x = xPositions[i];
      final y = yFor(point.yWeight);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paintLine);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = xPositions[i];
      final y = yFor(point.yWeight);
      canvas.drawCircle(Offset(x, y), 3.5, paintDot);

      final weightText = TextPainter(
        text: TextSpan(text: point.yWeight.toStringAsFixed(0), style: tpStyle.copyWith(fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      weightText.paint(canvas, Offset(x - weightText.width / 2, y - 18));

      final repsText = TextPainter(
        text: TextSpan(text: '${point.reps}r', style: tpStyle.copyWith(fontSize: 10, color: const Color(0xFF666666))),
        textDirection: TextDirection.ltr,
      )..layout();
      repsText.paint(canvas, Offset(x - repsText.width / 2, y + 4));

      final dateText = TextPainter(
        text: TextSpan(text: _formatDate(point.date), style: tpStyle.copyWith(fontSize: 10)),
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
        text: TextSpan(text: tick.toStringAsFixed(0), style: tpStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(leftPad - label.width - 6, y - label.height / 2));

      final guide = Paint()
        ..color = const Color(0xFFEFEFEF)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(leftPad + 1, y), Offset(size.width, y), guide);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressLineChartPainter oldDelegate) => oldDelegate.points != points;
}

DateTime _weekStart(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return local.subtract(Duration(days: local.weekday - 1));
}

String _formatDate(DateTime date) => '${date.month}/${date.day}';

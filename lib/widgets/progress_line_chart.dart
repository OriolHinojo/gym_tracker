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
    const bottomPad = 22.0;
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

    final minX = points.first.date.millisecondsSinceEpoch.toDouble();
    final maxX = points.last.date.millisecondsSinceEpoch.toDouble();
    final xRange = (maxX - minX).clamp(1, double.infinity);

    double xFor(DateTime d) => leftPad + ((d.millisecondsSinceEpoch - minX) / xRange) * chartW;
    double yFor(double weight) => chartH - ((weight - minY) / yRange) * chartH;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = xFor(point.date);
      final y = yFor(point.yWeight);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paintLine);

    for (final point in points) {
      final x = xFor(point.date);
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


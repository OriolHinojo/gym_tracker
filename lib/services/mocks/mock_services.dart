import 'dart:math';

import '../../models/models.dart';
import '../contracts/services.dart';

class MockMetricsService implements MetricsService {
  @override
  double estimateE1RM(double weight, int reps, {String formula = 'epley'}) {
    if (formula == 'brzycki') {
      return weight * 36 / (37 - reps);
    }
    return weight * (1 + reps / 30);
  }

  @override
  Future<List<Point>> e1rmTrend(String exerciseId, {Duration? range}) async {
    final DateTime now = DateTime.now();
    return List<Point>.generate(30, (i) => Point(now.subtract(Duration(days: 30 - i)), 100 + i.toDouble()));
  }

  @override
  Future<List<Point>> volumeTrend(String exerciseId, {Duration? range}) async {
    final DateTime now = DateTime.now();
    final Random r = Random(42);
    return List<Point>.generate(30, (i) => Point(now.subtract(Duration(days: 30 - i)), 1000 + r.nextInt(500).toDouble()));
  }
}

class MockSuggestionEngine implements SuggestionEngine {
  @override
  Future<NextTarget?> suggestNext(String exerciseId) async {
    return NextTarget(
      id: 'nt-$exerciseId',
      exerciseId: exerciseId,
      suggestedWeight: 2.5,
      suggestedReps: 0,
      reason: 'RIR 3, increase',
      createdAt: DateTime.now(),
    );
  }
}



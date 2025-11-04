import '../../models/models.dart';

abstract class MetricsService {
  double estimateE1RM(double weight, int reps, {String formula = 'epley'});
  Future<List<Point>> e1rmTrend(String exerciseId, {Duration? range});
  Future<List<Point>> volumeTrend(String exerciseId, {Duration? range});
}

class Point {
  Point(this.x, this.y);
  final DateTime x;
  final double y;
}

abstract class SuggestionEngine {
  Future<NextTarget?> suggestNext(String exerciseId);
}



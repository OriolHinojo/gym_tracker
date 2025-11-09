import 'package:flutter/foundation.dart';

/// Types of highlights that can appear on the home dashboard.
enum HomeHighlightType {
  /// Personal record achievements (e.g. new 5RM).
  pr,

  /// Positive trend in a tracked metric (e.g. e1RM moving up).
  trend,

  /// Consistency milestones such as weekly session counts.
  consistency,
}

/// Lightweight view model describing a highlight card row.
@immutable
class HomeHighlight {
  const HomeHighlight({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });

  /// Semantic classification used for iconography and styling.
  final HomeHighlightType type;

  /// Primary message for the highlight row.
  final String title;

  /// Supporting detail shown under the title.
  final String subtitle;

  /// Timestamp indicating when the highlight was achieved.
  final DateTime createdAt;
}

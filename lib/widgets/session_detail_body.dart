import 'package:flutter/material.dart';
import 'package:gym_tracker/shared/session_detail.dart';
import 'package:gym_tracker/widgets/session_exercises.dart';
import 'package:gym_tracker/widgets/session_header.dart';

/// Shared scrollable body for session previews and detail screens.
class SessionDetailBody extends StatelessWidget {
  const SessionDetailBody({
    super.key,
    required this.detail,
    this.subtitleOverride,
    this.padding,
    this.controller,
    this.spacing = 16,
  });

  final SessionDetail detail;
  final String? subtitleOverride;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: padding ?? const EdgeInsets.all(16),
      children: [
        SessionHeaderCard(
          detail: detail,
          subtitleOverride: subtitleOverride,
        ),
        SizedBox(height: spacing),
        SessionExercisesList(exercises: detail.exercises),
      ],
    );
  }
}

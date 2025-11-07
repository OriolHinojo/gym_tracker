import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/widgets/workout_editor.dart';

/// Route wrapper that hosts the shared [WorkoutEditor].
class LogScreen extends StatelessWidget {
  const LogScreen({super.key, this.templateId, this.workoutId, this.editWorkoutId});

  final int? templateId;
  final String? workoutId;
  final int? editWorkoutId;

  @override
  Widget build(BuildContext context) {
    return WorkoutEditor(
      templateId: templateId,
      workoutId: workoutId,
      editWorkoutId: editWorkoutId,
      onSaved: (ctx, result) {
        if (result.isUpdate) {
          ctx.push('/sessions/${result.workoutId}');
        } else {
          ctx.go('/log');
        }
      },
      onDiscarded: (ctx) => ctx.go('/log'),
    );
  }
}

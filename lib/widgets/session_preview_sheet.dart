import 'package:flutter/material.dart';
import 'package:gym_tracker/shared/session_detail.dart';
import 'package:gym_tracker/widgets/session_exercises.dart';
import 'package:gym_tracker/widgets/session_header.dart';

/// Displays a modal bottom sheet with a session preview.
Future<void> showSessionPreviewSheet(
  BuildContext context, {
  required Future<SessionDetail> sessionFuture,
  String? title,
  String? subtitle,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.9,
      child: SessionPreviewSheet(
        sessionFuture: sessionFuture,
        title: title,
        subtitle: subtitle,
      ),
    ),
  );
}

class SessionPreviewSheet extends StatelessWidget {
  const SessionPreviewSheet({
    super.key,
    required this.sessionFuture,
    this.title,
    this.subtitle,
  });

  final Future<SessionDetail> sessionFuture;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<SessionDetail>(
          future: sessionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load session.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            final detail = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      fit: FlexFit.tight,
                      child: Text(
                        title ?? 'Session Preview',
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  fit: FlexFit.tight,
                  child: ListView(
                    children: [
                      SessionHeaderCard(
                        detail: detail,
                        subtitleOverride: subtitle,
                      ),
                      const SizedBox(height: 12),
                      SessionExercisesList(exercises: detail.exercises),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

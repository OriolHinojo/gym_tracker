import 'package:flutter/material.dart';
import 'package:gym_tracker/shared/session_detail.dart';
import 'package:gym_tracker/widgets/session_detail_body.dart';
import 'package:gym_tracker/widgets/session_primary_action_button.dart';

/// Displays a modal bottom sheet with a session preview.
Future<void> showSessionPreviewSheet(
  BuildContext context, {
  required Future<SessionDetail> sessionFuture,
  String? title,
  String? subtitle,
  SessionPreviewAction? primaryAction,
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
        primaryAction: primaryAction,
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
    this.primaryAction,
  });

  final Future<SessionDetail> sessionFuture;
  final String? title;
  final String? subtitle;
  final SessionPreviewAction? primaryAction;

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
            final action = primaryAction;
            final showAction = action != null
                ? (action.isVisible?.call(detail) ?? true)
                : false;
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: SessionDetailBody(
                          detail: detail,
                          subtitleOverride: subtitle,
                          padding: EdgeInsets.only(
                            bottom: showAction ? 96 : 0,
                          ),
                          spacing: 12,
                        ),
                      ),
                      if (showAction && action != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: SessionPrimaryActionButton(
                            label: action.label,
                            icon: action.icon,
                            heroTag: action.heroTag,
                            onPressed: () => action.onPressed(context, detail),
                          ),
                        ),
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

/// Describes the primary action available in a session preview sheet.
class SessionPreviewAction {
  const SessionPreviewAction({
    required this.label,
    required this.onPressed,
    this.icon = Icons.edit,
    this.heroTag,
    this.isVisible,
  });

  final String label;
  final void Function(BuildContext context, SessionDetail detail) onPressed;
  final IconData icon;
  final Object? heroTag;
  final bool Function(SessionDetail detail)? isVisible;
}

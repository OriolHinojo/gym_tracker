import 'package:flutter/material.dart';
import 'package:gym_tracker/shared/session_detail.dart';

/// Header card for a session preview/detail view.
class SessionHeaderCard extends StatelessWidget {
  const SessionHeaderCard({
    super.key,
    required this.detail,
    this.subtitleOverride,
  });

  final SessionDetail detail;
  final String? subtitleOverride;

  String _subtitle() {
    if (subtitleOverride != null) return subtitleOverride!;
    final started = detail.startedAt?.toLocal();
    if (started == null) return 'Started time unavailable';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${started.year}-${two(started.month)}-${two(started.day)} at ${two(started.hour)}:${two(started.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final notes = detail.notes.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_subtitle(), style: Theme.of(context).textTheme.bodySmall),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(notes, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

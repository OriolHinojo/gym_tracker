import 'package:flutter/material.dart';
import 'package:gym_tracker/shared/formatting.dart';
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
    return formatMaybeDateTime(
      detail.startedAt?.toLocal(),
      fallback: 'Started time unavailable',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final onContainer = scheme.onPrimaryContainer;
    final exercisesCount = detail.exercises.length;
    final totalSets = detail.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    final notes = detail.notes.trim();

    Widget buildMetaChip(IconData icon, String label) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: onContainer.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: onContainer),
              const SizedBox(width: 6),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: onContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -12,
            child: Icon(
              Icons.fiber_manual_record_rounded,
              size: 72,
              color: onContainer.withOpacity(0.04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withOpacity(0.12),
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.name,
                            style: textTheme.titleLarge?.copyWith(
                              color: onContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: onContainer.withOpacity(0.8),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _subtitle(),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: onContainer.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    buildMetaChip(
                      Icons.lan_outlined,
                      exercisesCount == 1
                          ? '1 exercise'
                          : '$exercisesCount exercises',
                    ),
                    if (totalSets > 0)
                      buildMetaChip(
                        Icons.format_list_numbered_rounded,
                        totalSets == 1 ? '1 set' : '$totalSets sets',
                      ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    notes,
                    style: textTheme.bodyMedium?.copyWith(
                      color: onContainer.withOpacity(0.88),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

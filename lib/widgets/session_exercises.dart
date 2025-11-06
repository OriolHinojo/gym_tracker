import 'package:flutter/material.dart';
import 'package:gym_tracker/shared/session_detail.dart';
import 'package:gym_tracker/shared/set_tags.dart';

/// Renders a list of session exercises, each expandable to reveal sets.
class SessionExercisesList extends StatelessWidget {
  const SessionExercisesList({
    super.key,
    required this.exercises,
    this.initiallyExpanded = false,
  });

  final List<SessionExercise> exercises;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No sets were logged for this session.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < exercises.length; i++) ...[
          SessionExerciseCard(
            exercise: exercises[i],
            initiallyExpanded: initiallyExpanded,
          ),
          if (i != exercises.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class SessionExerciseCard extends StatefulWidget {
  const SessionExerciseCard({
    super.key,
    required this.exercise,
    this.initiallyExpanded = false,
  });

  final SessionExercise exercise;
  final bool initiallyExpanded;

  @override
  State<SessionExerciseCard> createState() => _SessionExerciseCardState();
}

class _SessionExerciseCardState extends State<SessionExerciseCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant SessionExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.exercise, oldWidget.exercise)) {
      _expanded = widget.initiallyExpanded;
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  String _formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  SessionSet? get _heaviestSet {
    if (widget.exercise.sets.isEmpty) return null;
    SessionSet? max;
    for (final set in widget.exercise.sets) {
      if (max == null ||
          set.weight > max.weight ||
          (set.weight == max.weight && set.reps > max.reps)) {
        max = set;
      }
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final sets = widget.exercise.sets;
    final totalReps = sets.fold<int>(0, (sum, s) => sum + s.reps);
    final heaviest = _heaviestSet;
    final outline = Theme.of(context).colorScheme.outline;
    final textTheme = Theme.of(context).textTheme;
    final summaryStyle = textTheme.bodySmall?.copyWith(color: outline);
    final setValueStyle = textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final setTrailingStyle = textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final ordinalStyle = textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.exercise.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sets: ${sets.length}${totalReps > 0 ? ' · Reps: $totalReps' : ''}',
                style: summaryStyle,
              ),
              if (heaviest != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Top set: ${_formatWeight(heaviest.weight)} kg x ${heaviest.reps}',
                  style: summaryStyle,
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: !_expanded
                    ? const SizedBox.shrink()
                    : sets.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No sets recorded for this exercise.',
                                style: summaryStyle,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              const SizedBox(height: 12),
                              for (var i = 0; i < sets.length; i++) ...[
                                Builder(builder: (context) {
                                  final tag = sets[i].tag;
                                  final tagLabel = setTagLabelFromStorage(tag);
                                  final subtitleStyle = Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(color: outline);
                                  return ListTile(
                                    dense: false,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 18,
                                      child: Text(
                                        sets[i].ordinal.toString(),
                                        style: ordinalStyle,
                                      ),
                                    ),
                                    title: Text(
                                      '${_formatWeight(sets[i].weight)} kg',
                                      style: setValueStyle,
                                    ),
                                    subtitle: tagLabel == null
                                        ? null
                                        : Text(tagLabel, style: subtitleStyle),
                                    trailing: Text(
                                      '${sets[i].reps} reps',
                                      style: setTrailingStyle,
                                    ),
                                  );
                                }),
                                if (i != sets.length - 1) const Divider(height: 1),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

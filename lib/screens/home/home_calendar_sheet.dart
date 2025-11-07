import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/shared/exercise_category_icons.dart' as exercise_icons;
import 'package:gym_tracker/shared/formatting.dart';
import 'package:gym_tracker/shared/session_detail.dart';
import 'package:gym_tracker/widgets/workout_editor.dart' show showWorkoutEditorPage;
import 'package:gym_tracker/widgets/session_preview_sheet.dart';

/// Simple summary of sessions grouped by day for the home calendar.
class CalendarDaySummary {
  CalendarDaySummary({required this.date, required this.sessions});

  /// Local date at midnight.
  final DateTime date;

  final List<CalendarSessionSummary> sessions;

  int get sessionCount => sessions.length;
}

/// Lightweight session view model for the calendar sheet.
class CalendarSessionSummary {
  CalendarSessionSummary({
    required this.id,
    required this.name,
    required this.startedAt,
    this.primaryCategory,
  });

  final int id;
  final String name;
  final DateTime startedAt;
  final String? primaryCategory;
}

class CalendarData {
  const CalendarData({
    required this.from,
    required this.to,
    required this.days,
  });

  final DateTime from;
  final DateTime to;
  final List<CalendarDaySummary> days;
}

Future<CalendarData> loadCalendarData({
  int userId = 1,
  LocalStore? store,
}) async {
  final db = store ?? LocalStore.instance;
  final workouts = await db.listWorkoutsRaw();
  final today = DateUtils.dateOnly(DateTime.now());
  if (workouts.isEmpty) {
    return CalendarData(from: today, to: today, days: const []);
  }

  final exercises = await db.listExercisesRaw();
  final exerciseCategoryById = <int, String>{
    for (final row in exercises)
      if (row['id'] != null)
        (row['id'] as num).toInt(): (row['category'] ?? 'other').toString(),
  };

  final sets = await db.listAllSetsRaw();
  final setsByWorkout = <int, List<Map<String, dynamic>>>{};
  for (final set in sets) {
    final wid = (set['workout_id'] as num?)?.toInt();
    if (wid == null) continue;
    setsByWorkout.putIfAbsent(wid, () => <Map<String, dynamic>>[]).add(set);
  }

  DateTime? earliestWorkout;
  for (final workout in workouts) {
    if ((workout['user_id'] as num?)?.toInt() != userId) continue;
    final startedAtRaw = (workout['started_at'] ?? '').toString();
    final startedAt = DateTime.tryParse(startedAtRaw)?.toLocal();
    if (startedAt == null) continue;
    final day = DateUtils.dateOnly(startedAt);
    earliestWorkout = earliestWorkout == null || day.isBefore(earliestWorkout!)
        ? day
        : earliestWorkout;
  }

  final fromDate = earliestWorkout ?? today;
  final toDate = today;
  final groupedByDay = <DateTime, List<CalendarSessionSummary>>{};

  for (final workout in workouts) {
    final user = (workout['user_id'] as num?)?.toInt();
    if (userId != user) continue;

    final idRaw = workout['id'] as num?;
    final startedAtRaw = (workout['started_at'] ?? '').toString();
    final startedAt = DateTime.tryParse(startedAtRaw)?.toLocal();
    if (idRaw == null || startedAt == null) continue;

    final day = DateUtils.dateOnly(startedAt);
    if (day.isBefore(fromDate) || day.isAfter(toDate)) continue;

    final setsForWorkout = setsByWorkout[idRaw.toInt()] ?? const <Map<String, dynamic>>[];
    final counts = <String, int>{};
    for (final set in setsForWorkout) {
      final exId = (set['exercise_id'] as num?)?.toInt();
      if (exId == null) continue;
      final category = exerciseCategoryById[exId] ?? 'other';
      counts[category] = (counts[category] ?? 0) + 1;
    }

    String? primaryCategory;
    if (counts.isNotEmpty) {
      primaryCategory = counts.entries.reduce((a, b) {
        if (a.value == b.value) {
          return a.key.compareTo(b.key) <= 0 ? a : b;
        }
        return a.value > b.value ? a : b;
      }).key;
    }

    final name = (workout['name'] ?? 'Workout').toString().trim();

    groupedByDay.putIfAbsent(day, () => <CalendarSessionSummary>[]).add(
          CalendarSessionSummary(
            id: idRaw.toInt(),
            name: name.isEmpty ? 'Workout' : name,
            startedAt: startedAt,
            primaryCategory: primaryCategory,
          ),
        );
  }

  final entries = groupedByDay.entries.map((entry) {
    final sessions = entry.value
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return CalendarDaySummary(date: entry.key, sessions: List.unmodifiable(sessions));
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return CalendarData(
    from: fromDate,
    to: toDate,
    days: List.unmodifiable(entries),
  );
}

Future<void> showHomeCalendarSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.9,
      child: const _HomeCalendarSheet(),
    ),
  );
}

class _HomeCalendarSheet extends StatefulWidget {
  const _HomeCalendarSheet();
  @override
  State<_HomeCalendarSheet> createState() => _HomeCalendarSheetState();
}

class _HomeCalendarSheetState extends State<_HomeCalendarSheet> {
  late Future<CalendarData> _future;
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  IconData _exerciseCategoryIcon(String? category) =>
      exercise_icons.exerciseCategoryIcon(category);

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _selectedDate = today;
    _visibleMonth = DateTime(today.year, today.month);
    _future = loadCalendarData();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<CalendarData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetHeader(onClose: () => Navigator.of(context).pop()),
                  const SizedBox(height: 24),
                  Text(
                    'Unable to load sessions.',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snap.error}',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ],
              );
            }

            final payload = snap.data ?? CalendarData(
              from: _selectedDate,
              to: _selectedDate,
              days: const [],
            );
            final data = payload.days;
            final minDate = payload.from;
            final maxDate = payload.to;
            final minMonth = DateTime(minDate.year, minDate.month);
            final maxMonth = DateTime(maxDate.year, maxDate.month);

            final clampedSelected = _clampDate(_selectedDate, minDate, maxDate);
            final clampedVisible = _clampMonth(_visibleMonth, minMonth, maxMonth);

            final effectiveSelected =
                DateUtils.isSameDay(clampedSelected, _selectedDate) ? _selectedDate : clampedSelected;
            final effectiveVisible = clampedVisible == _visibleMonth ? _visibleMonth : clampedVisible;

            if (!DateUtils.isSameDay(clampedSelected, _selectedDate) ||
                clampedVisible != _visibleMonth) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _selectedDate = clampedSelected;
                  _visibleMonth = clampedVisible;
                });
              });
            }

            final dayLookup = {
              for (final day in data) formatDateYmd(DateUtils.dateOnly(day.date)): day,
            };
            final sessionsForDay =
                dayLookup[formatDateYmd(effectiveSelected)]?.sessions ?? const <CalendarSessionSummary>[];

            final dates = _buildCalendarDatesForMonth(effectiveVisible);

            final monthLabel = _formatMonthLabel(effectiveVisible);
            final prevMonth = DateTime(effectiveVisible.year, effectiveVisible.month - 1);
            final nextMonth = DateTime(effectiveVisible.year, effectiveVisible.month + 1);
            final canGoPrev = !prevMonth.isBefore(minMonth);
            final canGoNext = !nextMonth.isAfter(maxMonth);

            final sessionTiles = sessionsForDay.isEmpty
                ? const <Widget>[]
                : [
                    for (var i = 0; i < sessionsForDay.length; i++) ...[
                      Builder(
                        builder: (_) {
                          final session = sessionsForDay[i];
                          final icon = _exerciseCategoryIcon(session.primaryCategory);
                          final subtitle =
                              '${formatTimeHm(session.startedAt)} · ${session.primaryCategory ?? 'other'}';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.onPrimaryContainer,
                                child: Icon(icon),
                              ),
                              title: Text(session.name),
                              subtitle: Text(subtitle),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                              onTap: () {
                                final rootContext = context;
                                showSessionPreviewSheet(
                                  rootContext,
                                  title: session.name,
                                  subtitle: formatDateTimeYmdHm(session.startedAt),
                                  sessionFuture: loadSessionDetail(session.id),
                                  primaryAction: SessionPreviewAction(
                                    label: 'Edit',
                                    onPressed: (sheetContext, detail) {
                                      Navigator.of(sheetContext).pop();
                                      if (!rootContext.mounted) return;
                                      showWorkoutEditorPage(
                                        rootContext,
                                        editWorkoutId: detail.id,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      if (i < sessionsForDay.length - 1) const SizedBox(height: 8),
                    ],
                  ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHeader(onClose: () => Navigator.of(context).pop()),
                const SizedBox(height: 12),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Session calendar', style: textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            IconButton(
                            onPressed: canGoPrev
                                ? () => setState(() {
                                        _visibleMonth = DateTime(
                                          effectiveVisible.year,
                                          effectiveVisible.month - 1,
                                        );
                                      })
                                : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                              tooltip: 'Previous month',
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  monthLabel,
                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            IconButton(
                            onPressed: canGoNext
                                ? () => setState(() {
                                        _visibleMonth = DateTime(
                                          effectiveVisible.year,
                                          effectiveVisible.month + 1,
                                        );
                                      })
                                : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                              tooltip: 'Next month',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _DayOfWeekHeader(textTheme: textTheme),
                        const SizedBox(height: 8),
                        _CalendarGrid(
                          dates: dates,
                          selectedDate: effectiveSelected,
                          dayLookup: dayLookup,
                          month: effectiveVisible,
                          minDate: minDate,
                          maxDate: maxDate,
                          onSelect: (date) {
                            setState(() => _selectedDate = date);
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _formatDayLabel(effectiveSelected),
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (sessionsForDay.isEmpty) ...[
                          Text(
                            'No sessions logged for this day.',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Log a workout to see it here.',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ] else ...[
                          Text(
                            '${sessionsForDay.length} session${sessionsForDay.length == 1 ? '' : 's'}',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          ...sessionTiles,
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
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

class _DayOfWeekHeader extends StatelessWidget {
  const _DayOfWeekHeader({required this.textTheme});

  final TextTheme textTheme;

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final label in _labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.dates,
    required this.selectedDate,
    required this.dayLookup,
    required this.month,
    required this.minDate,
    required this.maxDate,
    required this.onSelect,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final Map<String, CalendarDaySummary> dayLookup;
  final DateTime month;
  final DateTime minDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GridView.builder(
      itemCount: dates.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final date = dates[index];
        final inRange = !date.isBefore(minDate) && !date.isAfter(maxDate);
        final summary = dayLookup[formatDateYmd(date)];
        final isSelected = DateUtils.isSameDay(date, selectedDate);
        final badgeCount = summary?.sessionCount ?? 0;
        final hasSessions = badgeCount > 0;

        final isCurrentMonth = date.month == month.month && date.year == month.year;
        final dimmed = !inRange || !isCurrentMonth;
        Color backgroundColor = colorScheme.surfaceVariant.withOpacity(dimmed ? 0.25 : 0.6);
        Color? outlineColor;
        if (isSelected) {
          backgroundColor = Color.alphaBlend(
            colorScheme.primary.withOpacity(0.2),
            colorScheme.primaryContainer,
          );
          outlineColor = colorScheme.primary;
        } else if (hasSessions) {
          backgroundColor = colorScheme.secondaryContainer.withOpacity(0.9);
          outlineColor = colorScheme.secondary;
        }

        final onForeground = isSelected
            ? colorScheme.onPrimaryContainer
            : hasSessions
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant;

        return GestureDetector(
          onTap: inRange
              ? () {
                  onSelect(date);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: outlineColor == null ? null : Border.all(color: outlineColor, width: isSelected ? 1.5 : 1),
            ),
            padding: const EdgeInsets.all(6),
            child: Center(
              child: Text(
                '${date.day}',
                style: textTheme.titleSmall?.copyWith(
                  color: onForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          'Sessions calendar',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          tooltip: 'Close',
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
  if (value.isBefore(min)) return min;
  if (value.isAfter(max)) return max;
  return value;
}

DateTime _clampMonth(DateTime value, DateTime min, DateTime max) {
  final candidate = DateTime(value.year, value.month);
  if (candidate.isBefore(DateTime(min.year, min.month))) {
    return DateTime(min.year, min.month);
  }
  if (candidate.isAfter(DateTime(max.year, max.month))) {
    return DateTime(max.year, max.month);
  }
  return candidate;
}

String _formatMonthLabel(DateTime date) {
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final month = monthNames[date.month - 1];
  return '$month ${date.year}';
}

List<DateTime> _buildCalendarDatesForMonth(DateTime month) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);

  final startOffset = start.weekday == DateTime.monday ? 0 : start.weekday - DateTime.monday;
  final gridStart = start.subtract(Duration(days: startOffset));

  final endOffset = end.weekday == DateTime.sunday ? 0 : DateTime.sunday - end.weekday;
  final gridEnd = end.add(Duration(days: endOffset));

  final days = <DateTime>[];
  var cursor = gridStart;
  while (!cursor.isAfter(gridEnd)) {
    days.add(cursor);
    cursor = cursor.add(const Duration(days: 1));
  }
  return days;
}

String _formatDayLabel(DateTime date) {
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final month = monthNames[date.month - 1];
  return '$month ${date.day}, ${date.year}';
}

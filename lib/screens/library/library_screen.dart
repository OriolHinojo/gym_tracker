import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/screens/log/log_screen.dart';
import 'package:gym_tracker/shared/exercise_category_icons.dart';
import 'package:gym_tracker/shared/session_detail.dart';
import 'package:gym_tracker/widgets/create_exercise_dialog.dart';
import 'package:gym_tracker/widgets/session_preview_sheet.dart';
import 'package:gym_tracker/widgets/workout_editor.dart' show showWorkoutEditorPage;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  String _query = '';
  late final TabController _tab;
  int _workoutsRevision = 0;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _currentTab = _tab.index;
    _tab.addListener(() {
      if (!mounted) return;
      if (_tab.index != _currentTab) {
        setState(() {
          _currentTab = _tab.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Exercises'),
            Tab(text: 'Workouts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ExercisesTab(
            query: _query,
            onQuery: (s) => setState(() => _query = s),
          ),
          _WorkoutsTab(
            refreshToken: _workoutsRevision,
            onChanged: _refreshWorkouts,
          ),
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () => _showCreateExerciseDialog(context),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              onPressed: () => _showCreateTemplateDialog(context),
              child: const Icon(Icons.playlist_add),
            ),
    );
  }

  void _refreshWorkouts() {
    if (!mounted) return;
    setState(() => _workoutsRevision++);
  }

  Future<void> _showCreateExerciseDialog(BuildContext context) async {
    final created = await showCreateExerciseDialog(context);
    if (created != null) {
      setState(() {});
    }
  }

  Future<void> _showCreateTemplateDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final exercises = await LocalStore.instance.listExercisesRaw();
    final selected = <int>{};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New Workout Template'),
          content: SizedBox(
            width: _dialogContentWidth(ctx, 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Template name')),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: exercises.map((e) {
                      final id = (e['id'] as num).toInt();
                      final name = (e['name'] ?? '').toString();
                      final checked = selected.contains(id);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(name),
                        onChanged: (v) => setD(() {
                          if (v == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty || selected.isEmpty) return;
                await LocalStore.instance
                    .createWorkoutTemplate(name: name, exerciseIds: selected.toList());
                if (context.mounted) Navigator.pop(ctx);
                _refreshWorkouts();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  double _dialogContentWidth(BuildContext context, double fallbackWidth) {
    final size = MediaQuery.sizeOf(context);
    final available = size.width - 48; // approximate dialog padding
    if (!available.isFinite || available <= 0) {
      return fallbackWidth;
    }
    return available;
  }
}

/* ------------------------------- Exercises ------------------------------- */

class _ExercisesTab extends StatefulWidget {
  const _ExercisesTab({required this.query, required this.onQuery});
  final String query;
  final ValueChanged<String> onQuery;

  @override
  State<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<_ExercisesTab> {
  String? _selectedCategory;
  List<String> _availableCategories = const [];

  String _normalizeCategoryValue(String? raw) {
    final normalized = (raw ?? '').toString().trim().toLowerCase();
    if (normalized.isEmpty) return 'unknown';
    return normalized;
  }

  String _categoryLabel(String value) {
    if (value.isEmpty || value == 'unknown') return 'Unknown';
    return value
        .split(RegExp(r'[\s_]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.substring(0, 1).toUpperCase() +
              (part.length > 1 ? part.substring(1) : ''),
        )
        .join(' ');
  }

  Future<void> _openCategoryFilterSheet() async {
    final categories = _availableCategories;
    if (categories.isEmpty) return;

    String? tempSelection = _selectedCategory;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) => StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Exercise category',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All categories'),
                      selected: tempSelection == null,
                      onSelected: (selected) {
                        if (!selected) return;
                        setModalState(() => tempSelection = null);
                      },
                    ),
                    ...categories.map(
                      (category) => FilterChip(
                        label: Text(_categoryLabel(category)),
                        selected: tempSelection == category,
                        onSelected: (selected) => setModalState(() {
                          tempSelection = selected ? category : null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setModalState(() => tempSelection = null);
                      },
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        if (!mounted) return;
                        if (_selectedCategory != tempSelection) {
                          setState(() => _selectedCategory = tempSelection);
                        }
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCategorySelection = _selectedCategory != null;
    final filterIconColor = hasCategorySelection ? theme.colorScheme.primary : null;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search exercises',
              suffixIcon: IconButton(
                tooltip: 'Filter by category',
                icon: Icon(
                  hasCategorySelection ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: filterIconColor,
                ),
                onPressed: _availableCategories.isEmpty
                    ? null
                    : () {
                        _openCategoryFilterSheet();
                      },
              ),
            ),
            onChanged: (v) => widget.onQuery(v.trim()),
          ),
        ),
        if (hasCategorySelection)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: InputChip(
                avatar: const Icon(Icons.filter_alt, size: 16),
                label: Text('Category: ${_categoryLabel(_selectedCategory!)}'),
                onDeleted: () => setState(() => _selectedCategory = null),
              ),
            ),
          ),
        if (hasCategorySelection) const SizedBox(height: 4),
        Flexible(
          fit: FlexFit.tight,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: LocalStore.instance.listExercisesRaw(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading exercises:\n${snapshot.error}'));
              }
              final exercises = snapshot.data ?? [];
              final q = widget.query.toLowerCase();
              final categories = <String>{
                for (final e in exercises) _normalizeCategoryValue(e['category']),
              };
              final sortedCategories = categories.toList()
                ..sort((a, b) => _categoryLabel(a).compareTo(_categoryLabel(b)));
              if (!listEquals(_availableCategories, sortedCategories)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (!listEquals(_availableCategories, sortedCategories)) {
                    setState(() => _availableCategories = sortedCategories);
                  }
                });
              }
              final selectedCategory = _selectedCategory;
              if (selectedCategory != null && !categories.contains(selectedCategory)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (_selectedCategory == selectedCategory) {
                    setState(() => _selectedCategory = null);
                  }
                });
              }
              final filtered = exercises.where((e) {
                final name = (e['name'] ?? '').toString().toLowerCase();
                final rawCategoryValue = (e['category'] ?? '').toString();
                final effectiveCategory =
                    rawCategoryValue.trim().isEmpty ? 'Unknown' : rawCategoryValue;
                final normalizedCategory = _normalizeCategoryValue(rawCategoryValue);
                final matchesQuery =
                    q.isEmpty || name.contains(q) || effectiveCategory.toLowerCase().contains(q);
                final matchesCategory =
                    _selectedCategory == null || _selectedCategory == normalizedCategory;
                return matchesQuery && matchesCategory;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No exercises found'));
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = filtered[index];
                  final id = (e['id'] as num?)?.toInt();
                  final name = (e['name'] ?? 'Exercise').toString();
                  final rawCategoryValue = (e['category'] ?? '').toString();
                  final iconCategory =
                      rawCategoryValue.trim().isEmpty ? 'Unknown' : rawCategoryValue;
                  final normalizedCategory = _normalizeCategoryValue(rawCategoryValue);
                  final displayCategory = _categoryLabel(normalizedCategory);

                  return ListTile(
                    leading: Icon(exerciseCategoryIcon(iconCategory)),
                    title: Text(name),
                    subtitle: Text('Primary: $displayCategory'),
                    onTap: id == null
                        ? null
                        : () => context.pushNamed(
                              'exerciseDetail',
                              pathParameters: {'id': id.toString()},
                            ),
                    onLongPress: id == null
                        ? null
                        : () => _showExerciseActions(
                              context,
                              id: id,
                              initialName: name,
                              initialCategory: iconCategory,
                            ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showExerciseActions(
    BuildContext context, {
    required int id,
    required String initialName,
    required String initialCategory,
  }) async {
    final action = await showModalBottomSheet<_ExerciseAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit exercise'),
              onTap: () => Navigator.pop(ctx, _ExerciseAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete exercise'),
              onTap: () => Navigator.pop(ctx, _ExerciseAction.delete),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _ExerciseAction.edit:
        final updated = await showEditExerciseDialog(
          context,
          id: id,
          initialName: initialName,
          initialCategory: initialCategory,
        );
        if (!mounted || !updated) return;
        final refreshed = await LocalStore.instance.getExerciseRaw(id);
        if (!mounted) return;
        setState(() {});
        final newName = (refreshed?['name'] ?? initialName).toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated "$newName"')),
        );
        break;
      case _ExerciseAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Delete exercise'),
            content: Text('Delete "$initialName"? This removes its sets and template references.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await LocalStore.instance.deleteExercise(id);
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "$initialName"')),
        );
        break;
    }
  }
}

enum _ExerciseAction { edit, delete }

/* -------------------------------- Workouts -------------------------------- */

class _WorkoutsTab extends StatefulWidget {
  const _WorkoutsTab({required this.refreshToken, required this.onChanged});
  final int refreshToken;
  final VoidCallback onChanged;

  @override
  State<_WorkoutsTab> createState() => _WorkoutsTabState();
}

class _WorkoutsTabState extends State<_WorkoutsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _WorkoutsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _refresh();
    }
  }

  Future<List<Map<String, dynamic>>> _load() {
    return LocalStore.instance.listWorkoutTemplatesRaw();
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error loading workouts:\n${snap.error}'));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No workout templates yet'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final w = items[i];
            final id = (w['id'] as num).toInt();
            final name = (w['name'] ?? '').toString();
            final List<dynamic> ids = (w['exercise_ids'] ?? []) as List<dynamic>;
            final exercises = ids.map((e) => (e as num).toInt()).toList();
            return ListTile(
              leading: const Icon(Icons.playlist_play),
              title: Text(name),
              subtitle: Text('Exercises: ${exercises.length}'),
              onTap: () {
                context.pushNamed('log', extra: {'templateId': id});
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    tooltip: 'Preview',
                    onPressed: () => _showPreview(context, id, name, exercises),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(context, id, name),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPreview(
    BuildContext context,
    int templateId,
    String name,
    List<int> exerciseIds,
  ) async {
    final resolvedName = name.trim().isEmpty ? 'Workout Template' : name;
    final latestWorkout = await _latestWorkoutForTemplate(templateId);
    if (!mounted) return;

    SessionPreviewAction? action;
    final workoutId = (latestWorkout?['id'] as num?)?.toInt();
    if (workoutId != null) {
        action = SessionPreviewAction(
          label: 'Edit',
          onPressed: (sheetContext, detail) {
            Navigator.of(sheetContext).pop();
            if (!context.mounted) return;
            showWorkoutEditorPage(
              context,
              editWorkoutId: detail.id,
            );
          },
          isVisible: (detail) => detail.id > 0,
        );
    }

    final future = _buildTemplatePreview(
      templateId,
      exerciseIds,
      resolvedName,
      lastWorkout: latestWorkout,
    );

    showSessionPreviewSheet(
      context,
      sessionFuture: future,
      title: resolvedName,
      subtitle: 'Template preview',
      primaryAction: action,
    );
  }

  Future<SessionDetail> _buildTemplatePreview(
    int templateId,
    List<int> exerciseIds,
    String resolvedName,
    {Map<String, dynamic>? lastWorkout}
  ) async {
    final all = await LocalStore.instance.listExercisesRaw();
    final byId = <int, Map<String, dynamic>>{
      for (final item in all)
        if (item['id'] != null) (item['id'] as num).toInt(): item,
    };
    final exercises = await Future.wait(exerciseIds.map((exId) async {
      final data = byId[exId];
      final exName = (data?['name'] ?? 'Exercise #$exId').toString();
      final history = await LocalStore.instance.listLatestSetsForExerciseRaw(
        exId,
        templateId: templateId,
      );
      final sets = history
          .map(
            (row) => SessionSet(
              ordinal: (row['ordinal'] as num?)?.toInt() ?? 0,
              reps: (row['reps'] as num?)?.toInt() ?? 0,
              weight: (row['weight'] as num?)?.toDouble() ?? 0,
              tag: (row['tag'] ?? '') == ''
                  ? null
                  : row['tag'].toString(),
            ),
          )
          .toList();
      return SessionExercise(name: exName, sets: sets);
    }));
    final templateNotes = exercises.isEmpty
        ? 'Template contains no exercises yet.'
        : 'Shows the most recent logged sets for each exercise (per template when available).';
    final workoutNotes = (lastWorkout?['notes'] ?? '').toString().trim();
    final combinedNotes = [
      if (workoutNotes.isNotEmpty) workoutNotes,
      templateNotes,
    ].join('\n\n').trim();
    final startedAtRaw = (lastWorkout?['started_at'] ?? '').toString();
    final startedAt = DateTime.tryParse(startedAtRaw);
    return SessionDetail(
      id: (lastWorkout?['id'] as num?)?.toInt() ?? 0,
      name: resolvedName,
      startedAt: startedAt,
      notes: combinedNotes.isEmpty ? templateNotes : combinedNotes,
      exercises: exercises,
    );
  }

  Future<Map<String, dynamic>?> _latestWorkoutForTemplate(int templateId) async {
    const userId = 1;
    final workouts = await LocalStore.instance.listWorkoutsRaw();
    Map<String, dynamic>? latest;
    DateTime? latestStartedAt;

    for (final row in workouts) {
      final uid = (row['user_id'] as num?)?.toInt() ?? userId;
      if (uid != userId) continue;
      final rowTemplate = (row['template_id'] as num?)?.toInt();
      if (rowTemplate != templateId) continue;
      final startedRaw = (row['started_at'] ?? '').toString();
      final startedAt = DateTime.tryParse(startedRaw);
      if (latest == null) {
        latest = Map<String, dynamic>.from(row);
        latestStartedAt = startedAt;
        continue;
      }
      if (startedAt == null && latestStartedAt != null) continue;
      if (startedAt == null && latestStartedAt == null) {
        latest = Map<String, dynamic>.from(row);
        continue;
      }
      if (startedAt != null &&
          (latestStartedAt == null || startedAt.isAfter(latestStartedAt!))) {
        latest = Map<String, dynamic>.from(row);
        latestStartedAt = startedAt;
      }
    }

    return latest;
  }

  Future<void> _confirmDelete(BuildContext context, int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete workout'),
        content: Text('Delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await LocalStore.instance.deleteWorkoutTemplate(id);
    if (!mounted) return;
    _refresh();
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted workout "$name"')),
    );
  }
}

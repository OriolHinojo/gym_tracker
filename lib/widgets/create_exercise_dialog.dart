import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';

/// Result returned when a new exercise has been created through the dialog.
class CreatedExercise {
  const CreatedExercise({required this.id, required this.name, required this.category});
  final int id;
  final String name;
  final String category;
}

class _ExerciseDialogResult {
  const _ExerciseDialogResult({required this.name, required this.category});
  final String name;
  final String category;
}

const List<Map<String, String>> _exerciseCategories = <Map<String, String>>[
  {'value': 'compound', 'label': 'Compound'},
  {'value': 'isolation', 'label': 'Isolation'},
  {'value': 'push', 'label': 'Push'},
  {'value': 'pull', 'label': 'Pull'},
  {'value': 'legs', 'label': 'Legs'},
  {'value': 'core', 'label': 'Core'},
  {'value': 'cardio', 'label': 'Cardio'},
  {'value': 'mobility', 'label': 'Mobility'},
  {'value': 'other', 'label': 'Other'},
];

/// Shows the shared create-exercise dialog and returns the created exercise.
Future<CreatedExercise?> showCreateExerciseDialog(BuildContext context) async {
  final result = await _showExerciseDialog(context, title: 'New Exercise');
  if (result == null) return null;

  final id = await LocalStore.instance.createExercise(
    name: result.name,
    category: result.category,
  );

  return CreatedExercise(id: id, name: result.name, category: result.category);
}

/// Shows the shared edit-exercise dialog and persists the update.
Future<bool> showEditExerciseDialog(
  BuildContext context, {
  required int id,
  required String initialName,
  required String initialCategory,
}) async {
  final result = await _showExerciseDialog(
    context,
    title: 'Edit Exercise',
    isEditing: true,
    initialName: initialName,
    initialCategory: initialCategory,
  );
  if (result == null) return false;

  await LocalStore.instance.updateExercise(
    id: id,
    name: result.name,
    category: result.category,
  );
  return true;
}

Future<_ExerciseDialogResult?> _showExerciseDialog(
  BuildContext context, {
  required String title,
  bool isEditing = false,
  String? initialName,
  String? initialCategory,
}) async {
  return showDialog<_ExerciseDialogResult>(
    context: context,
    builder: (dialogCtx) => _ExerciseDialog(
      title: title,
      isEditing: isEditing,
      initialName: initialName,
      initialCategory: initialCategory,
    ),
  );
}

String? _resolveCategoryValue(String? category) {
  if (category == null) return null;
  final normalized = category.toLowerCase().trim();
  for (final entry in _exerciseCategories) {
    if (entry['value'] == normalized) {
      return entry['value'];
    }
  }
  return null;
}

double _dialogContentWidth(BuildContext context, double fallbackWidth) {
  final size = MediaQuery.sizeOf(context);
  final available = size.width - 48; // default dialog horizontal insets
  if (!available.isFinite || available <= 0) {
    return fallbackWidth;
  }
  return available;
}

class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog({
    required this.title,
    required this.isEditing,
    this.initialName,
    this.initialCategory,
  });

  final String title;
  final bool isEditing;
  final String? initialName;
  final String? initialCategory;

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _customCatCtrl;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _customCatCtrl = TextEditingController();
    _selectedCategory = _exerciseCategories.first['value']!;

    final resolved = _resolveCategoryValue(widget.initialCategory);
    if (resolved != null) {
      _selectedCategory = resolved;
    } else if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = 'other';
      _customCatCtrl.text = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customCatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final optionStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400);

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          width: _dialogContentWidth(context, 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _exerciseCategories
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['value'],
                        child: Text(
                          c['label']!,
                          style: optionStyle,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedCategory = value;
                    if (_selectedCategory != 'other') {
                      _customCatCtrl.clear();
                    }
                  });
                },
              ),
              if (_selectedCategory == 'other') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _customCatCtrl,
                  decoration: const InputDecoration(labelText: 'Custom category'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    var category = _selectedCategory;
    if (category == 'other') {
      final custom = _customCatCtrl.text.trim();
      if (custom.isNotEmpty) {
        category = custom;
      }
    }

    Navigator.of(context).pop(
      _ExerciseDialogResult(name: name, category: category),
    );
  }
}

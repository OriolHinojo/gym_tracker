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
  final nameCtrl = TextEditingController();
  final customCatCtrl = TextEditingController();
  String selectedCategory = _exerciseCategories.first['value']!;

  if (initialName != null && initialName.isNotEmpty) {
    nameCtrl.text = initialName;
  }

  String? resolved = _resolveCategoryValue(initialCategory);
  if (resolved != null) {
    selectedCategory = resolved;
  } else if (initialCategory != null && initialCategory.isNotEmpty) {
    selectedCategory = 'other';
    customCatCtrl.text = initialCategory;
  }

  try {
    return await showDialog<_ExerciseDialogResult>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final optionStyle =
              Theme.of(dialogCtx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400);

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(dialogCtx).viewInsets.bottom),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
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
                        setDialogState(() {
                          selectedCategory = value;
                          if (selectedCategory != 'other') {
                            customCatCtrl.clear();
                          }
                        });
                      },
                    ),
                    if (selectedCategory == 'other') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: customCatCtrl,
                        decoration: const InputDecoration(labelText: 'Custom category'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  var category = selectedCategory;
                  if (category == 'other') {
                    final custom = customCatCtrl.text.trim();
                    if (custom.isNotEmpty) {
                      category = custom;
                    }
                  }

                  Navigator.of(dialogCtx).pop(
                    _ExerciseDialogResult(name: name, category: category),
                  );
                },
                child: Text(isEditing ? 'Save' : 'Create'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    await Future<void>.delayed(Duration.zero);
    nameCtrl.dispose();
    customCatCtrl.dispose();
  }
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

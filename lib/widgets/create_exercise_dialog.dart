import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';

/// Result returned when a new exercise has been created through the dialog.
class CreatedExercise {
  const CreatedExercise({required this.id, required this.name, required this.category});
  final int id;
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
  final nameCtrl = TextEditingController();
  final customCatCtrl = TextEditingController();
  var selectedCategory = _exerciseCategories.first['value']!;
  CreatedExercise? created;

  await showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) {
        final optionStyle = Theme.of(dialogCtx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400);

        return AlertDialog(
          title: const Text('New Exercise'),
          content: SizedBox(
            width: 360,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                var category = selectedCategory;
                if (category == 'other') {
                  final custom = customCatCtrl.text.trim();
                  if (custom.isNotEmpty) {
                    category = custom;
                  }
                }

                final id = await LocalStore.instance.createExercise(name: name, category: category);
                created = CreatedExercise(id: id, name: name, category: category);
                if (Navigator.canPop(dialogCtx)) {
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ),
  );

  nameCtrl.dispose();
  customCatCtrl.dispose();
  return created;
}

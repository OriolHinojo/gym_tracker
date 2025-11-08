import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/widgets/create_exercise_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gym_tracker_test_');
    await LocalStore.instance.resetForTests(deleteFile: true);
    LocalStore.instance.overrideAppDirectory(tempDir);
  });

  tearDown(() async {
    await LocalStore.instance.resetForTests(deleteFile: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('creating an exercise via dialog does not throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          return SafeArea(
            top: true,
            bottom: false,
            left: true,
            right: true,
            child: child,
          );
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCreateExerciseDialog(context),
                child: const Text('Add exercise'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'New Exercise');
    await tester.tap(find.text('Create'));

    await tester.pumpAndSettle();
  });
}

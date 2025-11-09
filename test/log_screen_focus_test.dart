import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/screens/log/log_screen.dart';
import 'package:gym_tracker/widgets/workout_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogScreen editor', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ironpulse_log_test_');
      await LocalStore.instance.resetForTests(deleteFile: true);
      LocalStore.instance.overrideAppDirectory(tempDir);
    });

    tearDown(() async {
      await LocalStore.instance.resetForTests(deleteFile: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('expanding exercise focuses first empty weight field', (tester) async {
      final editorState = await _pumpLogScreenAndGetEditorState(tester);
      editorState.debugAddExerciseForTest(
        id: 1,
        presetSets: [
          {'weight': '', 'reps': ''},
          {'weight': '100', 'reps': '5'},
        ],
      );

      await tester.pump();
      await tester.pump();

      expect(editorState.debugWeightHasFocus(1, 1), isTrue);
    });

    testWidgets('duplicate last set copies previous values', (tester) async {
      final editorState = await _pumpLogScreenAndGetEditorState(tester);
      editorState.debugAddExerciseForTest(
        id: 1,
        presetSets: [
          {'weight': '120', 'reps': '5'},
        ],
      );

      await tester.pump();
      await tester.pump();

      final before = editorState.debugExerciseSets(1);
      editorState.debugDuplicateLastSetForTest(1);

      await tester.pump();

      final after = editorState.debugExerciseSets(1);
      expect(after.length, before.length + 1);
      expect(after.last['weight'], before.last['weight']);
      expect(after.last['reps'], before.last['reps']);
    });
  });
}

Future<dynamic> _pumpLogScreenAndGetEditorState(WidgetTester tester) async {
  WorkoutEditor.debugDisableTicker = true;
  addTearDown(() => WorkoutEditor.debugDisableTicker = false);
  await tester.pumpWidget(const MaterialApp(home: LogScreen()));
  await tester.pump(); // allow WorkoutEditor to mount
  return tester.state(find.byType(WorkoutEditor));
}

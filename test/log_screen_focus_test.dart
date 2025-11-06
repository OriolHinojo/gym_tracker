import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/screens/log/log_screen.dart';

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
      await tester.pumpWidget(const MaterialApp(home: LogScreen()));

      final state = tester.state(find.byType(LogScreen)) as dynamic;
      state.debugAddExerciseForTest(
        id: 1,
        presetSets: [
          {'weight': '', 'reps': ''},
          {'weight': '100', 'reps': '5'},
        ],
      );

      await tester.pump();
      await tester.pump();

      expect(state.debugWeightHasFocus(1, 1), isTrue);
    });

    testWidgets('duplicate last set copies previous values', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LogScreen()));

      final state = tester.state(find.byType(LogScreen)) as dynamic;
      state.debugAddExerciseForTest(
        id: 1,
        presetSets: [
          {'weight': '120', 'reps': '5'},
        ],
      );

      await tester.pump();
      await tester.pump();

      final before = state.debugExerciseSets(1);
      state.debugDuplicateLastSetForTest(1);

      await tester.pump();

      final after = state.debugExerciseSets(1);
      expect(after.length, before.length + 1);
      expect(after.last['weight'], before.last['weight']);
      expect(after.last['reps'], before.last['reps']);
    });
  });
}

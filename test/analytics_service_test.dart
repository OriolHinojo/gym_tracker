import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/services/analytics/analytics_models.dart';
import 'package:gym_tracker/services/analytics/analytics_service.dart';
import 'package:gym_tracker/shared/set_tags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService snapshot', () {
    late Directory tempDir;
    late AnalyticsService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('analytics_service_test_');
      await LocalStore.instance.resetForTests(deleteFile: true);
      LocalStore.instance.overrideAppDirectory(tempDir);
      service = AnalyticsService();
      await LocalStore.instance.init();
    });

    tearDown(() async {
      await LocalStore.instance.resetForTests(deleteFile: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('computes snapshot from deterministic seeded data', () async {
      final base = DateTime.utc(2024, 1, 1);
      Future<void> addWorkout({
        required DateTime startedAt,
        required int exerciseId,
        required double weight,
        required int reps,
      }) {
        return LocalStore.instance.saveWorkout(
          userId: 1,
          name: 'Session ${startedAt.day}',
          templateId: null,
          startedAtUtc: startedAt,
          sets: [
            {
              'exercise_id': exerciseId,
              'ordinal': 1,
              'reps': reps,
              'weight': weight,
              'created_at': startedAt,
            },
          ],
        );
      }

      await addWorkout(startedAt: base, exerciseId: 1, weight: 100, reps: 5); // 500
      await addWorkout(startedAt: base.add(const Duration(days: 1)), exerciseId: 2, weight: 150, reps: 4); // 600
      await addWorkout(startedAt: base.add(const Duration(days: 2)), exerciseId: 3, weight: 220, reps: 6); // 1320

      final snapshot = await service.snapshot();

      expect(snapshot.sessionCount, 3);
      expect(snapshot.totalVolume, closeTo(2420, 0.1));
      expect(snapshot.averageVolumePerSession, closeTo(806.6, 0.2));
      expect(snapshot.volumeTrend.length, 3);
    });

    test('filters by template id', () async {
      final now = DateTime.now().toUtc();
      await LocalStore.instance.saveWorkout(
        userId: 1,
        name: 'Template Run',
        templateId: 7,
        startedAtUtc: now,
        sets: [
          {
            'exercise_id': 1,
            'ordinal': 1,
            'reps': 5,
            'weight': 100,
          },
        ],
      );

      final snapshot = await service.snapshot(
        filters: AnalyticsFilters(templateIds: {7}),
      );

      expect(snapshot.sessionCount, 1);
      expect(snapshot.totalVolume, 500);
    });

    test('filters by time-of-day bucket', () async {
      final morning = DateTime.utc(2024, 1, 1, 6);
      await LocalStore.instance.saveWorkout(
        userId: 1,
        name: 'Morning volume',
        templateId: null,
        startedAtUtc: morning,
        sets: [
          {
            'exercise_id': 1,
            'ordinal': 1,
            'reps': 8,
            'weight': 80,
          },
        ],
      );

      final snapshot = await service.snapshot(
        filters: const AnalyticsFilters(
          timeOfDayBuckets: {TimeOfDayBucket.morning},
        ),
      );

      expect(snapshot.sessionCount, greaterThanOrEqualTo(1));
      final morningEntry = snapshot.volumeByTimeOfDay
          .firstWhere((entry) => entry.bucket == TimeOfDayBucket.morning, orElse: () => const TimeOfDayVolume(bucket: TimeOfDayBucket.morning, averageVolume: 0, lastSessionVolume: 0, sessionCount: 0));
      expect(morningEntry.averageVolume, greaterThan(0));
      expect(morningEntry.lastSessionVolume, greaterThan(0));
      expect(morningEntry.sessionCount, greaterThan(0));
    });

    test('filters by set tags', () async {
      final now = DateTime.now().toUtc();
      await LocalStore.instance.saveWorkout(
        userId: 1,
        name: 'Tagged session',
        templateId: null,
        startedAtUtc: now,
        sets: [
          {
            'exercise_id': 1,
            'ordinal': 1,
            'reps': 3,
            'weight': 110,
            'tag': SetTag.dropSet.storage,
          },
        ],
      );

      final snapshot = await service.snapshot(
        filters: AnalyticsFilters(tags: {SetTag.dropSet}),
      );

      expect(snapshot.sessionCount, 1);
      expect(snapshot.totalVolume, 330);
    });
  });
}

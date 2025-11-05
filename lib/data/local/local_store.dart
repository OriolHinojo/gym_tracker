import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Lightweight local JSON-based database for the gym tracker demo.
/// Works on Android, iOS, macOS, Windows, and Linux (not Web).
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  File? _file;
  Map<String, dynamic> _db = {};
  Completer<void>? _initComp;

  // Notifier: emits whenever preferred_exercise_id changes (Home listens to this).
  final ValueNotifier<int?> _preferredExerciseId = ValueNotifier<int?>(null);
  ValueListenable<int?> get preferredExerciseIdListenable => _preferredExerciseId;

  /// Initializes the local database file and loads it into memory.
  Future<void> init() async {
    if (_initComp != null) return _initComp!.future;
    _initComp = Completer<void>();

    try {
      assert(!kIsWeb, 'LocalStore file backend is not supported on Web.');

      final dir = await _getAppDir();
      final dbPath = p.join(dir.path, 'gym_tracker_db.json');
      _file = File(dbPath);

      if (!await _file!.exists()) {
        await _file!.create(recursive: true);
        _seedMockData();
        await _save();
      } else {
        try {
          final text = await _file!.readAsString();
          if (text.trim().isEmpty) {
            _seedMockData();
            await _save();
          } else {
            final parsed = (json.decode(text) as Map).cast<String, dynamic>();
            _db = parsed;
            _db.putIfAbsent('version', () => 1);
            _db.putIfAbsent('settings', () => {'preferred_exercise_id': null});
            _db.putIfAbsent('workout_templates', () => <Map<String, dynamic>>[]);
          }
        } catch (_) {
          try {
            final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
            await _file!.rename('${_file!.path}.$ts.bak');
          } catch (_) {}
          _seedMockData();
          await _save();
        }
      }

      final settings = Map<String, dynamic>.from(_db['settings'] ?? const {});
      final pref = settings['preferred_exercise_id'];
      _preferredExerciseId.value = pref == null ? null : (pref as num).toInt();

      _initComp!.complete();
    } catch (e, st) {
      _initComp!.completeError(e, st);
      rethrow;
    }
  }

  /// Returns a writable per-app directory using path_provider.
  Future<Directory> _getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  /// Atomic save: write to temp, then rename.
  Future<void> _save() async {
    if (_file == null) return;
    final tmp = File('${_file!.path}.tmp');
    await tmp.writeAsString(json.encode(_db), flush: true);
    await tmp.rename(_file!.path);
  }

  /// Seed a small mock dataset (timestamps in UTC).
  void _seedMockData() {
    final now = DateTime.now().toUtc();

    final user = {
      'id': 1,
      'name': 'Demo User',
      'units': 'kg',
      'created_at': now.toIso8601String(),
    };

    final exercises = [
      {'id': 1, 'name': 'Bench Press', 'category': 'compound'},
      {'id': 2, 'name': 'Back Squat', 'category': 'compound'},
      {'id': 3, 'name': 'Deadlift', 'category': 'compound'},
    ];

    // Workouts: one last week, two this week (UTC).
    final lastWeek = now.subtract(const Duration(days: 9));
    final workout1 = {
      'id': 1,
      'user_id': 1,
      'name': 'Leg Day',
      'started_at': lastWeek.toIso8601String(),
      'notes': ''
    };

    final mondayThisWeek = _mondayOfWeek(now);
    final workout2Start = mondayThisWeek.add(const Duration(days: 1)); // Tuesday
    final workout3Start = mondayThisWeek.add(const Duration(days: 2, hours: 2)); // Wednesday + 2h

    final workout2 = {
      'id': 2,
      'user_id': 1,
      'name': 'Push Day',
      'started_at': workout2Start.toIso8601String(),
      'notes': ''
    };

    final workout3 = {
      'id': 3,
      'user_id': 1,
      'name': 'Full Body',
      'started_at': workout3Start.toIso8601String(),
      'notes': ''
    };

    // Sets (ensure ordinals reflect order, weights > 0)
    final sets = [
      // workout1 (last week)
      {
        'id': 1,
        'workout_id': 1,
        'user_id': 1,
        'exercise_id': 2,
        'ordinal': 1,
        'reps': 5,
        'weight': 120,
        'created_at': lastWeek.toIso8601String()
      },
      {
        'id': 2,
        'workout_id': 1,
        'user_id': 1,
        'exercise_id': 3,
        'ordinal': 2,
        'reps': 3,
        'weight': 160,
        'created_at': lastWeek.toIso8601String()
      },

      // workout2 (this week)
      {
        'id': 3,
        'workout_id': 2,
        'user_id': 1,
        'exercise_id': 1,
        'ordinal': 1,
        'reps': 5,
        'weight': 90,
        'created_at': workout2Start.toIso8601String()
      },
      {
        'id': 4,
        'workout_id': 2,
        'user_id': 1,
        'exercise_id': 1,
        'ordinal': 2,
        'reps': 3,
        'weight': 100,
        'created_at': workout2Start.toIso8601String()
      },

      // workout3 (this week)
      {
        'id': 5,
        'workout_id': 3,
        'user_id': 1,
        'exercise_id': 2,
        'ordinal': 1,
        'reps': 5,
        'weight': 130,
        'created_at': workout3Start.toIso8601String()
      },
      {
        'id': 6,
        'workout_id': 3,
        'user_id': 1,
        'exercise_id': 1,
        'ordinal': 2,
        'reps': 2,
        'weight': 105,
        'created_at': workout3Start.toIso8601String()
      },
    ];

    _db = {
      'version': 2,
      'settings': {
        'preferred_exercise_id': null,
      },
      'users': [user],
      'exercises': exercises,
      'workouts': [workout1, workout2, workout3],
      'sets': sets,
      // Workout templates (named groups of exercises)
      'workout_templates': <Map<String, dynamic>>[
        {
          'id': 1,
          'name': 'Push Day',
          'exercise_ids': [1], // Bench
          'created_at': now.toIso8601String(),
        },
      ],
      'prs': [],
      'body_metrics': [],
    };
  }

  /// Returns the Monday of the current week (UTC).
  DateTime _mondayOfWeek(DateTime utcNow) {
    final weekday = utcNow.weekday; // Monday = 1
    final monday = DateTime.utc(utcNow.year, utcNow.month, utcNow.day)
        .subtract(Duration(days: weekday - 1));
    return monday;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _nextId(List<Map<String, dynamic>> table) {
    if (table.isEmpty) return 1;
    final ids = table.map((e) => (e['id'] as num?)?.toInt() ?? 0).toList()..sort();
    return ids.last + 1;
  }

  // ---------------------------------------------------------------------------
  // Public APIs for your UI
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> listExercisesRaw() async {
    await init();
    final rows = List<Map<String, dynamic>>.from(_db['exercises'] ?? const []);
    rows.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return rows;
  }

  Future<Map<String, dynamic>?> getExerciseRaw(int id) async {
    await init();
    final rows = List<Map<String, dynamic>>.from(_db['exercises'] ?? const []);
    try {
      return rows.firstWhere((e) => (e['id'] as num?)?.toInt() == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listSetsForExerciseRaw(int exerciseId) async {
    await init();
    final sets = List<Map<String, dynamic>>.from(_db['sets'] ?? const []);
    return sets
        .where((s) => (s['exercise_id'] as num?)?.toInt() == exerciseId)
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
  }

  /// Create an exercise on the fly.
  Future<int> createExercise({required String name, String category = 'other'}) async {
    await init();
    final list = List<Map<String, dynamic>>.from(_db['exercises'] ?? const []);
    final id = _nextId(list);
    list.add({'id': id, 'name': name, 'category': category});
    _db['exercises'] = list;
    await _save();
    return id;
  }

  /// Preferred (user-chosen) favourite exercise ID.
  Future<int?> getPreferredExerciseId() async {
    await init();
    final settings = Map<String, dynamic>.from(_db['settings'] ?? const {});
    final id = settings['preferred_exercise_id'];
    return id == null ? null : (id as num).toInt();
  }

  /// Set or clear the preferred favourite exercise.
  Future<void> setPreferredExerciseId(int? exerciseId) async {
    await init();
    final settings = Map<String, dynamic>.from(_db['settings'] ?? const {});
    settings['preferred_exercise_id'] = exerciseId;
    _db['settings'] = settings;
    await _save();
    _preferredExerciseId.value = exerciseId;
  }

  // ----- Workout templates -----

  Future<List<Map<String, dynamic>>> listWorkoutTemplatesRaw() async {
    await init();
    final list = List<Map<String, dynamic>>.from(_db['workout_templates'] ?? const []);
    list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return list;
  }

  Future<Map<String, dynamic>?> getWorkoutTemplateRaw(int id) async {
    await init();
    final list = List<Map<String, dynamic>>.from(_db['workout_templates'] ?? const []);
    try {
      return list.firstWhere((e) => (e['id'] as num?)?.toInt() == id);
    } catch (_) {
      return null;
    }
  }

  Future<int> createWorkoutTemplate({required String name, required List<int> exerciseIds}) async {
    await init();
    final list = List<Map<String, dynamic>>.from(_db['workout_templates'] ?? const []);
    final id = _nextId(list);
    list.add({
      'id': id,
      'name': name,
      'exercise_ids': exerciseIds,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    _db['workout_templates'] = list;
    await _save();
    return id;
  }

  Future<void> deleteWorkoutTemplate(int id) async {
    await init();
    final list = List<Map<String, dynamic>>.from(_db['workout_templates'] ?? const []);
    list.removeWhere((e) => (e['id'] as num?)?.toInt() == id);
    _db['workout_templates'] = list;
    await _save();
  }

  // ----- Persist a finished workout (and its sets) -----

  /// Save a workout with its sets. Returns the new workout id.
  ///
  /// [sets] entries: {exercise_id, ordinal, reps, weight, created_at?}
  Future<int> saveWorkout({
    required int userId,
    required String name,
    String notes = '',
    DateTime? startedAtUtc,
    required List<Map<String, dynamic>> sets,
  }) async {
    await init();
    final workouts = List<Map<String, dynamic>>.from(_db['workouts'] ?? const []);
    final allSets = List<Map<String, dynamic>>.from(_db['sets'] ?? const []);
    final now = DateTime.now().toUtc();
    final wid = _nextId(workouts);
    final started = startedAtUtc ?? now;

    workouts.add({
      'id': wid,
      'user_id': userId,
      'name': name,
      'started_at': started.toIso8601String(),
      'notes': notes,
    });

    int nextSetId = allSets.isEmpty
        ? 1
        : (allSets.map((e) => (e['id'] as num).toInt()).reduce((a, b) => a > b ? a : b) + 1);

    for (final s in sets) {
      allSets.add({
        'id': nextSetId++,
        'workout_id': wid,
        'user_id': userId,
        'exercise_id': (s['exercise_id'] as num).toInt(),
        'ordinal': (s['ordinal'] as num).toInt(),
        'reps': (s['reps'] as num).toInt(),
        'weight': (s['weight'] as num).toDouble(),
        'created_at': (s['created_at'] as DateTime? ?? now).toIso8601String(),
      });
    }

    _db['workouts'] = workouts;
    _db['sets'] = allSets;
    await _save();
    return wid;
  }

  /// Returns quick summary stats for home dashboard.
  Future<HomeStats> getHomeStats({int userId = 1}) async {
    await init();
    try {
      // Week windows (UTC)
      final nowUtc = DateTime.now().toUtc();
      final monday = _mondayOfWeek(nowUtc);
      final nextMonday = monday.add(const Duration(days: 7));
      final prevMonday = monday.subtract(const Duration(days: 7));

      final workouts = List<Map<String, dynamic>>.from(_db['workouts'] ?? []);
      final sets = List<Map<String, dynamic>>.from(_db['sets'] ?? []);
      final exercises = List<Map<String, dynamic>>.from(_db['exercises'] ?? []);

      // Sessions this week
      final sessionsThisWeek = workouts.where((w) {
        if (w['user_id'] != userId) return false;
        final dt = DateTime.parse(w['started_at']).toUtc();
        return !dt.isBefore(monday) && dt.isBefore(nextMonday);
      }).toList();
      final weeklyCount = sessionsThisWeek.length;

      // Favourite exercise (prefer user-chosen, fallback to most-used)
      final prefId = await getPreferredExerciseId();
      _Fav fav;
      if (prefId != null &&
          exercises.any((e) => (e['id'] as num?)?.toInt() == prefId)) {
        final name = (exercises.firstWhere(
          (e) => (e['id'] as num).toInt() == prefId,
        )['name'] ?? '').toString();
        fav = _Fav(prefId, name.isEmpty ? null : name);
      } else {
        fav = _favouriteExerciseBySetCount(
          sets: sets,
          exercises: exercises,
          userId: userId,
        );
      }

      double _avgE1ForRangeForExercise(DateTime start, DateTime end, int exerciseId) {
        final rows = sets.where((s) {
          if (s['user_id'] != userId) return false;
          final dt = DateTime.parse(s['created_at']).toUtc();
          final reps = s['reps'] as num?;
          final weight = s['weight'] as num?;
          final exIdNum = s['exercise_id'] as num?;
          if (reps == null || weight == null || exIdNum == null) return false;
          if (reps <= 0 || reps >= 37 || weight <= 0) return false;
          if (exIdNum.toInt() != exerciseId) return false;
          return !dt.isBefore(start) && dt.isBefore(end);
        }).toList();

        if (rows.isEmpty) return 0.0;
        double sum = 0.0;
        for (final r in rows) {
          final w = (r['weight'] as num).toDouble();
          final reps = (r['reps'] as num).toDouble();
          // Epley: 1RM ≈ w * 36 / (37 - reps)
          final e1 = w * (36.0 / (37.0 - reps));
          if (e1.isFinite) sum += e1;
        }
        return sum / rows.length;
      }

      double delta = 0.0;
      final favName = fav.name ?? '—';
      if (fav.id != null) {
        final favId = fav.id!;
        final avgThis = _avgE1ForRangeForExercise(monday, nextMonday, favId);
        final avgPrev = _avgE1ForRangeForExercise(prevMonday, monday, favId);
        delta = double.parse((avgThis - avgPrev).toStringAsFixed(2));
      }

      // Last session exercises
      final lastWorkout = (workouts.where((w) => w['user_id'] == userId).toList()
        ..sort((a, b) => DateTime.parse(b['started_at'])
            .toUtc()
            .compareTo(DateTime.parse(a['started_at']).toUtc())));

      String lastNames = '—';
      if (lastWorkout.isNotEmpty) {
        final lw = lastWorkout.first;
        final setRows = sets.where((s) => s['workout_id'] == lw['id']).toList();
        final exIds = setRows.map((s) => (s['exercise_id'] as num).toInt()).toSet();
        final names = exercises
            .where((e) => exIds.contains((e['id'] as num).toInt()))
            .map((e) => (e['name'] ?? '').toString())
            .where((n) => n.isNotEmpty)
            .toList();
        if (names.isNotEmpty) lastNames = names.join(', ');
      }

      return HomeStats(weeklyCount, delta, lastNames, favName);
    } catch (e) {
      debugPrint('LocalStore.getHomeStats error: $e');
      return const HomeStats(0, 0.0, '—', '—');
    }
  }

  /// Determine favourite exercise by counting sets (all time) for the user.
  _Fav _favouriteExerciseBySetCount({
    required List<Map<String, dynamic>> sets,
    required List<Map<String, dynamic>> exercises,
    required int userId,
  }) {
    if (sets.isEmpty) return const _Fav(null, null);

    final Map<int, int> counts = {};
    for (final s in sets) {
      if (s['user_id'] != userId) continue;
      final exIdNum = s['exercise_id'] as num?;
      if (exIdNum == null) continue;
      final exId = exIdNum.toInt();
      counts[exId] = (counts[exId] ?? 0) + 1;
    }
    if (counts.isEmpty) return const _Fav(null, null);

    final favEntry = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final favId = favEntry.key;

    final ex = exercises.firstWhere(
      (e) => (e['id'] as num?)?.toInt() == favId,
      orElse: () => const {},
    );
    final name = (ex['name'] ?? '').toString();
    return _Fav(favId, name.isEmpty ? null : name);
  }
}

class _Fav {
  final int? id;
  final String? name;
  const _Fav(this.id, this.name);
}

/// Simple data model for home statistics.
class HomeStats {
  final int weeklySessions;
  final double e1rmDelta;
  final String lastSessionExercises;
  final String favouriteExercise;

  const HomeStats(this.weeklySessions, this.e1rmDelta, this.lastSessionExercises, this.favouriteExercise);

  @override
  String toString() =>
      'HomeStats(weeklySessions: $weeklySessions, e1rmDelta: $e1rmDelta, lastSessionExercises: $lastSessionExercises, favouriteExercise: $favouriteExercise)';
}
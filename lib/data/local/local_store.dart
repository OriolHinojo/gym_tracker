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
            _db = (json.decode(text) as Map).cast<String, dynamic>();
          }
        } catch (e) {
          // Backup bad file and rebuild with mock data
          try {
            final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
            await _file!.rename('${_file!.path}.$ts.bak');
          } catch (_) {}
          _seedMockData();
          await _save();
        }
      }

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
    // On most platforms rename is atomic within the same filesystem.
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
      'version': 1,
      'users': [user],
      'exercises': exercises,
      'workouts': [workout1, workout2, workout3],
      'sets': sets,
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
  // Public APIs for your UI
  // ---------------------------------------------------------------------------

  /// Returns all exercises from the DB.
  Future<List<Map<String, dynamic>>> listExercisesRaw() async {
    await init();
    final rows = List<Map<String, dynamic>>.from(_db['exercises'] ?? const []);
    rows.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return rows;
  }

  /// Returns a single exercise by ID.
  Future<Map<String, dynamic>?> getExerciseRaw(int id) async {
    await init();
    final rows = List<Map<String, dynamic>>.from(_db['exercises'] ?? const []);
    try {
      return rows.firstWhere((e) => e['id'] == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns quick summary stats for home dashboard.
  Future<HomeStats> getHomeStats({int userId = 1}) async {
    await init();
    try {
      // Work with UTC for consistency, then define week boundaries in UTC.
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

      // Average E1RM per range (Epley), filter sanity: reps 1..36, weight>0.
      double avgE1ForRange(DateTime start, DateTime end) {
        final rows = sets.where((s) {
          if (s['user_id'] != userId) return false;
          final dt = DateTime.parse(s['created_at']).toUtc();
          final reps = s['reps'] as num?;
          final weight = s['weight'] as num?;
          if (reps == null || weight == null) return false;
          if (reps <= 0 || reps >= 37 || weight <= 0) return false;
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

      final avgThis = avgE1ForRange(monday, nextMonday);
      final avgPrev = avgE1ForRange(prevMonday, monday);
      final delta = double.parse((avgThis - avgPrev).toStringAsFixed(2));

      // Last session exercises (distinct names in most recent workout)
      final lastWorkout = (workouts.where((w) => w['user_id'] == userId).toList()
        ..sort((a, b) => DateTime.parse(b['started_at'])
            .toUtc()
            .compareTo(DateTime.parse(a['started_at']).toUtc())));

      String lastNames = '—';
      if (lastWorkout.isNotEmpty) {
        final lw = lastWorkout.first;
        final setRows = sets.where((s) => s['workout_id'] == lw['id']).toList();
        final exIds = setRows.map((s) => s['exercise_id'] as int).toSet();
        final names = exercises
            .where((e) => exIds.contains(e['id']))
            .map((e) => (e['name'] ?? '').toString())
            .where((n) => n.isNotEmpty)
            .toList();
        if (names.isNotEmpty) lastNames = names.join(', ');
      }

      return HomeStats(weeklyCount, delta, lastNames);
    } catch (e) {
      debugPrint('LocalStore.getHomeStats error: $e');
      return HomeStats(0, 0.0, '—');
    }
  }
}

/// Simple data model for home statistics.
class HomeStats {
  final int weeklySessions;
  final double e1rmDelta;
  final String lastSessionExercises;

  const HomeStats(this.weeklySessions, this.e1rmDelta, this.lastSessionExercises);

  @override
  String toString() =>
      'HomeStats(weeklySessions: $weeklySessions, e1rmDelta: $e1rmDelta, lastSessionExercises: $lastSessionExercises)';
}

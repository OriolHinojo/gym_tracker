// local_store.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gym_tracker/shared/set_tags.dart';
import 'package:gym_tracker/shared/weight_units.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Lightweight local JSON-based database for the gym tracker demo.
/// Works on Android, iOS, macOS, Windows, and Linux (not Web).
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();
  static const Object _templateIdNotSet = Object();

  File? _file;
  Map<String, dynamic> _db = {};
  Completer<void>? _initComp;
  Directory? _overrideAppDir;

  // Notifier: emits whenever preferred_exercise_id changes (Home listens to this).
  final ValueNotifier<int?> _preferredExerciseId = ValueNotifier<int?>(null);
  ValueListenable<int?> get preferredExerciseIdListenable => _preferredExerciseId;

  // Notifier: emits on weight unit preference changes.
  final ValueNotifier<WeightUnit> _weightUnit = ValueNotifier<WeightUnit>(WeightUnit.kilograms);
  ValueListenable<WeightUnit> get weightUnitListenable => _weightUnit;

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
            _db.putIfAbsent('settings', () => {
                  'preferred_exercise_id': null,
                  'weight_unit': 'kg',
                });
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

    final didEnhanceTemplates = _ensureTemplateMetadata();

    final settings = Map<String, dynamic>.from(_db['settings'] ?? const {});
    bool settingsUpdated = false;
    if (!settings.containsKey('preferred_exercise_id')) {
      settings['preferred_exercise_id'] = null;
      settingsUpdated = true;
    }
    final rawUnit = settings['weight_unit'];
    if (rawUnit is! String || rawUnit.isEmpty) {
      settings['weight_unit'] = 'kg';
      settingsUpdated = true;
    }
    _db['settings'] = settings;

    final pref = settings['preferred_exercise_id'];
    _preferredExerciseId.value = pref == null ? null : (pref as num).toInt();
    _weightUnit.value = WeightUnitX.fromStorage(settings['weight_unit']?.toString());

    if (didEnhanceTemplates || settingsUpdated) {
      await _save();
    }

      _initComp!.complete();
    } catch (e, st) {
      _initComp!.completeError(e, st);
      rethrow;
    }
  }

  /// Returns a writable per-app directory using path_provider.
  Future<Directory> _getAppDir() async {
    final override = _overrideAppDir;
    if (override != null) return override;
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

  bool _ensureTemplateMetadata() {
    bool workoutsUpdated = false;
    bool setsUpdated = false;

    final rawWorkouts = _db['workouts'];
    final workouts = <Map<String, dynamic>>[];
    if (rawWorkouts is List) {
      for (final entry in rawWorkouts) {
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          if (!map.containsKey('template_id')) {
            map['template_id'] = null;
            workoutsUpdated = true;
          } else if (map['template_id'] is num) {
            map['template_id'] = (map['template_id'] as num).toInt();
          }
          workouts.add(map);
        }
      }
      if (workoutsUpdated) {
        _db['workouts'] = workouts;
      }
    }

    final templateByWorkoutId = <int, int?>{
      for (final map in workouts)
        if (map['id'] != null)
          (map['id'] as num).toInt(): (map['template_id'] as num?)?.toInt(),
    };

    final rawSets = _db['sets'];
    if (rawSets is List) {
      final sets = <Map<String, dynamic>>[];
      for (final entry in rawSets) {
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          if (!map.containsKey('template_id')) {
            final wid = (map['workout_id'] as num?)?.toInt();
            map['template_id'] = templateByWorkoutId[wid];
            setsUpdated = true;
          } else if (map['template_id'] is num) {
            map['template_id'] = (map['template_id'] as num).toInt();
          }
          if (!map.containsKey('tag')) {
            map['tag'] = null;
            setsUpdated = true;
          } else {
            final normalized = _normalizeTag(map['tag']);
            if (normalized != map['tag']) {
              map['tag'] = normalized;
              setsUpdated = true;
            }
          }
          sets.add(map);
        }
      }
      if (setsUpdated) {
        _db['sets'] = sets;
      }
    }

    return workoutsUpdated || setsUpdated;
  }

  @visibleForTesting
  void overrideAppDirectory(Directory directory) {
    _overrideAppDir = directory;
  }

  @visibleForTesting
  Future<void> resetForTests({bool deleteFile = false}) async {
    final file = _file;
    _file = null;
    _db = {};
    _initComp = null;
    _preferredExerciseId.value = null;
    _weightUnit.value = WeightUnit.kilograms;
    _overrideAppDir = null;
    if (deleteFile && file != null) {
      try {
        await file.delete(recursive: true);
      } catch (_) {}
    }
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
      {'id': 4, 'name': 'Overhead Press', 'category': 'compound'},
      {'id': 5, 'name': 'Incline Dumbbell Press', 'category': 'accessory'},
      {'id': 6, 'name': 'Dumbbell Fly', 'category': 'accessory'},
      {'id': 7, 'name': 'Tricep Dip', 'category': 'accessory'},
      {'id': 8, 'name': 'Tricep Pushdown', 'category': 'isolation'},
      {'id': 9, 'name': 'Pull-Up', 'category': 'compound'},
      {'id': 10, 'name': 'Barbell Row', 'category': 'compound'},
      {'id': 11, 'name': 'Lat Pulldown', 'category': 'accessory'},
      {'id': 12, 'name': 'Seated Cable Row', 'category': 'accessory'},
      {'id': 13, 'name': 'Bicep Curl', 'category': 'isolation'},
      {'id': 14, 'name': 'Hammer Curl', 'category': 'isolation'},
      {'id': 15, 'name': 'Leg Press', 'category': 'compound'},
      {'id': 16, 'name': 'Bulgarian Split Squat', 'category': 'accessory'},
      {'id': 17, 'name': 'Romanian Deadlift', 'category': 'compound'},
      {'id': 18, 'name': 'Calf Raise', 'category': 'isolation'},
    ];

    _db = {
      'version': 2,
      'settings': {
        'preferred_exercise_id': null,
        'weight_unit': 'kg',
      },
      'users': [user],
      'exercises': exercises,
      // No sessions are pre-seeded; users start with empty history.
      'workouts': <Map<String, dynamic>>[],
      'sets': <Map<String, dynamic>>[],
      // Workout templates (named groups of exercises)
      'workout_templates': <Map<String, dynamic>>[
        {
          'id': 1,
          'name': 'Push Day',
          'exercise_ids': [1, 4, 5, 7, 8],
          'created_at': now.toIso8601String(),
        },
        {
          'id': 2,
          'name': 'Leg Day',
          'exercise_ids': [2, 15, 16, 17, 18],
          'created_at': now.toIso8601String(),
        },
        {
          'id': 3,
          'name': 'Pull Day',
          'exercise_ids': [3, 9, 10, 11, 13],
          'created_at': now.toIso8601String(),
        },
      ],
      'prs': [],
      'body_metrics': [],
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _nextId(List<Map<String, dynamic>> table) {
    if (table.isEmpty) return 1;
    final ids = table.map((e) => (e['id'] as num?)?.toInt() ?? 0).toList()..sort();
    return ids.last + 1;
  }

  String? _normalizeTag(dynamic value) {
    if (value == null) return null;
    final tag = setTagFromStorage(value is String ? value : value.toString());
    return tag?.storage;
  }

  /// Returns the Monday of the week for a UTC [utcNow] instant.
  DateTime _mondayOfWeek(DateTime utcNow) {
    final weekday = utcNow.weekday; // Monday = 1
    final monday = DateTime.utc(utcNow.year, utcNow.month, utcNow.day)
        .subtract(Duration(days: weekday - 1));
    return monday;
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

  /// Returns the sets (ordered by ordinal) from the most recent workout that
  /// includes [exerciseId] for the given [userId].
  Future<List<Map<String, dynamic>>> listLatestSetsForExerciseRaw(
    int exerciseId, {
    int userId = 1,
    int? templateId,
  }) async {
    await init();
    final sets = List<Map<String, dynamic>>.from(_db['sets'] ?? const []);
    final workouts = List<Map<String, dynamic>>.from(_db['workouts'] ?? const []);

    List<Map<String, dynamic>> filtered = sets
        .where((s) {
          final exId = (s['exercise_id'] as num?)?.toInt();
          if (exId != exerciseId) return false;
          final uid = (s['user_id'] as num?)?.toInt();
          return uid == null || uid == userId;
        })
        .map((s) => Map<String, dynamic>.from(s))
        .toList();

    if (filtered.isEmpty) return <Map<String, dynamic>>[];

    final workoutById = <int, Map<String, dynamic>>{
      for (final w in workouts)
        if (w['id'] != null && (w['user_id'] as num?)?.toInt() == userId)
          (w['id'] as num).toInt(): Map<String, dynamic>.from(w),
    };

    if (templateId != null) {
      final templateFiltered = filtered.where((row) {
        final rowTemplate = (row['template_id'] as num?)?.toInt();
        if (rowTemplate != null) return rowTemplate == templateId;
        final wid = (row['workout_id'] as num?)?.toInt();
        final workoutTemplate = (workoutById[wid]?['template_id'] as num?)?.toInt();
        return workoutTemplate == templateId;
      }).toList();
      if (templateFiltered.isEmpty) {
        return listLatestSetsForExerciseRaw(
          exerciseId,
          userId: userId,
        );
      }
      filtered = templateFiltered;
    }

    DateTime bestDateForWorkout(int wid) {
      final workout = workoutById[wid];
      final startedRaw = (workout?['started_at'] ?? '').toString();
      final started = DateTime.tryParse(startedRaw)?.toUtc();
      if (started != null) return started;

      DateTime best = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      for (final row in filtered) {
        if ((row['workout_id'] as num?)?.toInt() != wid) continue;
        final created = DateTime.tryParse((row['created_at'] ?? '').toString())?.toUtc();
        if (created != null && created.isAfter(best)) best = created;
      }
      return best;
    }

    final workoutIds = filtered
        .map((s) => (s['workout_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => bestDateForWorkout(b).compareTo(bestDateForWorkout(a)));

    if (workoutIds.isEmpty) return <Map<String, dynamic>>[];

    final latestId = workoutIds.first;
    final latest = filtered
        .where((s) => (s['workout_id'] as num?)?.toInt() == latestId)
        .toList()
      ..sort((a, b) => ((a['ordinal'] as num?)?.toInt() ?? 0).compareTo((b['ordinal'] as num?)?.toInt() ?? 0));

    return latest.map((s) => Map<String, dynamic>.from(s)).toList();
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

  Future<void> updateExercise({
    required int id,
    required String name,
    required String category,
  }) async {
    await init();
    final list = List<Map<String, dynamic>>.from(_db['exercises'] ?? const []);
    final index = list.indexWhere((e) => (e['id'] as num?)?.toInt() == id);
    if (index == -1) return;
    final existing = Map<String, dynamic>.from(list[index]);
    existing['name'] = name;
    existing['category'] = category;
    list[index] = existing;
    _db['exercises'] = list;
    await _save();
    if (_preferredExerciseId.value == id) {
      _preferredExerciseId.notifyListeners();
    }
  }

  Future<void> deleteExercise(int id) async {
    await init();
    final exercises = List<Map<String, dynamic>>.from(_db['exercises'] ?? const []);
    final before = exercises.length;
    exercises.removeWhere((e) => (e['id'] as num?)?.toInt() == id);
    if (before == exercises.length) return;
    _db['exercises'] = exercises;

    final settings = Map<String, dynamic>.from(_db['settings'] ?? const {});
    final preferred = (settings['preferred_exercise_id'] as num?)?.toInt();
    if (preferred == id) {
      settings['preferred_exercise_id'] = null;
      _preferredExerciseId.value = null;
    }
    _db['settings'] = settings;

    final sets = List<Map<String, dynamic>>.from(_db['sets'] ?? const []);
    sets.removeWhere((s) => (s['exercise_id'] as num?)?.toInt() == id);
    _db['sets'] = sets;

    final templates = List<Map<String, dynamic>>.from(_db['workout_templates'] ?? const []);
    for (final template in templates) {
      final rawIds = (template['exercise_ids'] as List?) ?? const [];
      final filtered = rawIds
          .whereType<num>()
          .map((e) => e.toInt())
          .where((exerciseId) => exerciseId != id)
          .toList();
      template['exercise_ids'] = filtered;
    }
    _db['workout_templates'] = templates;

    await _save();
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

  /// Returns the preferred display unit for weights.
  Future<WeightUnit> getWeightUnit() async {
    await init();
    final settings = Map<String, dynamic>.from(_db['settings'] ?? const {});
    final unit = WeightUnitX.fromStorage(settings['weight_unit']?.toString());
    _weightUnit.value = unit;
    return unit;
  }

  /// Persists and broadcasts the preferred display unit for weights.
  Future<void> setWeightUnit(WeightUnit unit) async {
    await init();
    final settings = Map<String, dynamic>.from(_db['settings'] ?? const {});
    final current = WeightUnitX.fromStorage(settings['weight_unit']?.toString());
    if (current == unit && _weightUnit.value == unit) {
      return;
    }
    settings['weight_unit'] = unit.storageKey;
    _db['settings'] = settings;
    await _save();
    _weightUnit.value = unit;
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

  /// Returns the most recent workouts for the current user (newest first).
  Future<List<Map<String, dynamic>>> listRecentWorkoutsRaw({
    int limit = 10,
    int userId = 1,
  }) async {
    await init();
    final workouts = List<Map<String, dynamic>>.from(_db['workouts'] ?? const [])
        .where((w) => (w['user_id'] as num?)?.toInt() == userId)
        .toList();
    workouts.sort((a, b) {
      final da = DateTime.tryParse((a['started_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse((b['started_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return workouts.take(limit).toList();
  }

  /// Returns all workouts (unsorted copy) for analytics usage.
  Future<List<Map<String, dynamic>>> listWorkoutsRaw() async {
    await init();
    final workouts = List<Map<String, dynamic>>.from(_db['workouts'] ?? const []);
    return workouts
        .map((w) => Map<String, dynamic>.from(w))
        .toList(growable: false);
  }

  /// Returns all sets (unsorted copy) for analytics usage.
  Future<List<Map<String, dynamic>>> listAllSetsRaw() async {
    await init();
    final sets = List<Map<String, dynamic>>.from(_db['sets'] ?? const []);
    return sets
        .map((s) => Map<String, dynamic>.from(s))
        .toList(growable: false);
  }

  /// Raw set rows for a specific workout (sorted by exercise + ordinal).
  Future<List<Map<String, dynamic>>> listSetsForWorkoutRaw(int workoutId) async {
    await init();
    final sets = List<Map<String, dynamic>>.from(_db['sets'] ?? const []);
    final filtered = sets.where((s) => (s['workout_id'] as num?)?.toInt() == workoutId).toList();
    filtered.sort((a, b) {
      final exA = (a['exercise_id'] as num?)?.toInt() ?? 0;
      final exB = (b['exercise_id'] as num?)?.toInt() ?? 0;
      if (exA != exB) return exA.compareTo(exB);
      final ordA = (a['ordinal'] as num?)?.toInt() ?? 0;
      final ordB = (b['ordinal'] as num?)?.toInt() ?? 0;
      return ordA.compareTo(ordB);
    });
    return filtered;
  }

  Future<Map<String, dynamic>?> getWorkoutRaw(int workoutId) async {
    await init();
    final workouts = List<Map<String, dynamic>>.from(_db['workouts'] ?? const []);
    try {
      final row = workouts.firstWhere((w) => (w['id'] as num?)?.toInt() == workoutId);
      return Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteWorkout(int workoutId) async {
    await init();
    final workouts = List<Map<String, dynamic>>.from(_db['workouts'] ?? const [])
      ..removeWhere((w) => (w['id'] as num?)?.toInt() == workoutId);
    final sets = List<Map<String, dynamic>>.from(_db['sets'] ?? const [])
      ..removeWhere((s) => (s['workout_id'] as num?)?.toInt() == workoutId);
    _db['workouts'] = workouts;
    _db['sets'] = sets;
    await _save();
  }

  Future<void> updateWorkout({
    required int workoutId,
    required String name,
    String? notes,
    DateTime? startedAtUtc,
    required List<Map<String, dynamic>> sets,
    Object? templateId = _templateIdNotSet,
  }) async {
    await init();
    final workouts = List<Map<String, dynamic>>.from(_db['workouts'] ?? const []);
    final index = workouts.indexWhere((w) => (w['id'] as num?)?.toInt() == workoutId);
    if (index == -1) {
      throw ArgumentError.value(workoutId, 'workoutId', 'Workout not found');
    }

    final existing = Map<String, dynamic>.from(workouts[index]);
    final userId = (existing['user_id'] as num?)?.toInt() ?? 1;
    final existingStarted =
        DateTime.tryParse((existing['started_at'] ?? '').toString())?.toUtc();
    final started = (startedAtUtc ?? existingStarted ?? DateTime.now().toUtc()).toUtc();

    final updatedNotes = notes ?? (existing['notes'] ?? '');
    final bool templateProvided = templateId != _templateIdNotSet;
    final int? updatedTemplateId =
        templateProvided ? (templateId as int?) : (existing['template_id'] as num?)?.toInt();

    workouts[index] = {
      ...existing,
      'name': name,
      'notes': updatedNotes,
      'started_at': started.toIso8601String(),
      'template_id': updatedTemplateId,
    };

    final allSets = List<Map<String, dynamic>>.from(_db['sets'] ?? const [])
      ..removeWhere((s) => (s['workout_id'] as num?)?.toInt() == workoutId);

    int nextSetId = allSets.isEmpty
        ? 1
        : (allSets
                .map((e) => (e['id'] as num?)?.toInt() ?? 0)
                .reduce((a, b) => a > b ? a : b) +
            1);

    DateTime _resolveCreatedAt(dynamic value) {
      if (value is DateTime) return value.toUtc();
      if (value is String) {
        final parsed = DateTime.tryParse(value)?.toUtc();
        if (parsed != null) return parsed;
      }
      return started;
    }

    for (final s in sets) {
      final exerciseId = (s['exercise_id'] as num?)?.toInt();
      final ordinal = (s['ordinal'] as num?)?.toInt();
      final reps = (s['reps'] as num?)?.toInt();
      final weight = (s['weight'] as num?)?.toDouble();
      if (exerciseId == null || ordinal == null || reps == null || weight == null) continue;
      final createdAt = _resolveCreatedAt(s['created_at']);
      final tag = _normalizeTag(s['tag']);
      allSets.add({
        'id': nextSetId++,
        'workout_id': workoutId,
        'user_id': userId,
        'exercise_id': exerciseId,
        'ordinal': ordinal,
        'reps': reps,
        'weight': weight,
        'created_at': createdAt.toIso8601String(),
        'template_id': updatedTemplateId,
        'tag': tag,
      });
    }

    _db['workouts'] = workouts;
    _db['sets'] = allSets;
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
    int? templateId,
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
      'template_id': templateId,
    });

    int nextSetId = allSets.isEmpty
        ? 1
        : (allSets.map((e) => (e['id'] as num).toInt()).reduce((a, b) => a > b ? a : b) + 1);

    for (final s in sets) {
      final tag = _normalizeTag(s['tag']);
      allSets.add({
        'id': nextSetId++,
        'workout_id': wid,
        'user_id': userId,
        'exercise_id': (s['exercise_id'] as num).toInt(),
        'ordinal': (s['ordinal'] as num).toInt(),
        'reps': (s['reps'] as num).toInt(),
        'weight': (s['weight'] as num).toDouble(),
        'created_at': (s['created_at'] as DateTime? ?? now).toIso8601String(),
        'template_id': templateId,
        'tag': tag,
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

      // Last workout (name + start time)
      final lastWorkout = (workouts.where((w) => w['user_id'] == userId).toList()
        ..sort((a, b) => DateTime.parse(b['started_at'])
            .toUtc()
            .compareTo(DateTime.parse(a['started_at']).toUtc())));

      String lastWorkoutName = '—';
      DateTime? lastWorkoutStartedAt;
      int? lastWorkoutId;
      if (lastWorkout.isNotEmpty) {
        final lw = lastWorkout.first;
        lastWorkoutName = (lw['name'] ?? 'Workout').toString();
        lastWorkoutStartedAt =
            DateTime.tryParse((lw['started_at'] ?? '').toString())?.toUtc();
        final idNum = lw['id'] as num?;
        lastWorkoutId = idNum?.toInt();
      }

      return HomeStats(
        weeklyCount,
        delta,
        lastWorkoutName,
        lastWorkoutStartedAt,
        favName,
        lastWorkoutId: lastWorkoutId,
      );
    } catch (e) {
      debugPrint('LocalStore.getHomeStats error: $e');
      return const HomeStats(0, 0.0, '—', null, '—');
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
  final int? lastWorkoutId;
  final String lastWorkoutName;
  final DateTime? lastWorkoutStartedAt;
  final String favouriteExercise;

  const HomeStats(
    this.weeklySessions,
    this.e1rmDelta,
    this.lastWorkoutName,
    this.lastWorkoutStartedAt,
    this.favouriteExercise, {
    this.lastWorkoutId,
  });

  @override
  String toString() =>
      'HomeStats(weeklySessions: $weeklySessions, e1rmDelta: $e1rmDelta, lastWorkoutId: $lastWorkoutId, lastWorkoutName: $lastWorkoutName, lastWorkoutStartedAt: $lastWorkoutStartedAt, favouriteExercise: $favouriteExercise)';
}

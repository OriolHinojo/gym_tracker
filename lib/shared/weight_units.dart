import 'package:flutter/foundation.dart';

/// Supported weight display units in the app.
enum WeightUnit {
  kilograms,
  pounds,
}

/// Conversion + metadata helpers for [WeightUnit].
extension WeightUnitX on WeightUnit {
  /// Machine-friendly identifier saved in local storage.
  String get storageKey => switch (this) {
        WeightUnit.kilograms => 'kg',
        WeightUnit.pounds => 'lb',
      };

  /// Short label suitable for UI badges, e.g. `kg`.
  String get label => switch (this) {
        WeightUnit.kilograms => 'kg',
        WeightUnit.pounds => 'lb',
      };

  /// Human readable unit name.
  String get displayName => switch (this) {
        WeightUnit.kilograms => 'Kilograms (kg)',
        WeightUnit.pounds => 'Pounds (lb)',
      };

  /// Converts the provided value in kilograms to this unit.
  double fromKilograms(double kilos) => switch (this) {
        WeightUnit.kilograms => kilos,
        WeightUnit.pounds => kilos * 2.20462262185,
      };

  /// Converts the provided value in this unit back to kilograms.
  double toKilograms(double value) => switch (this) {
        WeightUnit.kilograms => value,
        WeightUnit.pounds => value / 2.20462262185,
      };

  /// List of all supported units (stable order for toggles/menus).
  static List<WeightUnit> get valuesOrdered => const [
        WeightUnit.kilograms,
        WeightUnit.pounds,
      ];

  /// Parses a stored string into a [WeightUnit]. Defaults to kilograms.
  static WeightUnit fromStorage(String? raw) {
    if (raw == null) return WeightUnit.kilograms;
    switch (raw) {
      case 'kg':
      case 'kilograms':
        return WeightUnit.kilograms;
      case 'lb':
      case 'lbs':
      case 'pounds':
        return WeightUnit.pounds;
      default:
        debugPrint('Unknown weight unit "$raw", defaulting to kg');
        return WeightUnit.kilograms;
    }
  }
}

/// Formats a weight value stored in kilograms into a compact string with unit.
String formatCompactWeight(double kilos, WeightUnit unit) {
  final converted = unit.fromKilograms(kilos);
  final label = unit.label;
  if (converted >= 1000) {
    return '${(converted / 1000).toStringAsFixed(1)}k $label';
  }
  if (converted >= 100) {
    return '${converted.toStringAsFixed(0)} $label';
  }
  return '${converted.toStringAsFixed(1)} $label';
}

/// Formats a weight stored in kilograms for set displays (no unit suffix).
String formatSetWeight(double kilos, WeightUnit unit) {
  final converted = unit.fromKilograms(kilos);
  if (converted == converted.roundToDouble()) {
    return converted.toInt().toString();
  }
  return converted.toStringAsFixed(1);
}

/// Formats a weight delta stored in kilograms, keeping the sign.
String formatWeightDelta(double kilos, WeightUnit unit) {
  final converted = unit.fromKilograms(kilos);
  final sign = converted >= 0 ? '+' : '';
  final magnitude = converted.abs() >= 10
      ? converted.toStringAsFixed(0)
      : converted.toStringAsFixed(1);
  return '$sign$magnitude';
}

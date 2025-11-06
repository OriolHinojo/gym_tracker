import 'package:flutter/material.dart';

/// Tags that can be assigned to a logged set.
enum SetTag { warmUp, dropSet, amrap }

extension SetTagX on SetTag {
  String get storage {
    switch (this) {
      case SetTag.warmUp:
        return 'warm_up';
      case SetTag.dropSet:
        return 'drop_set';
      case SetTag.amrap:
        return 'amrap';
    }
  }

  String get label {
    switch (this) {
      case SetTag.warmUp:
        return 'Warm-up';
      case SetTag.dropSet:
        return 'Drop set';
      case SetTag.amrap:
        return 'AMRAP';
    }
  }

  IconData get icon {
    switch (this) {
      case SetTag.warmUp:
        return Icons.thermostat;
      case SetTag.dropSet:
        return Icons.trending_down_rounded;
      case SetTag.amrap:
        return Icons.all_inclusive;
    }
  }

  static SetTag? fromStorage(String? value) {
    switch (value) {
      case 'warm_up':
        return SetTag.warmUp;
      case 'drop_set':
        return SetTag.dropSet;
      case 'amrap':
        return SetTag.amrap;
      default:
        return null;
    }
  }
}

/// Helper to safely parse a tag from its persisted string form.
SetTag? setTagFromStorage(String? storage) => SetTagX.fromStorage(storage);

/// Returns the display label for a persisted tag value.
String? setTagLabelFromStorage(String? storage) => setTagFromStorage(storage)?.label;

const List<SetTag> kAvailableSetTags = SetTag.values;


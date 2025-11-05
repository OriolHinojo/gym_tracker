import 'package:flutter/material.dart';

/// Returns an icon that matches the given exercise category.
IconData exerciseCategoryIcon(String? category) {
  switch (category?.toLowerCase().trim()) {
    case 'compound':
      return Icons.fitness_center;
    case 'isolation':
      return Icons.adjust;
    case 'push':
      return Icons.front_hand;
    case 'pull':
      return Icons.back_hand;
    case 'legs':
      return Icons.directions_run;
    case 'core':
      return Icons.sports_martial_arts;
    case 'cardio':
      return Icons.favorite;
    case 'mobility':
      return Icons.self_improvement;
    default:
      return Icons.fitness_center_outlined;
  }
}

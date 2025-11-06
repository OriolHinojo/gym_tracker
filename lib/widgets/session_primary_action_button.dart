import 'package:flutter/material.dart';

/// Primary action used across session previews and detail screens.
class SessionPrimaryActionButton extends StatelessWidget {
  const SessionPrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.edit,
    this.heroTag,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

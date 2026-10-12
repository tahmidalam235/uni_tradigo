import 'package:flutter/material.dart';

/// UserAvatar — a circular avatar that shows the first letter of the
/// user's name on a soft brand background. Used in chat headers,
/// message list rows, item details seller row, and admin user lists.
///
/// Falls back to a person icon if the name is empty.
class UserAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? color;
  final Color? textColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.radius = 18,
    this.color,
    this.textColor,
  });

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    // Use the first non-space character, uppercased. For multi-word
    // names we still pick the first letter; the brand color and shape
    // do the visual work.
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.primary;
    final fg = textColor ?? Colors.white;
    final initial = _initial;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: initial.isEmpty
          ? Icon(Icons.person_rounded, color: fg, size: radius)
          : Text(
              initial,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.9,
                letterSpacing: 0.2,
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

/// Central theme colors that adapt dynamically to Light Mode and Dark Mode.
/// Prevents hardcoded white text on white backgrounds or hardcoded dark cards in light mode.
class AppColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffold(BuildContext context) =>
      isDark(context) ? const Color(0xFF0D0E15) : const Color(0xFFF5F6FA);

  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF161922) : Colors.white;

  static Color cardSubtle(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C202C) : const Color(0xFFF1F3F9);

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF232736) : const Color(0xFFE2E8F0);

  // Primary headings, titles, active labels
  static Color text(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF1B1F2E);

  // Secondary subheadings, captions, sensor units
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF8E92A4) : const Color(0xFF64748B);

  // Muted timestamps, inactive items
  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF636E72) : const Color(0xFF94A3B8);

  // App bar and navigation icons
  static Color icon(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF1B1F2E);

  // Text field / input container backgrounds
  static Color input(BuildContext context) =>
      isDark(context) ? const Color(0xFF0D0E15) : const Color(0xFFF1F5F9);
}

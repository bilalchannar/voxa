import 'package:flutter/material.dart';

/// Central definition of Voxa's brand palette so screens don't hardcode hex
/// values inconsistently.
class AppColors {
  AppColors._();

  /// Primary brand green (deep teal).
  static const Color primary = Color(0xFF075E54);

  /// Secondary brand green.
  static const Color secondary = Color(0xFF128C7E);

  /// Accent / call-to-action green.
  static const Color accent = Color(0xFF25D366);

  // Light theme surfaces & text.
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF111111);
  static const Color secondaryText = Color(0xFF667781);
  static const Color divider = Color(0xFFE9EDEF);
  static const Color lightSectionBackground = Color(0xFFF7F9FA);

  // Dark theme surfaces & text (branded, not a pure-black clone).
  static const Color darkBackground = Color(0xFF0B141A);
  static const Color darkSurface = Color(0xFF111B21);
  static const Color darkElevated = Color(0xFF1F2C33);
  static const Color darkPrimaryText = Color(0xFFE9EDEF);
  static const Color darkSecondaryText = Color(0xFF8696A0);
  static const Color darkDivider = Color(0xFF222E35);

  /// Semantic red used for destructive actions (logout, remove photo).
  static const Color danger = Color(0xFFD32F2F);
}

import 'package:flutter/material.dart';

/// Vibely's original palette — a deep violet/aqua identity, deliberately
/// distinct from TikTok's red/black/white and Reels' gradient branding.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF6C5CE7); // electric violet
  static const Color primaryDark = Color(0xFF4834D4);
  static const Color accent = Color(0xFF00D2C6); // aqua accent
  static const Color secondaryAccent = Color(0xFFFF6B9D); // warm pink for likes

  static const Color darkBackground = Color(0xFF0F0F14);
  static const Color darkSurface = Color(0xFF1A1A22);
  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFE74C3C);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);

  static const Color textPrimaryDark = Color(0xFFF5F5F7);
  static const Color textSecondaryDark = Color(0xFFA0A0AB);
  static const Color textPrimaryLight = Color(0xFF1A1A22);
  static const Color textSecondaryLight = Color(0xFF6B6B76);
}

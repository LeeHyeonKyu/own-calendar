import 'package:flutter/material.dart';

/// Design-system spacing constants based on a 4px base unit.
/// Reference: Fantastical + Google Calendar spacing analysis.
class Spacing {
  Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Typography scale from calendar design research.
/// Inter/system font, sizes in logical pixels.
class AppTypography {
  AppTypography._();

  static const double display = 32;
  static const double h1 = 24;
  static const double h2 = 18;
  static const double h3 = 15;
  static const double body = 14;
  static const double bodySmall = 12;
  static const double caption = 11;

  // Calendar-specific
  static const double dayNumber = 14;
  static const double eventTitle = 13;
  static const double eventTime = 11;
}

/// Border radius scale.
class AppRadius {
  AppRadius._();

  static const double none = 0;
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 9999;
}

/// Semantic colors used across the calendar UI.
/// These are fallback constants; prefer Theme.of(context).colorScheme
/// for surface/text colors.
class AppColors {
  AppColors._();

  // Now line (universal red signal for "now")
  static const Color nowLine = Color(0xFFFF3B30);

  // Weekend header tints
  static const Color sundayText = Color(0xFFE53935);
  static const Color saturdayText = Color(0xFF1E88E5);

  // Task status colors
  static const Color taskPending = Color(0xFFF0A050);
  static const Color taskDone = Color(0xFF4ADE80);
  static const Color taskOverdue = Color(0xFFEF6B6B);

  // Related/linked badge
  static const Color relatedBadge = Color(0xFFA78BFA);

  // Today circle diameter
  static const double todayCircleSize = 28;
}

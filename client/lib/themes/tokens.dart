import 'package:flutter/material.dart';

/// Design tokens for Own Calendar theme system.
///
/// All values are sourced from docs/research/calendar-design-research.md.
/// These tokens are attached to ThemeData as a ThemeExtension so any widget
/// can access them via `Theme.of(context).extension<CalendarThemeTokens>()`.
class CalendarThemeTokens extends ThemeExtension<CalendarThemeTokens> {
  // ── Surfaces ──
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceElevated;

  // ── Text ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // ── Accent ──
  final Color accentPrimary;
  final Color accentToday;
  final Color accentNowLine;

  // ── Grid ──
  final Color gridBorder;
  final Color gridHourLine;
  final Color gridHalfHourLine;

  // ── Event colors (10 colors) ──
  final List<Color> eventColors;

  // ── Spacing (4px base, matching Fantastical) ──
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;
  static const double spacing2xl = 32;
  static const double spacing3xl = 48;

  // ── Border Radius ──
  final double radiusNone;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusFull;

  // ── Shadows ──
  final BoxShadow shadowSm;
  final BoxShadow shadowMd;
  final BoxShadow shadowLg;

  // ── Motion ──
  final Duration durationFast;
  final Duration durationBase;
  final Duration durationSlow;
  final Curve easingSnappy;

  const CalendarThemeTokens({
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentPrimary,
    required this.accentToday,
    required this.accentNowLine,
    required this.gridBorder,
    required this.gridHourLine,
    required this.gridHalfHourLine,
    required this.eventColors,
    this.radiusNone = 0,
    this.radiusSm = 4,
    this.radiusMd = 8,
    this.radiusLg = 12,
    this.radiusXl = 16,
    this.radiusFull = 9999,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    this.durationFast = const Duration(milliseconds: 120),
    this.durationBase = const Duration(milliseconds: 240),
    this.durationSlow = const Duration(milliseconds: 400),
    this.easingSnappy = const Cubic(0.16, 1, 0.3, 1),
  });

  @override
  CalendarThemeTokens copyWith({
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accentPrimary,
    Color? accentToday,
    Color? accentNowLine,
    Color? gridBorder,
    Color? gridHourLine,
    Color? gridHalfHourLine,
    List<Color>? eventColors,
    double? radiusNone,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusFull,
    BoxShadow? shadowSm,
    BoxShadow? shadowMd,
    BoxShadow? shadowLg,
    Duration? durationFast,
    Duration? durationBase,
    Duration? durationSlow,
    Curve? easingSnappy,
  }) {
    return CalendarThemeTokens(
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentToday: accentToday ?? this.accentToday,
      accentNowLine: accentNowLine ?? this.accentNowLine,
      gridBorder: gridBorder ?? this.gridBorder,
      gridHourLine: gridHourLine ?? this.gridHourLine,
      gridHalfHourLine: gridHalfHourLine ?? this.gridHalfHourLine,
      eventColors: eventColors ?? this.eventColors,
      radiusNone: radiusNone ?? this.radiusNone,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusFull: radiusFull ?? this.radiusFull,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
      durationFast: durationFast ?? this.durationFast,
      durationBase: durationBase ?? this.durationBase,
      durationSlow: durationSlow ?? this.durationSlow,
      easingSnappy: easingSnappy ?? this.easingSnappy,
    );
  }

  @override
  CalendarThemeTokens lerp(CalendarThemeTokens? other, double t) {
    if (other is! CalendarThemeTokens) return this;
    return CalendarThemeTokens(
      surfacePrimary: Color.lerp(surfacePrimary, other.surfacePrimary, t)!,
      surfaceSecondary:
          Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentToday: Color.lerp(accentToday, other.accentToday, t)!,
      accentNowLine: Color.lerp(accentNowLine, other.accentNowLine, t)!,
      gridBorder: Color.lerp(gridBorder, other.gridBorder, t)!,
      gridHourLine: Color.lerp(gridHourLine, other.gridHourLine, t)!,
      gridHalfHourLine:
          Color.lerp(gridHalfHourLine, other.gridHalfHourLine, t)!,
      eventColors: _lerpColorList(eventColors, other.eventColors, t),
      radiusNone: _lerpDouble(radiusNone, other.radiusNone, t),
      radiusSm: _lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: _lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: _lerpDouble(radiusLg, other.radiusLg, t),
      radiusXl: _lerpDouble(radiusXl, other.radiusXl, t),
      radiusFull: _lerpDouble(radiusFull, other.radiusFull, t),
      shadowSm: BoxShadow.lerp(shadowSm, other.shadowSm, t)!,
      shadowMd: BoxShadow.lerp(shadowMd, other.shadowMd, t)!,
      shadowLg: BoxShadow.lerp(shadowLg, other.shadowLg, t)!,
      durationFast: t < 0.5 ? durationFast : other.durationFast,
      durationBase: t < 0.5 ? durationBase : other.durationBase,
      durationSlow: t < 0.5 ? durationSlow : other.durationSlow,
      easingSnappy: t < 0.5 ? easingSnappy : other.easingSnappy,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  static List<Color> _lerpColorList(
      List<Color> a, List<Color> b, double t) {
    final length = a.length < b.length ? a.length : b.length;
    return List.generate(length, (i) => Color.lerp(a[i], b[i], t)!);
  }
}

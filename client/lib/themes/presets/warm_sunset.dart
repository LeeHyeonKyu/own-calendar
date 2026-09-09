import 'package:flutter/material.dart';
import '../tokens.dart';

/// Warm, cozy palette theme -- sunset-inspired warmth.
/// Accent: #E07C4F (light) / #F09060 (dark).

const warmSunsetLight = CalendarThemeTokens(
  // Surfaces -- warm ivory tones
  surfacePrimary: Color(0xFFFFF8F0),
  surfaceSecondary: Color(0xFFF5EDE4),
  surfaceElevated: Color(0xFFFFFFFF),
  // Text
  textPrimary: Color(0xE63D2E1F), // warm dark brown
  textSecondary: Color(0x8A3D2E1F),
  textTertiary: Color(0x593D2E1F),
  // Accent
  accentPrimary: Color(0xFFE07C4F),
  accentToday: Color(0xFFD94F3B),
  accentNowLine: Color(0xFFD94F3B),
  // Grid
  gridBorder: Color(0x173D2E1F),
  gridHourLine: Color(0x263D2E1F),
  gridHalfHourLine: Color(0x0F3D2E1F),
  // Event colors -- shifted warm
  eventColors: [
    Color(0xFFC62828), // Warm Red
    Color(0xFFE08A7A), // Warm Coral
    Color(0xFFE65100), // Deep Orange
    Color(0xFFEDA826), // Amber
    Color(0xFF558B2F), // Olive Green
    Color(0xFF00897B), // Warm Teal
    Color(0xFF0277BD), // Warm Blue
    Color(0xFF4527A0), // Deep Indigo
    Color(0xFF7B1FA2), // Warm Purple
    Color(0xFF6D4C41), // Warm Brown
  ],
  // Shadows -- warmer tint
  shadowSm: BoxShadow(
    offset: Offset(0, 1),
    blurRadius: 2,
    color: Color(0x0A3D2E1F),
  ),
  shadowMd: BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 12,
    color: Color(0x143D2E1F),
  ),
  shadowLg: BoxShadow(
    offset: Offset(0, 12),
    blurRadius: 28,
    color: Color(0x1F3D2E1F),
  ),
);

const warmSunsetDark = CalendarThemeTokens(
  // Surfaces -- warm dark brown
  surfacePrimary: Color(0xFF2A1F17),
  surfaceSecondary: Color(0xFF3A2E24),
  surfaceElevated: Color(0xFF3A2E24),
  // Text
  textPrimary: Color(0xDEFFF0E0),
  textSecondary: Color(0x99FFF0E0),
  textTertiary: Color(0x61FFF0E0),
  // Accent
  accentPrimary: Color(0xFFF09060),
  accentToday: Color(0xFFFF6B52),
  accentNowLine: Color(0xFFFF6B52),
  // Grid
  gridBorder: Color(0x1FFFF0E0),
  gridHourLine: Color(0x26FFF0E0),
  gridHalfHourLine: Color(0x0FFFF0E0),
  // Event colors -- boosted for dark
  eventColors: [
    Color(0xFFEF5350), // Warm Red
    Color(0xFFEF9A9A), // Warm Coral
    Color(0xFFFF8A65), // Deep Orange
    Color(0xFFFFCA28), // Amber
    Color(0xFF8BC34A), // Olive Green
    Color(0xFF26A69A), // Warm Teal
    Color(0xFF42A5F5), // Warm Blue
    Color(0xFF7E57C2), // Deep Indigo
    Color(0xFFAB47BC), // Warm Purple
    Color(0xFFA1887F), // Warm Brown
  ],
  // Shadows
  shadowSm: BoxShadow(
    offset: Offset(0, 1),
    blurRadius: 2,
    color: Color(0x33000000),
  ),
  shadowMd: BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 12,
    color: Color(0x4D000000),
  ),
  shadowLg: BoxShadow(
    offset: Offset(0, 12),
    blurRadius: 28,
    color: Color(0x66000000),
  ),
);

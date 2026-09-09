import 'package:flutter/material.dart';
import '../tokens.dart';

/// Google Calendar inspired theme -- clean, minimal, Material Design 3.
/// Accent: #4285F4 (light) / #5B9BF7 (dark).

const googleBlueLight = CalendarThemeTokens(
  // Surfaces
  surfacePrimary: Color(0xFFFFFFFF),
  surfaceSecondary: Color(0xFFF2F2F7),
  surfaceElevated: Color(0xFFFFFFFF),
  // Text
  textPrimary: Color(0xE6000000), // rgba(0,0,0,0.9)
  textSecondary: Color(0x8A000000), // rgba(0,0,0,0.54)
  textTertiary: Color(0x59000000), // rgba(0,0,0,0.35)
  // Accent
  accentPrimary: Color(0xFF4285F4),
  accentToday: Color(0xFFFF3B30),
  accentNowLine: Color(0xFFFF3B30),
  // Grid
  gridBorder: Color(0x17000000), // rgba(0,0,0,0.09)
  gridHourLine: Color(0x26000000), // rgba(0,0,0,0.15)
  gridHalfHourLine: Color(0x0F000000), // rgba(0,0,0,0.06)
  // Event colors
  eventColors: [
    Color(0xFFD50000), // Red
    Color(0xFFE67C73), // Coral
    Color(0xFFF4511E), // Orange
    Color(0xFFF6BF26), // Yellow
    Color(0xFF33B679), // Green
    Color(0xFF009688), // Teal
    Color(0xFF039BE5), // Blue
    Color(0xFF3F51B5), // Indigo
    Color(0xFF8E24AA), // Purple
    Color(0xFF616161), // Gray
  ],
  // Shadows
  shadowSm: BoxShadow(
    offset: Offset(0, 1),
    blurRadius: 2,
    color: Color(0x0A000000), // rgba(0,0,0,0.04)
  ),
  shadowMd: BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 12,
    color: Color(0x14000000), // rgba(0,0,0,0.08)
  ),
  shadowLg: BoxShadow(
    offset: Offset(0, 12),
    blurRadius: 28,
    color: Color(0x1F000000), // rgba(0,0,0,0.12)
  ),
);

const googleBlueDark = CalendarThemeTokens(
  // Surfaces
  surfacePrimary: Color(0xFF1C1C1E),
  surfaceSecondary: Color(0xFF2C2C2E),
  surfaceElevated: Color(0xFF2C2C2E),
  // Text
  textPrimary: Color(0xDEFFFFFF), // rgba(255,255,255,0.87)
  textSecondary: Color(0x99FFFFFF), // rgba(255,255,255,0.60)
  textTertiary: Color(0x61FFFFFF), // rgba(255,255,255,0.38)
  // Accent
  accentPrimary: Color(0xFF5B9BF7),
  accentToday: Color(0xFFFF453A),
  accentNowLine: Color(0xFFFF453A),
  // Grid
  gridBorder: Color(0x1FFFFFFF), // rgba(255,255,255,0.12)
  gridHourLine: Color(0x26FFFFFF), // rgba(255,255,255,0.15)
  gridHalfHourLine: Color(0x0FFFFFFF), // rgba(255,255,255,0.06)
  // Event colors (dark: saturation +20%, lightness +10%)
  eventColors: [
    Color(0xFFE53935), // Red
    Color(0xFFEF9A9A), // Coral
    Color(0xFFFF7043), // Orange
    Color(0xFFFFCA28), // Yellow
    Color(0xFF4CAF50), // Green
    Color(0xFF26A69A), // Teal
    Color(0xFF42A5F5), // Blue
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFAB47BC), // Purple
    Color(0xFF9E9E9E), // Gray
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

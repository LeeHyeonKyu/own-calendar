import 'package:flutter/material.dart';
import '../tokens.dart';

/// Fresh, nature-inspired theme -- cool-toned, calming.
/// Accent: #009688 (light) / #26A69A (dark).

const oceanTealLight = CalendarThemeTokens(
  // Surfaces -- cool, slightly blue-tinted
  surfacePrimary: Color(0xFFF5F9FA),
  surfaceSecondary: Color(0xFFE8F0F2),
  surfaceElevated: Color(0xFFFFFFFF),
  // Text
  textPrimary: Color(0xE6172B30),
  textSecondary: Color(0x8A172B30),
  textTertiary: Color(0x59172B30),
  // Accent
  accentPrimary: Color(0xFF009688),
  accentToday: Color(0xFFE64A19),
  accentNowLine: Color(0xFFE64A19),
  // Grid
  gridBorder: Color(0x17172B30),
  gridHourLine: Color(0x26172B30),
  gridHalfHourLine: Color(0x0F172B30),
  // Event colors -- cool-toned palette
  eventColors: [
    Color(0xFFD32F2F), // Red
    Color(0xFFE57373), // Coral
    Color(0xFFFF7043), // Orange
    Color(0xFFFDD835), // Yellow
    Color(0xFF43A047), // Green
    Color(0xFF00897B), // Teal
    Color(0xFF0288D1), // Blue
    Color(0xFF3949AB), // Indigo
    Color(0xFF8E24AA), // Purple
    Color(0xFF607D8B), // Blue Gray
  ],
  // Shadows
  shadowSm: BoxShadow(
    offset: Offset(0, 1),
    blurRadius: 2,
    color: Color(0x0A172B30),
  ),
  shadowMd: BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 12,
    color: Color(0x14172B30),
  ),
  shadowLg: BoxShadow(
    offset: Offset(0, 12),
    blurRadius: 28,
    color: Color(0x1F172B30),
  ),
);

const oceanTealDark = CalendarThemeTokens(
  // Surfaces -- deep ocean dark
  surfacePrimary: Color(0xFF0F1E21),
  surfaceSecondary: Color(0xFF1A2D31),
  surfaceElevated: Color(0xFF1A2D31),
  // Text
  textPrimary: Color(0xDEE0F0F2),
  textSecondary: Color(0x99E0F0F2),
  textTertiary: Color(0x61E0F0F2),
  // Accent
  accentPrimary: Color(0xFF26A69A),
  accentToday: Color(0xFFFF7043),
  accentNowLine: Color(0xFFFF7043),
  // Grid
  gridBorder: Color(0x1FE0F0F2),
  gridHourLine: Color(0x26E0F0F2),
  gridHalfHourLine: Color(0x0FE0F0F2),
  // Event colors -- boosted for dark
  eventColors: [
    Color(0xFFEF5350), // Red
    Color(0xFFEF9A9A), // Coral
    Color(0xFFFF8A65), // Orange
    Color(0xFFFFEE58), // Yellow
    Color(0xFF66BB6A), // Green
    Color(0xFF26A69A), // Teal
    Color(0xFF42A5F5), // Blue
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFAB47BC), // Purple
    Color(0xFF90A4AE), // Blue Gray
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

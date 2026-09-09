import 'package:flutter/material.dart';
import '../tokens.dart';

/// Timepage/Apple inspired monochromatic theme -- very muted, elegant.
/// Accent: #333333 (light) / #E0E0E0 (dark).
/// Event differentiation through opacity, not vivid colors.

const minimalMonoLight = CalendarThemeTokens(
  // Surfaces
  surfacePrimary: Color(0xFFFAFAFA),
  surfaceSecondary: Color(0xFFF0F0F0),
  surfaceElevated: Color(0xFFFFFFFF),
  // Text
  textPrimary: Color(0xE6222222),
  textSecondary: Color(0x8A222222),
  textTertiary: Color(0x59222222),
  // Accent -- monochromatic, near-black
  accentPrimary: Color(0xFF333333),
  accentToday: Color(0xFF333333),
  accentNowLine: Color(0xFF888888),
  // Grid
  gridBorder: Color(0x12000000),
  gridHourLine: Color(0x1A000000),
  gridHalfHourLine: Color(0x0A000000),
  // Event colors -- muted, opacity-based differentiation
  eventColors: [
    Color(0xFF8C8C8C), // Gray 1
    Color(0xFF6B6B6B), // Gray 2
    Color(0xFFA3A3A3), // Gray 3
    Color(0xFF787878), // Gray 4
    Color(0xFF5A5A5A), // Gray 5
    Color(0xFF999999), // Gray 6
    Color(0xFF4A4A4A), // Gray 7
    Color(0xFFB0B0B0), // Gray 8
    Color(0xFF686868), // Gray 9
    Color(0xFFC0C0C0), // Gray 10
  ],
  // Shadows -- very subtle
  shadowSm: BoxShadow(
    offset: Offset(0, 1),
    blurRadius: 2,
    color: Color(0x08000000),
  ),
  shadowMd: BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 12,
    color: Color(0x0D000000),
  ),
  shadowLg: BoxShadow(
    offset: Offset(0, 12),
    blurRadius: 28,
    color: Color(0x14000000),
  ),
);

const minimalMonoDark = CalendarThemeTokens(
  // Surfaces
  surfacePrimary: Color(0xFF161616),
  surfaceSecondary: Color(0xFF232323),
  surfaceElevated: Color(0xFF232323),
  // Text
  textPrimary: Color(0xDEE0E0E0),
  textSecondary: Color(0x99E0E0E0),
  textTertiary: Color(0x61E0E0E0),
  // Accent -- light gray on dark
  accentPrimary: Color(0xFFE0E0E0),
  accentToday: Color(0xFFE0E0E0),
  accentNowLine: Color(0xFF888888),
  // Grid
  gridBorder: Color(0x12FFFFFF),
  gridHourLine: Color(0x1AFFFFFF),
  gridHalfHourLine: Color(0x0AFFFFFF),
  // Event colors -- slightly lighter grays for dark
  eventColors: [
    Color(0xFFA0A0A0), // Gray 1
    Color(0xFF8A8A8A), // Gray 2
    Color(0xFFB8B8B8), // Gray 3
    Color(0xFF959595), // Gray 4
    Color(0xFF7A7A7A), // Gray 5
    Color(0xFFADADAD), // Gray 6
    Color(0xFF6A6A6A), // Gray 7
    Color(0xFFC8C8C8), // Gray 8
    Color(0xFF858585), // Gray 9
    Color(0xFFD5D5D5), // Gray 10
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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/tokens.dart';
import '../themes/presets/google_blue.dart';
import '../themes/presets/warm_sunset.dart';
import '../themes/presets/minimal_mono.dart';
import '../themes/presets/ocean_teal.dart';

/// Preset metadata used by the theme picker UI.
class ThemePresetInfo {
  final String id;
  final String name;
  final CalendarThemeTokens light;
  final CalendarThemeTokens dark;

  const ThemePresetInfo({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
  });
}

/// All available theme presets.
const List<ThemePresetInfo> themePresets = [
  ThemePresetInfo(
    id: 'google_blue',
    name: 'Google Blue',
    light: googleBlueLight,
    dark: googleBlueDark,
  ),
  ThemePresetInfo(
    id: 'warm_sunset',
    name: 'Warm Sunset',
    light: warmSunsetLight,
    dark: warmSunsetDark,
  ),
  ThemePresetInfo(
    id: 'minimal_mono',
    name: 'Minimal Mono',
    light: minimalMonoLight,
    dark: minimalMonoDark,
  ),
  ThemePresetInfo(
    id: 'ocean_teal',
    name: 'Ocean Teal',
    light: oceanTealLight,
    dark: oceanTealDark,
  ),
];

class ThemeProvider extends ChangeNotifier {
  static const _presetKey = 'theme_preset';
  static const _modeKey = 'theme_mode';

  String _currentPreset = 'google_blue';
  ThemeMode _themeMode = ThemeMode.system;

  String get currentPreset => _currentPreset;
  ThemeMode get themeMode => _themeMode;

  ThemeData get lightTheme => _buildTheme(Brightness.light);
  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  /// Load persisted preferences. Call once at app startup.
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _currentPreset = prefs.getString(_presetKey) ?? 'google_blue';
    final modeIndex = prefs.getInt(_modeKey);
    if (modeIndex != null && modeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[modeIndex];
    }
    notifyListeners();
  }

  void setPreset(String presetName) {
    if (_currentPreset == presetName) return;
    _currentPreset = presetName;
    notifyListeners();
    _persist();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, _currentPreset);
    await prefs.setInt(_modeKey, _themeMode.index);
  }

  ThemePresetInfo get _presetInfo =>
      themePresets.firstWhere(
        (p) => p.id == _currentPreset,
        orElse: () => themePresets.first,
      );

  CalendarThemeTokens _tokensFor(Brightness brightness) =>
      brightness == Brightness.light ? _presetInfo.light : _presetInfo.dark;

  ThemeData _buildTheme(Brightness brightness) {
    final tokens = _tokensFor(brightness);
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.accentPrimary,
      brightness: brightness,
      surface: tokens.surfacePrimary,
    );

    // Typography scale from research:
    // Display 32/700, H1 24/700, H2 18/600, H3 15/600,
    // Body 14/400, BodySmall 12/400, Caption 11/500
    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: tokens.textPrimary,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: tokens.textPrimary,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: tokens.textPrimary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: tokens.textPrimary,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: tokens.textSecondary,
        height: 1.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: tokens.textTertiary,
        height: 1.4,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.surfacePrimary,
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surfacePrimary,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: tokens.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          side: BorderSide(color: tokens.gridBorder),
        ),
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.surfacePrimary,
        selectedItemColor: tokens.accentPrimary,
        unselectedItemColor: tokens.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // NavigationBar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surfacePrimary,
        indicatorColor: tokens.accentPrimary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.accentPrimary,
        foregroundColor: isLight ? Colors.white : Colors.black,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusFull),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: tokens.gridBorder,
        thickness: 1,
        space: 0,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        textColor: tokens.textPrimary,
        iconColor: tokens.textSecondary,
      ),

      // Extensions
      extensions: [tokens],
    );
  }
}

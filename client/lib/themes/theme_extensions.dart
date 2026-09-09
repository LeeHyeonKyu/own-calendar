import 'package:flutter/material.dart';
import 'tokens.dart';

/// Convenience extension to access [CalendarThemeTokens] from [BuildContext].
///
/// Usage: `context.tokens.accentPrimary`
extension ThemeTokens on BuildContext {
  CalendarThemeTokens get tokens =>
      Theme.of(this).extension<CalendarThemeTokens>()!;
}

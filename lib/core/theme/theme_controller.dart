import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../services/settings_service.dart';

/// App-wide theme state.
///
/// The project uses no external state-management package, so this is a simple
/// global [ChangeNotifier]. `main.dart` listens to it with a
/// [ListenableBuilder] and rebuilds [MaterialApp] when the mode changes, so the
/// Appearance screen produces a real, immediate theme change.
///
/// The chosen mode is persisted to `users/{uid}/settings/appearance` so it
/// survives restarts and follows the account across devices.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  /// Single shared instance used by `main.dart` and the Appearance screen.
  static final ThemeController instance = ThemeController._();

  final SettingsService _settingsService = SettingsService();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Apply a mode locally (immediate UI update) and persist it best-effort.
  ///
  /// The UI updates even if the write fails so the user is never blocked by a
  /// transient network error; the persistence error is surfaced to the caller
  /// so it can show a message if desired.
  Future<void> setThemeMode(ThemeMode mode, {bool persist = true}) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
    if (persist) {
      await _settingsService.saveThemeMode(
        AppearanceSettings.themeModeToString(mode),
      );
    }
  }

  /// Load the persisted mode for the current user (called after sign-in and on
  /// app start). Silently keeps the current mode if nothing is stored.
  Future<void> loadForCurrentUser() async {
    final stored = await _settingsService.loadThemeMode();
    if (stored == null) return;
    final mode = AppearanceSettings.themeModeFromString(stored);
    if (mode != _themeMode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  /// Reset to the default on sign-out so the next user doesn't inherit the
  /// previous account's theme before their own settings load.
  void resetToDefault() {
    if (_themeMode != ThemeMode.system) {
      _themeMode = ThemeMode.system;
      notifyListeners();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's explicit theme preference. `system` follows the OS
/// setting; the two literals override it.
///
/// The default is `dark` to match the web app's `:root` selector,
/// which is the dark theme unless `body[data-theme="light"]` is
/// explicitly set.
enum AppThemeMode {
  light,
  dark,
  system,
}

/// `ChangeNotifier` that owns the current theme mode and bridges it
/// to a persistent store via `shared_preferences`.
///
/// Why `shared_preferences` and not `flutter_secure_storage`:
/// the theme preference is non-sensitive (a UI accent, not a token),
/// and `shared_preferences` is the right tool for "small, primitive,
/// app-local user preference" — the documented use case. The secure
/// store is reserved for what it's good for (secrets, credentials).
class ThemeProvider extends ChangeNotifier {
  /// Stable key used in `SharedPreferences`. Bumping the value would
  /// silently invalidate any persisted choice from a previous app
  /// version; if we ever need a migration, bump the key (e.g.
  /// `'theme_mode_v2'`) and fall back to the default.
  static const String _prefKey = 'theme_mode';

  /// Current theme mode. Defaults to [AppThemeMode.dark] per the spec
  /// (matches the web app's default). The actual persisted value is
  /// loaded lazily by [loadSavedMode] on app startup; until then this
  /// holds the default.
  AppThemeMode mode = AppThemeMode.dark;

  /// Maps the app's three-state [AppThemeMode] to Flutter's
  /// two-and-a-half-state [ThemeMode]:
  ///   * [AppThemeMode.light]   → [ThemeMode.light]
  ///   * [AppThemeMode.dark]    → [ThemeMode.dark]
  ///   * [AppThemeMode.system]  → [ThemeMode.system]
  ///
  /// Pass directly to `MaterialApp.themeMode`.
  ThemeMode get flutterThemeMode {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Loads the persisted theme choice from `SharedPreferences`.
  ///
  /// Called once at app startup (mirroring `AuthProvider.loadSavedMode`
  /// / `..tryAutoLogin()`) — `NutriMindApp`'s `build` then picks up
  /// the loaded value via `context.watch<ThemeProvider>().flutterThemeMode`.
  ///
  /// If nothing is persisted (fresh install / never set), the default
  /// [AppThemeMode.dark] is kept. If the persisted value is unrecognised
  /// for any reason (e.g. a stale key from a previous app version),
  /// we fall back to the default too — silently, the way the rest of
  /// the app's preferences handle unknown values.
  Future<void> loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return;
      final parsed = AppThemeMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => AppThemeMode.dark,
      );
      if (parsed != mode) {
        mode = parsed;
        notifyListeners();
      }
    } catch (_) {
      // Storage failures (rare on iOS / Android) shouldn't block the
      // app from running. The default already in memory is fine.
    }
  }

  /// Updates the mode, notifies listeners so the UI rebuilds, and
  /// persists the new choice. Persistence failures are swallowed
  /// silently — the in-memory change is still reflected in the current
  /// session, and a fresh app start will fall back to the last
  /// successfully-persisted value.
  Future<void> setMode(AppThemeMode newMode) async {
    if (newMode == mode) return;
    mode = newMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newMode.name);
    } catch (_) {
      // No-op: see comment above.
    }
  }
}

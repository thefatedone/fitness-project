import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The languages the app currently ships with.
///
/// Ordered roughly by adoption for the target audience; the
/// rendered label uses each language's native name (English,
/// ქართული, Русский) so the segment buttons are always
/// self-explanatory regardless of the active locale.
enum AppLocale {
  en,
  ka,
  ru,
}

/// `ChangeNotifier` that owns the currently-active app locale and
/// bridges it to a persistent store via `shared_preferences`.
///
/// Mirrors [ThemeProvider]'s shape (single-value `ChangeNotifier`,
/// `loadSavedXxx()` on app startup, `setXxx()` to update + persist)
/// so the two preference flows behave identically to the user —
/// and so future code that needs to read the locale (e.g. a
/// number-formatter helper) can find the same idiomatic API
/// surface it already uses for theme mode.
class LocaleProvider extends ChangeNotifier {
  /// Stable key used in `SharedPreferences`. Bumping the value
  /// would silently invalidate any persisted choice from a
  /// previous app version; if we ever need a migration, bump
  /// the key (e.g. `'app_locale_v2'`) and fall back to the
  /// default.
  static const String _prefKey = 'app_locale';

  /// Current locale. Defaults to [AppLocale.ru] to match the
  /// app's existing Russian-only UI — until the user picks a
  /// different language, the app's locale is Russian and Flutter's
  /// built-in widgets (DatePicker, dialog buttons) render in
  /// Russian via `flutter_localizations`. The persisted choice
  /// is loaded lazily by [loadSavedLocale] at app startup;
  /// until that completes, this holds the default.
  AppLocale locale = AppLocale.ru;

  /// Maps the app's [AppLocale] to Flutter's [Locale] for
  /// `MaterialApp.locale`. We don't carry a country code — the
  /// app doesn't currently differentiate en-US vs en-GB or
  /// ru-RU vs ru-BY; if a future requirement wants that, add
  /// it as a per-enum-value field rather than mapping
  /// unconditionally here.
  Locale get flutterLocale {
    switch (locale) {
      case AppLocale.en:
        return const Locale('en');
      case AppLocale.ka:
        return const Locale('ka');
      case AppLocale.ru:
        return const Locale('ru');
    }
  }

  /// Loads the persisted locale from `SharedPreferences`.
  ///
  /// Called once at app startup (mirroring
  /// [ThemeProvider.loadSavedMode]) — `_NutriMindAppShell`'s build
  /// then picks up the loaded value via
  /// `context.watch<LocaleProvider>().flutterLocale`.
  ///
  /// If nothing is persisted (fresh install / never set), the
  /// default [AppLocale.ru] is kept. If the persisted value is
  /// unrecognised for any reason (e.g. a stale key from a
  /// previous app version with a renamed enum case), we fall
  /// back to the default too — silently, the way the rest of the
  /// app's preferences handle unknown values.
  Future<void> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return;
      final parsed = AppLocale.values.firstWhere(
        (l) => l.name == raw,
        orElse: () => AppLocale.ru,
      );
      if (parsed != locale) {
        locale = parsed;
        notifyListeners();
      }
    } catch (_) {
      // Storage failures (rare on iOS / Android) shouldn't block
      // the app from running. The default already in memory is
      // fine.
    }
  }

  /// Updates the locale, notifies listeners so the UI rebuilds
  /// (and `MaterialApp.locale` propagates the new value), and
  /// persists the new choice. Persistence failures are swallowed
  /// silently — the in-memory change is still reflected in the
  /// current session, and a fresh app start will fall back to
  /// the last successfully-persisted value.
  Future<void> setLocale(AppLocale newLocale) async {
    if (newLocale == locale) return;
    locale = newLocale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newLocale.name);
    } catch (_) {
      // No-op: see comment above.
    }
  }
}

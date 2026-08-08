import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import 'app_config.dart';

/// Debug-only source of truth for the *currently-active* API base URL
/// used by the shared `Dio` client.
///
/// Bridges two things:
///
///   * The compile-time `AppConfig.environment` switch — the original
///     "edit-then-rebuild" baseline every other piece of code already
///     depends on.
///   * A user-settable override stored in [SharedPreferences], read by
///     [loadSaved] and written by [setOverride]. Sourced from the
///     in-app Settings screen's [kDebugMode]-only API switcher.
///
/// The override, once applied, is pushed directly into
/// `apiClient.dio.options.baseUrl` — Dio permits mutating `baseUrl`
/// on an existing instance, so the new environment takes effect on
/// the *very next* outbound request without re-instantiating the
/// client or restarting the app.
///
/// What "takes effect on the next request" means in practice:
/// already-loaded screens keep whatever data they fetched under the
/// previous URL; the user has to pull-to-refresh or navigate away
/// and back to see the new URL reflected. The Settings screen
/// surfaces this caveat in the post-change SnackBar so the user
/// isn't left wondering why a freshly-tapped screen still looks
/// "old".
///
/// Why a separate provider rather than extending [ThemeProvider]?
/// Settings UI may want to watch both independently, and the
/// persistence semantics differ (ThemeProvider is a tri-state
/// enum + a single key; this is a nullable string keyed on a
/// different path).
class ApiEnvironmentProvider extends ChangeNotifier {
  /// `SharedPreferences` key for the persisted override. Exposed as
  /// a constant so a future "force reset" debug action can remove
  /// it directly without re-importing this file's internals.
  static const String prefsKey = 'api_base_url_override';

  /// The currently-active override URL as a user-set value (no
  /// `/api/v1` appended, regardless of how the user typed it).
  /// `null` means "use the compile-time default".
  String? customUrl;

  /// Loads any previously-saved override from [SharedPreferences]
  /// and applies it to both [AppConfig] and the live `Dio`
  /// instance.
  ///
  /// Called from the [MultiProvider] create lambda at app boot —
  /// `fire-and-forget` is safe here because the Settings screen
  /// just renders whatever [effectiveUrl] says (the compile-time
  /// default while [SharedPreferences] drains, the override once
  /// it has). On a cold start with no saved override, the call is
  /// a no-op apart from the `notifyListeners` (which is then
  /// immediately followed by a real change on a later
  /// `setOverride`).
  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsKey);
    customUrl = (saved == null || saved.trim().isEmpty) ? null : saved.trim();
    AppConfig.setRuntimeOverride(customUrl);
    // Re-apply so the live `Dio` instance matches. `ApiClient`'s
    // constructor already set `baseUrl` to the compile-time
    // default at build time; this line overrides it with whatever
    // [AppConfig.apiBaseUrl] now resolves to (with the override
    // applied, if any).
    apiClient.dio.options.baseUrl = AppConfig.apiBaseUrl;
    notifyListeners();
  }

  /// Sets or clears the runtime API base URL override.
  ///
  /// [url] semantics:
  ///   * `null` or whitespace-only → clear override, fall back to
  ///     the compile-time [AppConfig.environment] switch. The
  ///     SharedPreferences entry is *removed* (not stored as `""`)
  ///     so the next `loadSaved` is a clean no-op.
  ///   * starts with `http://` or `https://` → treat as the new
  ///     override. Persisted to SharedPreferences and pushed into
  ///     `apiClient.dio.options.baseUrl` via [AppConfig].
  ///   * anything else (notably: not `http(s)`, or contains
  ///     typos that no real URL would have) → ignored: a
  ///     [debugPrint] is emitted and no state changes (no
  ///     `notifyListeners`, no Dio mutation). The Settings UI's
  ///     form validator already catches most invalid input, so
  ///     this branch is a belt-and-braces for any caller that
  ///     skips validation.
  Future<void> setOverride(String? url) async {
    String? normalized;
    if (url != null) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty) {
        if (!trimmed.startsWith('http://') &&
            !trimmed.startsWith('https://')) {
          debugPrint(
            'ApiEnvironmentProvider.setOverride: rejected non-http(s) '
            'value "$url" — leaving existing override unchanged.',
          );
          return;
        }
        normalized = trimmed;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setString(prefsKey, normalized);
    }
    customUrl = normalized;
    AppConfig.setRuntimeOverride(normalized);
    // Re-point the live `Dio` so the change applies to subsequent
    // requests. Already-in-flight requests keep their captured
    // URL — they don't get re-routed mid-flight.
    apiClient.dio.options.baseUrl = AppConfig.apiBaseUrl;
    notifyListeners();
  }

  /// What's actually being used right now. Resolved through
  /// [AppConfig.apiBaseUrl] (so the `/api/v1` suffix logic
  /// happens in exactly one place) rather than re-implementing
  /// it here. The Settings UI's "Текущий URL" card reads this
  /// for display.
  String get effectiveUrl => AppConfig.apiBaseUrl;
}

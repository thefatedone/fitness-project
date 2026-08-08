/// Compile-time environment selector for the NutriMind mobile app.
///
/// Resolves the API base URL based on where the app is being run. The same
/// compiled binary can be reused across development on a real device, on an
/// Android emulator, and in production by toggling [AppConfig.environment].
///
/// Since the `1.0.0+1` build that introduced [ApiEnvironmentProvider],
/// [AppConfig.apiBaseUrl] is *also* runtime-overridable — see
/// [setRuntimeOverride]. The compile-time switch below remains the
/// authoritative fallback used by all callers when no override has been
/// set, so nothing in the rest of the app needs to know about runtime
/// overrides to stay correct.
library;

/// All known runtime environments the app can be built for.
enum Environment {
  /// Local development on macOS / Linux / Windows where the FastAPI backend is
  /// reached directly over loopback.
  dev,

  /// Local development on the Android emulator. The emulator runs in a NAT'd
  /// network where `localhost`/`127.0.0.1` resolves to the emulator itself,
  /// NOT to the host machine. Android exposes a special alias — `10.0.2.2` —
  /// that the emulator maps to the host's loopback interface, so any request
  /// to `http://10.0.2.2:8000` from inside the emulator lands on the
  /// developer's host machine. The iOS Simulator does not have this quirk: it
  /// shares the host's network stack, so `localhost` works the same as on the
  /// host. Hence two separate dev flavors.
  devAndroidEmulator,

  /// Live production deployment. Replace [Environment.production]'s URL in
  /// [AppConfig.apiBaseUrl] with the real Railway URL once the backend is
  /// published.
  production,
}

/// Static configuration container.
///
/// Single responsibility: answer "what environment am I running in, and where
/// is the API?". Centralizing the URL here means screens, repositories, and
/// the HTTP client all read from one source of truth — no scattered strings,
/// no guessing which host a request was meant to hit.
class AppConfig {
  /// Active environment. Change this constant (or wire it to a `--dart-define`
  /// flag) when building for a different target.
  static const Environment environment = Environment.dev;

  /// Runtime override of [apiBaseUrl], settable at runtime via
  /// [setRuntimeOverride] for the in-app, debug-only API-environment
  /// switcher ([ApiEnvironmentProvider]).
  ///
  /// `null` (the default) means "use the compile-time [environment]
  /// switch below" — the original behaviour the rest of the app was
  /// written against. Non-null means "always return this value
  /// (with the `/api/v1` auto-append handled by [apiBaseUrl])".
  static String? _runtimeOverrideUrl;

  /// Sets or clears the runtime API base URL override.
  ///
  /// Called by [ApiEnvironmentProvider] when the user picks a
  /// different environment from the debug-only Settings switcher;
  /// direct callers outside the provider are unlikely.
  ///
  /// Whitespace-only [url] (and any value whose `.trim()` becomes
  /// empty) is treated as a *clear* — same as passing `null`. This
  /// lets the UI pass through whatever its "reset to default"
  /// control produces without an extra null-check at every call
  /// site, and it means a stray " " from a copy-paste doesn't end up
  /// stored as the active URL.
  static void setRuntimeOverride(String? url) {
    if (url == null) {
      _runtimeOverrideUrl = null;
      return;
    }
    final trimmed = url.trim();
    _runtimeOverrideUrl = trimmed.isEmpty ? null : trimmed;
  }

  /// Base URL of the FastAPI backend, suffixed with the API version
  /// prefix.
  ///
  /// Lookup order:
  ///   1. Runtime override ([setRuntimeOverride]), if non-null —
  ///      the in-app, debug-only override. If the override does
  ///      NOT end with `/api/v1`, this getter appends it —
  ///      choosing "forgiving" because the most likely misuse is
  ///      a user typing a bare base like
  ///      `http://192.168.1.23:8000` for a phone on the local
  ///      network, where requiring the user to ALSO remember the
  ///      `/api/v1` suffix would be a footgun. Both forms round-
  ///      trip cleanly: passing `http://localhost:8000/api/v1`
  ///      returns `http://localhost:8000/api/v1` (the
  ///      `endsWith` check passes), and passing
  ///      `http://localhost:8000` returns
  ///      `http://localhost:8000/api/v1`.
  ///   2. The compile-time [environment] switch below — the
  ///      original "edit-then-rebuild" flow. Unchanged.
  static String get apiBaseUrl {
    final override = _runtimeOverrideUrl;
    if (override != null) {
      return override.endsWith('/api/v1') ? override : '$override/api/v1';
    }
    switch (environment) {
      case Environment.dev:
        return 'http://localhost:8000/api/v1';
      case Environment.devAndroidEmulator:
        return 'http://10.0.2.2:8000/api/v1';
      case Environment.production:
        return 'https://YOUR-RAILWAY-URL.up.railway.app/api/v1';
    }
  }

  // No instances — this is a static config namespace.
  AppConfig._();
}

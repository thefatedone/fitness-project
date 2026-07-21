/// Compile-time environment selector for the NutriMind mobile app.
///
/// Resolves the API base URL based on where the app is being run. The same
/// compiled binary can be reused across development on a real device, on an
/// Android emulator, and in production by toggling [AppConfig.environment].
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

  /// Base URL of the FastAPI backend, suffixed with the API version prefix.
  ///
  /// Switches on [environment]:
  ///   * [Environment.dev] → loopback, hits the backend on the developer
  ///     machine directly. Works for iOS Simulator, macOS / Windows / Linux
  ///     desktop builds.
  ///   * [Environment.devAndroidEmulator] → `10.0.2.2`, the Android emulator's
  ///     NAT alias back to the host. Required because the emulator's own
  ///     loopback is not the host loopback.
  ///   * [Environment.production] → the deployed Railway URL. Replace the
  ///     placeholder before shipping.
  static String get apiBaseUrl {
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

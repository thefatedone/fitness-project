import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around `flutter_secure_storage` for the JWT access token.
///
/// Single responsibility: persist and retrieve the opaque access token issued
/// by the NutriMind backend. Wrapping the plugin (rather than calling it
/// directly from feature code) lets us:
///
///   * Swap the underlying storage backend (Keychain on iOS, EncryptedSharedPreferences
///     on Android) without touching repositories or screens.
///   * Centralize the key name so a typo can't silently deserialize nothing.
///   * Mock the surface in tests by implementing the same trio of methods.
///
/// Reads and writes are async because every native call crosses the
/// platform-channel boundary.
class TokenStorage {
  /// Keychain / Keystore key under which the access token is stored.
  ///
  /// Kept `private` and `static const` so the only way to touch the storage
  /// is through this class — a future refactor won't accidentally split the
  /// read/write sites across different keys.
  static const String _key = 'access_token';

  /// Backing secure-storage instance. Default options (`aOptions` for Android,
  /// `iOptions` for iOS) are fine — both platforms will encrypt the value at
  /// rest using the OS-level credential store.
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Persists [token] to secure storage, overwriting any previous value.
  ///
  /// Returns a [Future] that completes once the platform-channel write is
  /// acknowledged. Throws if the underlying native call fails (e.g. on a
  /// jail-broken device where the keystore is unavailable).
  Future<void> saveToken(String token) {
    return _storage.write(key: _key, value: token);
  }

  /// Returns the stored access token, or `null` if no token has been saved
  /// yet (e.g. before the user logs in for the first time).
  Future<String?> readToken() {
    return _storage.read(key: _key);
  }

  /// Removes the stored access token. Idempotent — calling it when no token
  /// is stored is a no-op rather than an error.
  ///
  /// Call this on logout so the next request the HTTP client makes will not
  /// carry a stale credential.
  Future<void> deleteToken() {
    return _storage.delete(key: _key);
  }
}

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Pre-configured `Dio` instance for talking to the NutriMind backend.
///
/// Single responsibility: hand callers a ready-to-use [Dio] whose `baseUrl`,
/// timeouts, and `Authorization` header are already wired to the rest of the
/// infrastructure layer ([AppConfig] + [TokenStorage]). Repositories depend
/// on this class rather than constructing their own `Dio`, so HTTP concerns
/// (auth header injection, timeouts, retry policy, error mapping) stay in
/// one place.
///
/// The auth flow is intentionally minimal at this layer:
///   * The token is read on **every** outgoing request via the
///     [InterceptorsWrapper.onRequest] callback below, so a fresh token saved
///     by the login screen takes effect on the next request without needing
///     to rebuild the client.
///   * 401 handling (refresh / force-logout) can be added as a second
///     interceptor later without touching call sites.
class ApiClient {
  /// Holds the [TokenStorage] so the auth interceptor can read the current
  /// access token on every request.
  final TokenStorage _tokenStorage;

  /// The shared HTTP client. `late final` so it can be assigned in the
  /// constructor body after this instance is fully initialised (the
  /// interceptor closes over `_tokenStorage`).
  late final Dio dio;

  /// Builds a new [ApiClient].
  ///
  /// The optional [tokenStorage] parameter is exposed primarily for tests
  /// that want to inject a fake; in production, callers should rely on the
  /// module-level [tokenStorage] / [apiClient] singletons declared below.
  ApiClient({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        // We send JSON; let the server tell us if it disagrees.
        contentType: 'application/json',
        // 2xx only — anything else becomes a DioException so call sites can
        // handle errors uniformly rather than checking `response.statusCode`.
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        // Attach `Authorization: Bearer <token>` when a token is stored.
        // We re-read on every request so a login / logout from elsewhere in
        // the app takes effect immediately without rebuilding the client.
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }
}

// ============================================================================
// Module-level singletons
// ============================================================================
//
// These exist so feature code can simply `import 'api_client.dart';` and use
// `apiClient.dio` (or `tokenStorage.readToken()`) without re-constructing the
// HTTP client / storage wrapper every call. Re-instantiating `ApiClient`
// would also re-register the interceptor — harmless but wasteful — and would
// lose any future in-flight configuration added at runtime.

/// Process-wide [TokenStorage] instance. Import and use directly:
/// `final t = await tokenStorage.readToken();`
final TokenStorage tokenStorage = TokenStorage();

/// Process-wide [ApiClient] instance, wired to the singleton [tokenStorage].
/// Import and use directly: `await apiClient.dio.get('/users/me');`
final ApiClient apiClient = ApiClient(tokenStorage: tokenStorage);

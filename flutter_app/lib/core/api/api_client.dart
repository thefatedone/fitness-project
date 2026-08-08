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
class ApiClient {
  /// Holds the [TokenStorage] so the auth interceptor can read the current
  /// access token on every request.
  final TokenStorage _tokenStorage;

  /// The shared HTTP client. `late final` so it can be assigned in the
  /// constructor body after this instance is fully initialised (the
  /// interceptor closes over `_tokenStorage`).
  late final Dio dio;

  /// Hook fired when ANY request returns `401 Unauthorized` from the
  /// backend. The hook is set by the app's `main()` after both the
  /// [ApiClient] and the [AuthProvider] exist, so the 401-handler can
  /// call `authProvider.forceLogout()` and let [AuthGate] route the
  /// user to the login screen.
  ///
  /// Why a callback hook rather than a direct dependency on
  /// [AuthProvider]? `core/api/` is a leaf in the dependency graph —
  /// it can't import `features/auth/` without inverting the graph and
  /// creating a cycle (the auth providers already depend on
  /// `core/api/api_client.dart` for the shared `Dio`). The callback
  /// keeps the dependency direction one-way.
  ///
  /// `null` (the default) means "no system-wide handler wired" — the
  /// 401 will still propagate as an [ApiException] to the call site
  /// for it to handle, which preserves the existing behaviour.
  void Function()? onUnauthorized;

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

        // Centralized 401 handling. A 401 from the backend means the
        // current token has expired or been revoked. We:
        //   1. Fire `onUnauthorized` (if wired) so the AuthProvider
        //      force-logs-out, flips `status` to `unauthenticated`, and
        //      `AuthGate` re-routes to the login screen.
        //   2. STILL propagate the error via `handler.next(e)` so the
        //      original call site receives its normal [ApiException]
        //      and can display whatever per-screen error message it
        //      already does. The 401 handler is purely additive —
        //      it never suppresses the call site's error.
        //
        // Why this doesn't loop: `onUnauthorized` ultimately calls
        // [AuthProvider.forceLogout], which is a purely local state
        // mutation (no network). The user lands on `LoginScreen`; the
        // login form is a fresh Form; no API call fires from that
        // path. So a 401 mid-session fires the hook once, the user
        // gets routed away, the dangling response from the original
        // call is consumed by the call site's existing error handler.
        onError: (e, handler) {
          if (e.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(e);
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

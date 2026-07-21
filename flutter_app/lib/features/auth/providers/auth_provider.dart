import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../models/user_model.dart';
import 'auth_api.dart';

/// Top-level authentication state of the app.
enum AuthStatus {
  /// Initial state before [AuthProvider.tryAutoLogin] has run. UI should
  /// treat this as "show a splash / loader, don't navigate yet".
  unknown,

  /// A valid token exists in secure storage AND `GET /users/me` succeeded.
  authenticated,

  /// Either no token was stored, the stored token was rejected by the
  /// backend, or the user explicitly logged out.
  unauthenticated,
}

/// `ChangeNotifier` that owns the user's authentication state.
///
/// Single responsibility: orchestrate the login / register / auto-login flows
/// end-to-end (network call → store token → fetch profile → notify the UI),
/// and expose a small, UI-friendly state object ([status], [currentUser],
/// [isLoading], [errorMessage]) that screens can react to via
/// `provider`'s `Consumer` / `context.watch`.
///
/// Anything network-shaped lives in [AuthApi]; anything storage-shaped lives
/// in [TokenStorage]. This class is the glue.
class AuthProvider extends ChangeNotifier {
  /// Talks to the backend. Held as a field (not a singleton reference at the
  /// call site) so tests can inject a fake.
  final AuthApi _authApi;

  /// Where the current authentication status sits. UI surfaces branch off
  /// this; `_runAuthAction` and `tryAutoLogin` are the only writers.
  AuthStatus _status = AuthStatus.unknown;

  /// Cached copy of the authenticated user's profile. `null` until
  /// authentication succeeds (or after logout).
  UserModel? _currentUser;

  /// Last user-facing error message, or `null` if the most recent action
  /// succeeded. Cleared at the start of every new auth action.
  String? _errorMessage;

  /// True while a network call is in flight; UI uses this to disable the
  /// "Sign in" button and show a spinner.
  bool _isLoading = false;

  AuthProvider({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  // ---- public read-only views -------------------------------------------------

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  /// Convenience flag for screens that only need a yes/no answer.
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ---- lifecycle --------------------------------------------------------------

  /// Runs once at app startup. Decides whether an existing token is still
  /// valid by trying to load the profile with it.
  ///
  /// Behaviour:
  ///   * No token in storage → `unauthenticated`, listener notified once.
  ///   * Token present, profile fetch succeeds → `authenticated` and
  ///     [currentUser] populated.
  ///   * Token present, profile fetch fails (e.g. 401) → token is purged
  ///     and status becomes `unauthenticated`. We swallow the failure here
  ///     because the only sensible reaction is to show the login screen;
  ///     there's nothing the user could do about a stale token.
  Future<void> tryAutoLogin() async {
    final token = await tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      _currentUser = await _authApi.fetchCurrentUser();
      _status = AuthStatus.authenticated;
    } on ApiException {
      // Stale or rejected token — wipe it so the next login is clean.
      await tokenStorage.deleteToken();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  // ---- public actions ---------------------------------------------------------

  /// Registers a new account and, on success, signs the user in.
  ///
  /// [email] / [phone] — provide one (the backend requires at least one).
  /// Returns `true` on success, `false` on failure (with [errorMessage] set).
  Future<bool> register({
    String? email,
    String? phone,
    required String password,
    required String fullName,
  }) {
    return _runAuthAction(
      () async {
        final token = await _authApi.register(
          email: email,
          phone: phone,
          password: password,
          fullName: fullName,
        );
        await tokenStorage.saveToken(token);
      },
    );
  }

  /// Logs an existing user in. Returns `true` on success.
  Future<bool> login({
    String? email,
    String? phone,
    required String password,
  }) {
    return _runAuthAction(
      () async {
        final token = await _authApi.login(
          email: email,
          phone: phone,
          password: password,
        );
        await tokenStorage.saveToken(token);
      },
    );
  }

  /// Logs the user out: purges the token, drops the cached profile, and
  /// resets the status. Safe to call repeatedly.
  Future<void> logout() async {
    await tokenStorage.deleteToken();
    _currentUser = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Clears [errorMessage] without otherwise touching state — useful for
  /// dismissing a banner after the user has read it.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ---- private helpers --------------------------------------------------------

  /// Shared body for [register] and [login].
  ///
  /// [action] runs the network call and persists the token. This helper
  /// wraps it in the loading / error / user-fetch boilerplate so each
  /// public method is a one-liner.
  ///
  /// On success it fetches the user profile and flips the status to
  /// `authenticated`. On any [ApiException] it captures [ApiException.message]
  /// into [errorMessage] so the UI can render it. The loading flag is
  /// always reset, and listeners are always notified exactly once at the
  /// end of the call.
  Future<bool> _runAuthAction(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      _currentUser = await _authApi.fetchCurrentUser();
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      // The action already saved a token before the failure (e.g. register
      // succeeded but the subsequent /users/me call failed with 401). If
      // that happens, drop the half-baked session so the next login starts
      // from a clean slate.
      if (e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('token')) {
        await tokenStorage.deleteToken();
      }
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      return false;
    } catch (_) {
      // Defensive: any non-ApiException that somehow escapes the auth
      // client (e.g. a bug in fetchCurrentUser) shouldn't crash the UI.
      _errorMessage =
          'Что-то пошло не так. Проверь соединение и попробуй снова.';
      _status = AuthStatus.unauthenticated;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

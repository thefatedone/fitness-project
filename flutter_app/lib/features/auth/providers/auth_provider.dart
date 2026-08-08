import 'dart:async';

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
  /// this; `_runAuthAction`, `tryAutoLogin`, `logout`, and
  /// `forceLogout` are the only writers.
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

  /// Set to `true` by [forceLogout] when the system (rather than the
  /// user) is what kicked us out — i.e. an expired token triggered
  /// the centralized 401 handler in [apiClient].
  ///
  /// The intent is for the next screen the user lands on (the login
  /// screen) to read this in `initState` and show a "Сессия истекла,
  /// войди снова." SnackBar, then clear it. LoginScreen's current
  /// implementation doesn't yet read this — that's a follow-up
  /// integration that's out of scope for the current three-file
  /// task — but the data IS captured here so the LoginScreen hookup
  /// is a one-line read + clear.
  bool sessionExpiredNotice = false;

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
  /// resets the status. Safe to call repeatedly. This is the path used
  /// for user-initiated sign-out (e.g. the "Выйти" tile in Settings).
  Future<void> logout() async {
    await tokenStorage.deleteToken();
    _currentUser = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// System-initiated logout. Called by the centralized 401 handler
  /// in [apiClient] when any in-flight request returns
  /// `401 Unauthorized` — i.e. the access token has expired or been
  /// revoked.
  ///
  /// Functionally identical to [logout] EXCEPT it also flips
  /// [sessionExpiredNotice] so the next screen the user lands on
  /// (typically the login screen) can render a one-time
  /// "Сессия истекла, войди снова." SnackBar. The two methods are
  /// deliberately distinct so the UI can later distinguish "user chose
  /// to sign out" from "the system signed them out" without changing
  /// the call site that fires them.
  ///
  /// This is `void` (not `Future<void>`) because nothing on the
  /// logout path awaits anything — clearing the token is a single
  /// `tokenStorage.deleteToken()` call that the caller can fire-and-
  /// forget (the [ApiClient.onUnauthorized] hook signature is itself
  /// `void Function()`).
  void forceLogout() {
    // No `await` on `tokenStorage.deleteToken()` because this method
    // is intentionally sync — the 401 hook is called on a hot path
    // (inside Dio's error interceptor) and we don't want the API call
    // to wait on disk storage cleanup before propagating its
    // original error back to the call site. The next [tryAutoLogin]
    // or [login] will simply find no token, which is the correct
    // post-condition.
    unawaited(tokenStorage.deleteToken());
    _currentUser = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    sessionExpiredNotice = true;
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

  /// Clears [sessionExpiredNotice] after the one-shot SnackBar has
  /// been shown. Idempotent: calling it when the flag is already
  /// `false` is a no-op. Intentionally does NOT call
  /// [notifyListeners] — nothing watches [sessionExpiredNotice]
  /// reactively; it's a one-shot read-and-clear pattern that the
  /// login screen consumes in [initState] before any rebuild of the
  /// provider tree happens. Keeps the clear a pure data-update with
  /// zero UI thrash.
  void clearSessionExpiredNotice() {
    sessionExpiredNotice = false;
  }

  /// Replaces the cached [currentUser] with [user] and notifies.
  ///
  /// Intended for OTHER providers (e.g. [ProfileProvider]) that just
  /// completed a partial update and need the rest of the app — the
  /// tracker summary, the weight chart, the navigation bar — to see
  /// the new targets immediately on the next rebuild.
  ///
  /// Passing the new `UserModel` (rather than letting callers poke
  /// at `_currentUser` directly) keeps the field properly private and
  /// makes the call site read as "publish a fresh snapshot of the
  /// user", which is exactly what's happening.
  void updateCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
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

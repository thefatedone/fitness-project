import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../../core/api/api_client.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/gen/app_localizations_lookup.dart';
import '../models/user_model.dart';

/// Thrown by [AuthApi] when the backend rejects a request or the network
/// is unreachable.
///
/// Single responsibility: carry a user-presentable message out of the HTTP
/// layer AND/OR a stable lookup key that the UI layer renders through
/// [AppLocalizations]. Two parallel fields:
///   * [message] — the fallback text (English) used when no [messageKey]
///     is set, OR when the UI renders the exception outside a localised
///     context (e.g. server-side logs).
///   * [messageKey] / [messageArgs] — when present, the UI's
///     [localizedMessage] helper resolves them via
///     `AppLocalizations.of(context)!.lookup(...)`. If lookup returns
///     null (unknown key), the helper falls back to [message].
///
/// This "key + fallback" architecture keeps the provider layer
/// localization-SAFE (no translation logic in providers, no BuildContext
/// threading) while letting the UI render every error in the active
/// locale. New endpoints should prefer the key+args form for any error
/// with a stable translation; dynamic backend-issued messages keep
/// using the raw [message] since they're already localized on the
/// server.
class ApiException implements Exception {
  /// English fallback text. Always non-null — used by
  /// [localizedMessage] when no [messageKey] is set, and by
  /// [toString] for logs.
  final String message;

  /// Optional ARB key — when set, [localizedMessage] resolves the
  /// text in the active locale via [AppLocalizations.lookup].
  final String? messageKey;

  /// Optional placeholder arguments for [messageKey] (e.g. `{'name':
  /// foodLog.foodName}`). Mirrors the standard ARB-placeholder shape.
  final Map<String, Object>? messageArgs;

  const ApiException(
    this.message, {
    this.messageKey,
    this.messageArgs,
  });

  @override
  String toString() => 'ApiException: $message';

  /// Resolves the user-facing text in the current locale.
  ///
  /// Order:
  ///   1. If [messageKey] is set, look it up via [AppLocalizations].
  ///   2. If lookup returns null (unknown key) or [AppLocalizations] is
  ///      unavailable (e.g. outside a [BuildContext]), fall back to
  ///      [message] so the user still sees *something* sensible.
  ///
  /// Callers should prefer this over reading [message] directly when
  /// they have a [BuildContext] in scope.
  String localizedMessage(BuildContext context) {
    final key = messageKey;
    final l10n = AppLocalizations.of(context);
    if (key != null) {
      // The `lookup` extension maps a small set of stable runtime
      // keys (see `app_localizations_lookup.dart`) to the matching
      // generated getter; args are dropped because none of the
      // currently-registered keys take placeholders.
      final fromL10n = l10n.lookup(key);
      if (fromL10n != null) return fromL10n;
    }
    return message;
  }

  /// Builds an [ApiException] from a Dio failure.
  ///
  /// Precedence:
  ///   1. If the backend returned an HTTP error body, extract its `detail`
  ///      field. FastAPI typically sends either `{"detail": "..."}` (custom
  ///      HTTPException) or `{"detail": [{loc, msg, type}, ...]}` (422
  ///      validation). We surface the raw server text as the [message]
  ///      fallback (it carries the backend's own wording) and **do not**
  ///      attach a `messageKey` because the server's per-error wording
  ///      is dynamic and isn't in the ARB catalogue.
  ///   2. If the failure was a network-level problem (timeout, no
  ///      internet, TLS error), attach a stable `messageKey` so the UI
  ///      can render the active locale's network-error copy.
  ///   3. As a last resort, fall back to the generic
  ///      `commonError` key (also localised).
  factory ApiException.fromDioError(DioException e) {
    // (1) Server-provided error message. FastAPI returns the detail
    // text directly — we pass it through verbatim, which means the
    // backend owns the localisation of its own error copy (it's the
    // same text that gets surfaced on the wire).
    final response = e.response;
    if (response != null) {
      final detail = _extractDetail(response.data);
      if (detail != null && detail.isNotEmpty) {
        return ApiException(detail);
      }
    }

    // (2) Network-layer failures — keyed so the UI can render the
    // active locale's copy.
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          'Server is not responding. Please check your connection and try again.',
          messageKey: 'authServerUnreachable',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'Cannot reach the server. Check your internet connection.',
          messageKey: 'authNoConnection',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          'Could not establish a secure connection to the server.',
          messageKey: 'authSecureConnectionFailed',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          'Request was cancelled.',
          messageKey: 'authRequestCancelled',
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    // (3) Generic fallback — localised via the `commonError` key.
    return const ApiException(
      'Something went wrong. Please check your connection and try again.',
      messageKey: 'commonError',
    );
  }

  /// Pulls a user-presentable string out of the FastAPI error envelope.
  /// Handles both string `detail` and the list form used for validation
  /// errors. Returns `null` if the body shape is unrecognised.
  static String? _extractDetail(dynamic data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) return first['msg'] as String;
    }
    return null;
  }
}

/// Client-side mirror of the backend's password policy.
///
/// Returns `null` when [password] is acceptable, otherwise an English
/// error message that the UI shows inline next to the password field.
/// The UI is responsible for rendering this through
/// `AppLocalizations.of(context)` when a `BuildContext` is in scope
/// (see `validatePasswordLocalized(context, password)` below).
///
/// Rules (must match `backend/app/api/v1/routes/auth.py`):
///   * At least 8 characters.
///   * First character must be uppercase.
///   * At least one digit somewhere in the string.
///
/// We use Unicode-aware patterns (`\p{Lu}`, `\p{Nd}`) so the client-side rule
/// matches the backend's `str.isupper()` / `str.isdigit()` checks, which are
/// Unicode-aware in Python 3 — i.e. `А` (Cyrillic A) and `１` (fullwidth 1)
/// are both accepted by both sides.
String? validatePassword(String password) {
  if (password.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!RegExp(r'^\p{Lu}', unicode: true).hasMatch(password)) {
    return 'First letter of the password must be uppercase';
  }
  if (!RegExp(r'\p{Nd}', unicode: true).hasMatch(password)) {
    return 'Password must contain at least one digit';
  }
  return null;
}

/// Convenience wrapper for screens that have a [BuildContext] in scope:
/// returns the *localized* password-rule message (or null) by looking
/// up the [validatePassword] result against [AppLocalizations].
///
/// Keys are intentionally inline (not a `lookup` helper) because the
/// generated [AppLocalizations] class doesn't expose a generic
/// key→string resolver — it has one named getter per ARB entry.
/// Inlining the switch keeps the surface area minimal.
String? validatePasswordLocalized(
  BuildContext context,
  String password,
) {
  final l10n = AppLocalizations.of(context);
  if (password.length < 8) return l10n.authPasswordMinLength;
  if (!RegExp(r'^\p{Lu}', unicode: true).hasMatch(password)) {
    return l10n.authPasswordNeedUpper;
  }
  if (!RegExp(r'\p{Nd}', unicode: true).hasMatch(password)) {
    return l10n.authPasswordNeedDigit;
  }
  return null;
}

/// Auth-related network calls for the NutriMind mobile app.
///
/// Single responsibility: speak HTTP to the three auth/user endpoints the
/// app needs (`POST /auth/register`, `POST /auth/login`, `GET /users/me`),
/// translate Dio errors into [ApiException]s, and decode the typed payload
/// ([UserModel] for `/users/me`). Higher layers ([AuthProvider]) layer
/// caching, retry, and UI state on top.
///
/// All methods rethrow [ApiException] on failure so callers can `catch`
/// just one exception type and present a message directly.
class AuthApi {
  /// The shared HTTP client. Reusing [apiClient] ensures the auth-token
  /// interceptor (and any future cross-cutting config) is in effect.
  final Dio _dio = apiClient.dio;

  /// Registers a new account.
  ///
  /// Either [email] or [phone] must be non-null on the server side. We send
  /// both as `null` when absent rather than omitting the key, so the JSON
  /// shape is deterministic and easier to log.
  ///
  /// Returns the `access_token` issued by the backend. The caller is
  /// responsible for persisting it via [tokenStorage].
  Future<String> register({
    String? email,
    String? phone,
    required String password,
    required String fullName,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'phone': phone,
          'password': password,
          'full_name': fullName,
        },
      );
      return _extractAccessToken(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Logs the user in with either [email] or [phone] + [password].
  ///
  /// Returns the `access_token` issued by the backend. The caller is
  /// responsible for persisting it via [tokenStorage].
  Future<String> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'phone': phone,
          'password': password,
        },
      );
      return _extractAccessToken(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Fetches the authenticated user's profile from `GET /users/me`.
  ///
  /// Requires a valid access token to be present in [tokenStorage] — the
  /// auth interceptor on [apiClient.dio] will attach it automatically.
  /// On 401 the server's `detail` (e.g. "Invalid token") is surfaced as an
  /// [ApiException] so the caller can decide to log the user out.
  Future<UserModel> fetchCurrentUser() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/users/me');
      final data = res.data;
      if (data == null) {
        throw const ApiException('Server returned an empty response.');
      }
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Pulls the `access_token` out of the standard `{access_token, token_type}`
  /// response envelope. Throws [ApiException] if the shape is unexpected so
  /// the user never sees a confusing `null` token downstream.
  String _extractAccessToken(Map<String, dynamic>? body) {
    if (body == null) {
      throw const ApiException('Server returned an empty response.');
    }
    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Server did not issue an authentication token.');
    }
    return token;
  }
}

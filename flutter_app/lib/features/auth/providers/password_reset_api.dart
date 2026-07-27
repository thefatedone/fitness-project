import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'auth_api.dart';

/// HTTP client for the three password-reset endpoints:
///
///   * `POST /auth/forgot-password`   — request a 6-digit code by email
///   * `POST /auth/verify-reset-code` — pre-flight check before showing
///                                    the new-password screen
///   * `POST /auth/reset-password`    — commit the swap; burns the code
///
/// Single responsibility: speak HTTP to those three routes, decode
/// their tiny JSON envelopes, and rethrow any Dio failure as an
/// [ApiException] (reused from `auth_api.dart` so the chat snackbar
/// pipeline can surface messages from any auth/reset call with one
/// exception type).
///
/// No auth token is required for any of these routes — the
/// password-reset flow runs while the user is unauthenticated. The
/// shared `apiClient.dio` will still attach whatever token might be in
/// secure storage (e.g. if the user is signed-in in a different tab),
/// but the backend ignores the header on these endpoints, so that's
/// harmless.
class PasswordResetApi {
  /// The shared HTTP client. Reusing [apiClient] means the auth-token
  /// interceptor (and any future cross-cutting config) is in effect
  /// — see the class-level comment on why that's harmless here.
  final Dio _dio = apiClient.dio;

  /// `POST /auth/forgot-password`. Always returns 200 with a
  /// generic Russian message — whether the email maps to a real user
  /// or not. Email-enumeration prevention: an attacker probing the
  /// endpoint can't distinguish "no such account" from "code sent".
  ///
  /// Returns the `message` field on success. The `ApiException`
  /// thrown by `fromDioError` would normally surface the backend's
  /// `detail`, but this endpoint never returns one, so in practice
  /// any exception here is a network-level failure.
  Future<String> requestCode(String email) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/forgot-password',
        data: {'email': email},
      );
      return _extractMessage(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `POST /auth/verify-reset-code`. Returns `true` on a 200 (the
  /// backend's `{valid: true}` envelope); any 400 (bad / expired /
  /// used code, unknown email) is an [ApiException] that the caller
  /// catches and surfaces as an inline error.
  ///
  /// The returned `bool` is essentially always `true` — the only
  /// non-`true` outcome is the exception path. We keep the `bool`
  /// return type rather than just `void` so the call site reads
  /// naturally ("did verifyCode succeed?") and so a future server
  /// contract change (e.g. adding a `remaining_attempts` field) is
  /// easy to plumb in.
  Future<bool> verifyCode({
    required String email,
    required String code,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/verify-reset-code',
        data: {'email': email, 'code': code},
      );
      return _extractValid(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `POST /auth/reset-password`. The backend independently
  /// re-verifies the supplied code (the client can't skip the verify
  /// step), validates `new_password` against the same three rules
  /// registration uses, and only then atomically flips the code
  /// row to `used=True` and swaps the user's password hash.
  ///
  /// The 400-error copy from the backend surfaces the *specific*
  /// reason the request failed — either the generic
  /// "Неверный или истёкший код." or one of the password-strength
  /// rules. The caller shows the message verbatim in a SnackBar so
  /// the user can act on it.
  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/reset-password',
        data: {
          'email': email,
          'code': code,
          'new_password': newPassword,
        },
      );
      return _extractMessage(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // -- envelope helpers ----------------------------------------------------

  /// Pulls the `message` field out of a `{message: "..."}` response.
  /// Defensive: the backend's contracts guarantee this field, but if
  /// the server ever hands us a body without it we surface a friendly
  /// Russian fallback rather than crashing — same pattern as
  /// `AuthApi._extractAccessToken`.
  String _extractMessage(Map<String, dynamic>? body) {
    if (body == null) {
      throw const ApiException('Сервер вернул пустой ответ.');
    }
    final msg = body['message'];
    if (msg is! String || msg.isEmpty) {
      throw const ApiException('Сервер не вернул подтверждение.');
    }
    return msg;
  }

  /// Pulls the `valid` boolean out of a `{valid: true}` response. A
  /// missing or non-bool `valid` is treated as `false` (which is
  /// "reject" — the same effective outcome as if the backend had
  /// returned `valid: false`, since the caller would surface a failure
  /// either way).
  bool _extractValid(Map<String, dynamic>? body) {
    if (body == null) return false;
    return body['valid'] == true;
  }
}

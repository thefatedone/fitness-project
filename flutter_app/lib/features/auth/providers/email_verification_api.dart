import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../providers/auth_api.dart';

/// HTTP client for the two email-verification endpoints:
///
///   * `POST /auth/send-verification-email` — request a 6-digit code
///   (or refresh an existing unverified one). Authenticated.
///   * `POST /auth/verify-email` — submit the 6-digit code. Authenticated.
///
/// Single responsibility: speak HTTP to those two routes, decode
/// the tiny JSON envelopes, and rethrow any Dio failure as an
/// [ApiException] (reused from `auth_api.dart` so the chat snackbar
/// pipeline can surface messages with one exception type).
///
/// Email verification is a *soft reminder*, not an access gate. The
/// user can use the entire app with `is_email_verified=False`; the
/// flag just drives the in-app banner. The endpoints are authenticated
/// so we know which user is asking (a user without a stored email
/// gets a 400 from the backend instead of silently sending to a
/// null address).
class EmailVerificationApi {
  /// The shared HTTP client. Reusing [apiClient] means the auth-token
  /// interceptor (and any future cross-cutting config) is in effect —
  /// the JWT the user got from login attaches automatically.
  final Dio _dio = apiClient.dio;

  /// `POST /auth/send-verification-email`. Empty body — the route
  /// knows which user is asking from the JWT. Returns the server's
  /// Russian `message` ("Код подтверждения отправлен на email." or
  /// "Email уже подтверждён." for an idempotent re-call).
  Future<String> sendCode() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/send-verification-email',
      );
      return _extractMessage(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `POST /auth/verify-email` with `{'code': code}`. Returns the
  /// server's Russian `message` ("Email подтверждён!" on success).
  /// On 400 the backend's `detail` ("Неверный или истёкший код.")
  /// surfaces as an [ApiException] via `fromDioError`.
  Future<String> verifyCode(String code) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/verify-email',
        data: {'code': code},
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
  /// `PasswordResetApi._extractMessage`.
  String _extractMessage(Map<String, dynamic>? body) {
    if (body == null) {
      throw const ApiException('Server returned an empty response.', messageKey: 'userFacingErrorServerEmpty');
    }
    final msg = body['message'];
    if (msg is! String || msg.isEmpty) {
      throw const ApiException('Server did not return confirmation.');
    }
    return msg;
  }
}

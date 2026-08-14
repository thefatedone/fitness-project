import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_api.dart';

/// HTTP client for the `PUT /users/me/password` endpoint.
///
/// Single responsibility: send the `current_password` / `new_password`
/// pair to the backend, surface the returned success message (or an
/// [ApiException] carrying the backend's `detail`) and return. The
/// 400 wrong-current-password case, the 422 strength-rule case, and
/// every other status code all flow through the standard
/// [ApiException.fromDioError] pipeline — the backend already speaks
/// user-friendly Russian detail text for the 400 path, and the 422 path
/// carries the standard FastAPI `detail: [{type, loc, msg, …}]` shape
/// that the mobile client already knows how to extract.
///
/// We deliberately don't special-case either error here — letting the
/// standard exception flow handle them keeps the contract simple and
/// makes future server-side tweaks land in the client without code
/// changes on this side.
class PasswordApi {
  /// The shared HTTP client — reuses [apiClient] so the auth-token
  /// interceptor (and any future cross-cutting config) is in effect.
  final Dio _dio = apiClient.dio;

  /// `PUT /users/me/password`. Returns the `message` string from the
  /// 200 response on success. Any Dio error becomes an [ApiException].
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/users/me/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      final body = res.data;
      if (body == null) {
        // Defensive — the backend's PUT always returns a JSON object
        // with a `message` field. Treat an empty body the same way
        // the rest of the app does: surface a friendly fallback.
        throw const ApiException('Server returned an empty response.', messageKey: 'userFacingErrorServerEmpty');
      }
      final msg = body['message'];
      if (msg is! String || msg.isEmpty) {
        throw const ApiException('Server did not return confirmation.');
      }
      return msg;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

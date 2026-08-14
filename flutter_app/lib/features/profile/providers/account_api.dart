import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_api.dart';

/// HTTP client for the destructive account-management endpoint
/// `DELETE /users/me`.
///
/// Single responsibility: hit the endpoint with a password-confirmation
/// body, surface the returned success message, and rethrow any Dio
/// error as an [ApiException]. We don't special-case the 400 wrong-
/// password path here — the backend's `detail` is already a
/// user-friendly Russian string that [ApiException.fromDioError] will
/// pick up and surface in a SnackBar without any extra logic.
class AccountApi {
  /// The shared HTTP client — reuses [apiClient] so the auth-token
  /// interceptor is in effect. Even though the call deletes the user
  /// account (and therefore the JWT becomes useless for *future*
  /// requests), the current request itself is authenticated with the
  /// still-valid token, so the interceptor's pre-flight header
  /// attachment is the right thing to happen here.
  final Dio _dio = apiClient.dio;

  /// `DELETE /users/me`. Returns the `message` string from the 200
  /// response. Any Dio error becomes an [ApiException].
  ///
  /// Note: DELETE requests with bodies are unusual but the HTTP spec
  /// permits them and the backend's FastAPI handler reads the body
  /// exactly the same as it would for a POST. Dio's `delete()` method
  /// supports a `data` argument out of the box.
  Future<String> deleteAccount({required String password}) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/users/me',
        data: {'password': password},
      );
      final body = res.data;
      if (body == null) {
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

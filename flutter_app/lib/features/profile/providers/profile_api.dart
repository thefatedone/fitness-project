import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_api.dart';

/// HTTP client for the user-profile endpoints (`PUT /users/me` and the
/// profile-photo upload helper `POST /users/me/photo`).
///
/// Single responsibility: serialize the partial-update payload the caller
/// built and translate the response back into a [UserModel] — every
/// other piece (form widgets, validation, image picking, file
/// compression) lives in higher layers. Persistence happens server-side;
/// a successful `updateProfile` already wrote the row, so the returned
/// [UserModel] is also the new source of truth.
class ProfileApi {
  /// The shared HTTP client — reuses [apiClient] so the auth-token
  /// interceptor (added in `core/api/api_client.dart`) attaches the
  /// bearer header automatically. No manual auth here.
  final Dio _dio = apiClient.dio;

  /// `PUT /users/me` with a partial-update body.
  ///
  /// The FastAPI route accepts all fields as optional and applies
  /// only what is supplied (PATCH-like semantics over a PUT verb).
  /// Callers pass a map containing *only* the keys that actually
  /// changed — the backend ignores everything else. Returned [UserModel]
  /// carries the server's recomputed derived fields (`bmr`, `tdee`,
  /// daily targets) when applicable, so a weight-edit round-trip can
  /// refresh the calorie ring without a second `GET /users/me`.
  Future<UserModel> updateProfile(Map<String, dynamic> fields) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/users/me',
        data: fields,
      );
      final body = res.data;
      if (body == null) {
        throw const ApiException('Сервер вернул пустой ответ.');
      }
      return UserModel.fromJson(body);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `POST /users/me/photo` — uploads a base64-encoded profile photo and
  /// returns the URL where the server stored it.
  ///
  /// The backend caps decoded payloads at 5 MB and returns 400 if the
  /// image is over the limit or the base64 is malformed. Those raw
  /// detail strings are English and not very helpful — surface a
  /// friendlier Russian hint for *this specific endpoint* whenever
  /// the server's complaint is exactly the size/format constraint.
  /// Other statuses (auth, network) still flow through the generic
  /// `ApiException.fromDioError` pipeline.
  Future<String> uploadPhoto(String base64Image) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/users/me/photo',
        data: {'image': base64Image},
      );
      final body = res.data;
      if (body == null) {
        throw const ApiException('Сервер вернул пустой ответ.');
      }
      final url = body['url'];
      if (url is! String || url.isEmpty) {
        throw const ApiException('Сервер не вернул ссылку на фото.');
      }
      return url;
    } on DioException catch (e) {
      // Size / format constraint: mask the raw backend English text
      // with a Russian hint that's actionable on a phone.
      if (e.response?.statusCode == 400) {
        throw const ApiException(
          'Не удалось загрузить фото. Проверь размер файла (макс. 5 МБ).',
        );
      }
      throw ApiException.fromDioError(e);
    }
  }
}

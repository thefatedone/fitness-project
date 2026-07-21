import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_api.dart';
import '../models/food_recognition_result.dart';

/// HTTP client for the AI-powered food-recognition endpoint.
///
/// Single responsibility: POST a photo to
/// `POST /api/v1/food/recognize-and-log?meal_type=…`, send the image as a
/// single multipart `file` field, decode the response into a
/// [FoodRecognitionResult], and surface any failure as an [ApiException]
/// (re-used from the auth layer so callers only deal with one exception
/// type).
///
/// The backend writes the resulting `food_logs` row server-side, so a
/// successful response means the entry is *already persisted* — the UI
/// just needs to refresh the day's list.
class FoodRecognitionApi {
  /// The shared HTTP client. Reusing [apiClient] means the auth-token
  /// interceptor (and any future cross-cutting config) is in effect.
  final Dio _dio = apiClient.dio;

  /// Gemini-backed food recognition.
  ///
  /// [imageFile] is the user-selected photo, uploaded as multipart
  /// `file`. [mealType] is forwarded as a query parameter (NOT in the
  /// FormData body, which is how the backend expects it). The per-request
  /// timeouts are bumped to 30 s — Gemini analysis can easily take longer
  /// than the global 15 s connect/receive budget when the image is large
  /// or the API is under load. We do NOT mutate the shared [_dio] client's
  /// defaults; we just override per-call via `Options`.
  Future<FoodRecognitionResult> recognizeAndLog({
    required File imageFile,
    required String mealType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: _filenameFromPath(imageFile.path),
        ),
      });

      final res = await _dio.post<Map<String, dynamic>>(
        '/food/recognize-and-log',
        data: formData,
        queryParameters: {'meal_type': mealType},
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final body = res.data;
      if (body == null) {
        throw const ApiException('Сервер вернул пустой ответ.');
      }
      return FoodRecognitionResult.fromJson(body);
    } on DioException catch (e) {
      // The backend's raw 422 detail is English and not very helpful to
      // a user staring at a photo of their lunch; surface a friendlier
      // Russian hint for *this specific endpoint* only.
      if (e.response?.statusCode == 422) {
        throw const ApiException(
          'Не удалось распознать блюдо на фото. Попробуй сделать более чёткое фото.',
        );
      }
      throw ApiException.fromDioError(e);
    }
  }

  /// Extracts the basename of [path] (the segment after the last separator)
  /// as the upload filename. Falls back to `"upload.jpg"` if the path is
  /// bare or ends in a separator — `MultipartFile` requires a non-empty
  /// filename.
  static String _filenameFromPath(String path) {
    final separators = ['/', r'\'];
    for (final s in separators) {
      final i = path.lastIndexOf(s);
      if (i >= 0 && i + 1 < path.length) {
        return path.substring(i + 1);
      }
    }
    return 'upload.jpg';
  }
}

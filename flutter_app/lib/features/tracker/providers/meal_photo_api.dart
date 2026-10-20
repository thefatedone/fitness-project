import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_api.dart';
import '../models/meal_analysis_result.dart';
import 'food_recognition_api.dart';

/// HTTP client for the meal-photo analysis endpoint.
///
/// Single responsibility: talk to `POST /api/v1/tracker/food/analyze-photo`,
/// decode the response into a [MealAnalysisResult], and map failures to
/// [ApiException]s the rest of the app already knows how to render.
///
/// The endpoint lives under the *tracker* router
/// (`/api/v1/tracker/food/analyze-photo`), not under the
/// `/api/v1/food/*` prefix the existing [FoodRecognitionApi] uses —
/// the relative path passed to `_dio.post` is therefore
/// `/tracker/food/analyze-photo` (the shared [apiClient] already
/// prefixes with the API base URL).
///
/// The endpoint does NOT persist anything server-side; it returns
/// a list of *suggested* items the user then reviews and POSTs to
/// `/tracker/food` one-by-one via [TrackerApi.addFood]. The data-
/// layer half of the flow stops here — the eventual screen renders
/// the result, edits portions, and drives the per-item POSTs.
class MealPhotoApi {
  /// The shared HTTP client. Reusing [apiClient] means the auth-token
  /// interceptor (and any future cross-cutting config) is in effect.
  final Dio _dio = apiClient.dio;

  /// Plate-analysis: photo in, multi-item estimate out.
  ///
  /// [imageFile] is the user-selected photo, uploaded as multipart
  /// `file` (the same field name the [FoodRecognitionApi] uses, so
  /// the backend's shared upload handler stays simple). [mealType]
  /// is forwarded as a query parameter — the same convention the
  /// single-item recogniser follows.
  ///
  /// Per-call timeouts are bumped to 60 s — plate-segmentation plus
  /// per-item calorie estimation is meaningfully heavier than the
  /// single-dish recogniser (which already needed 30 s); the global
  /// 15 s connect/receive budget is not realistic for a top-down
  /// photo of a full plate.
  ///
  /// Returns a [MealAnalysisResult] with `noFoodDetected == true`
  /// (and empty items) when the model inspected the photo and found
  /// nothing edible — that's a successful 200, not an error.
  Future<MealAnalysisResult> analyzeMealPhoto({
    required File imageFile,
    String mealType = 'snack',
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: FoodRecognitionApi.filenameFromPath(imageFile.path),
        ),
      });

      final res = await _dio.post<Map<String, dynamic>>(
        '/tracker/food/analyze-photo',
        data: formData,
        queryParameters: {'meal_type': mealType},
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      final body = res.data;
      if (body == null) {
        throw const ApiException(
          'Server returned an empty response.',
          messageKey: 'userFacingErrorServerEmpty',
        );
      }
      return MealAnalysisResult.fromJson(body);
    } on DioException catch (e) {
      // Friendlier per-status mapping for the meal-photo flow. The
      // single-item recogniser only customises the 422 case; the
      // meal flow can fail in several distinct, user-actionable ways
      // (oversize upload, wrong mime, rate limit, upstream model
      // hiccup) that all deserve a localised message rather than
      // the generic `commonError` fall-through. 401 is intentionally
      // NOT remapped — the global interceptor's `onUnauthorized`
      // hook handles token expiry, and the call site still needs to
      // see the original [ApiException] so its own error UI renders.
      switch (e.response?.statusCode) {
        case 413:
          throw const ApiException(
            'Image too large.',
            messageKey: 'userFacingErrorUploadPhoto',
          );
        case 415:
          throw const ApiException(
            'Unsupported image format.',
            messageKey: 'mealPhotoErrorFormat',
          );
        case 422:
          throw const ApiException(
            "Couldn't read the meal, try a clearer photo.",
            messageKey: 'userFacingErrorFoodPhotoRecognize',
          );
        case 429:
          throw const ApiException(
            'Too many analyses, wait a minute.',
            messageKey: 'mealPhotoErrorTooMany',
          );
        case 502:
        case 504:
          throw const ApiException(
            'The AI is having trouble, try again in a moment.',
            messageKey: 'mealPhotoErrorUpstream',
          );
      }
      throw ApiException.fromDioError(e);
    }
  }
}
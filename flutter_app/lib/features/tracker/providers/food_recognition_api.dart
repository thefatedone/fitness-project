import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_api.dart';
import '../models/food_recognition_result.dart';

/// HTTP client for the AI-powered food-recognition endpoints.
///
/// Single responsibility: talk to the two `POST /api/v1/food/*` Gemini-backed
/// routes — `recognize-and-log` (photo in, new row out) and
/// `{food_id}/reanalyze` (edited text in, same row updated out) — decode the
/// identical-shape responses into [FoodRecognitionResult], and surface any
/// failure as an [ApiException] (re-used from the auth layer so callers only
/// deal with one exception type).
///
/// The backend writes (or updates) the resulting `food_logs` row server-side,
/// so a successful response means the entry is *already persisted* — the UI
/// just needs to refresh the day's list.
class FoodRecognitionApi {
  /// The shared HTTP client. Reusing [apiClient] means the auth-token
  /// interceptor (and any future cross-cutting config) is in effect.
  final Dio _dio = apiClient.dio;

  /// Gemini-backed food recognition — photo → new row.
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
        throw const ApiException('Server returned an empty response.', messageKey: 'userFacingErrorServerEmpty');
      }
      return FoodRecognitionResult.fromJson(body);
    } on DioException catch (e) {
      // The backend's raw 422 detail is English and not very helpful to
      // a user staring at a photo of their lunch; surface a friendlier
      // localized hint for *this specific endpoint* only. The English
      // string doubles as a last-ditch fallback for callers that don't
      // resolve `messageKey` through `AppLocalizations`.
      if (e.response?.statusCode == 422) {
        throw const ApiException(
          'Could not recognize the dish in the photo. Try a clearer photo.',
          messageKey: 'userFacingErrorFoodPhotoRecognize',
        );
      }
      throw ApiException.fromDioError(e);
    }
  }

  /// Gemini-backed food recognition — edited text → row UPDATE in place.
  ///
  /// Pairs with [recognizeAndLog]: the user has already logged a photo-
  /// recognised entry, then taps "Уточнить" on the home screen to refine
  /// the description ("actually it's brown rice, not white, and there
  /// was less oil"). We POST the user's edited free-text to Gemini with no
  /// image; the backend gets fresh macro estimates for the same `FoodLog`
  /// row, runs the same allergen check, and UPDATEs the row in place — no
  /// duplicate, same `id`, same `meal_type`, same `date`.
  ///
  /// The response shape is byte-identical to [recognizeAndLog] (the
  /// backend intentionally reuses the response contract so the Flutter
  /// parser — [FoodRecognitionResult.fromJson] — doesn't have to branch
  /// on which endpoint produced it).
  ///
  /// Same 30 s per-call timeout rationale as [recognizeAndLog]: a text-
  /// only Gemini call is usually faster than a photo, but cold starts
  /// and quota-throttled retries can easily blow past the global 15 s
  /// budget. Overriding per-call keeps the shared client's defaults
  /// intact for the rest of the app.
  Future<FoodRecognitionResult> reanalyzeDescription({
    required String foodId,
    required String description,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/food/$foodId/reanalyze',
        data: {'description': description},
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final body = res.data;
      if (body == null) {
        throw const ApiException('Server returned an empty response.', messageKey: 'userFacingErrorServerEmpty');
      }
      return FoodRecognitionResult.fromJson(body);
    } on DioException catch (e) {
      // Same friendlier-Russian-hint pattern as [recognizeAndLog],
      // adapted for the text path: a 422 here usually means Gemini
      // couldn't extract a usable JSON from the user's text (too vague,
      // contradictory, or non-food content) — asking the user to
      // rephrase is the productive next step.
      if (e.response?.statusCode == 422) {
        throw const ApiException(
          'Could not analyze the description. Try rephrasing.',
          messageKey: 'userFacingErrorFoodReanalyze',
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

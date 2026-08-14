import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_api.dart';
import '../models/beverage_result.dart';

/// HTTP client for the beverage-recognition endpoints.
///
/// Single responsibility: talk to the two `POST /api/v1/food/*`
/// beverage routes — `recognize-beverage` (photo in, either
/// auto-logged dual-write or a suggestion-only payload out) and
/// `log-beverage-manual` (already-confirmed values in, dual-write
/// out) — decode both response shapes into a single
/// [BeverageRecognitionResult] (the dispatcher lives in
/// `BeverageRecognitionResult.fromJson`), and surface any failure
/// as an [ApiException] from the auth layer so callers only deal
/// with one exception type.
///
/// The backend writes (or updates) the resulting `food_logs` AND
/// `water_logs` rows server-side on the auto-logged branch, so a
/// successful `autoLogged == true` response means the entries are
/// *already persisted* — the UI just needs to refresh the day's
/// list.
class BeverageApi {
  /// The shared HTTP client. Reusing [apiClient] means the
  /// auth-token interceptor (and any future cross-cutting config)
  /// is in effect.
  final Dio _dio = apiClient.dio;

  /// Photo → beverage suggestion or auto-logged dual-write.
  ///
  /// Same per-call 30 s timeout override as
  /// [FoodRecognitionApi.recognizeAndLog] — Gemini analysis is
  /// the same slow path regardless of whether the prompt is
  /// food-shaped or beverage-shaped, so the rationale carries
  /// over.
  Future<BeverageRecognitionResult> recognizeBeverage(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: _filenameFromPath(imageFile.path),
        ),
      });

      final res = await _dio.post<Map<String, dynamic>>(
        '/food/recognize-beverage',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final body = res.data;
      if (body == null) {
        throw const ApiException('Server returned an empty response.', messageKey: 'userFacingErrorServerEmpty');
      }
      return BeverageRecognitionResult.fromJson(body);
    } on DioException catch (e) {
      // Same friendlier-Russian-hint pattern as
      // [FoodRecognitionApi.recognizeAndLog], adapted for the
      // beverage path: a 422 here usually means Gemini's
      // beverage output was unparseable (too ambiguous, or the
      // photo wasn't actually a drink). Asking the user to try
      // a different photo is the productive next step.
      if (e.response?.statusCode == 422) {
        throw const ApiException(
          'Could not recognize the beverage. Try a different photo.',
          messageKey: 'userFacingErrorBeverageRecognize',
        );
      }
      throw ApiException.fromDioError(e);
    }
  }

  /// User-confirmed values → dual-write.
  ///
  /// Counterpart to [recognizeBeverage]'s medium/low-confidence
  /// branch: the AI returned a `suggestion`, the user reviewed
  /// it (optionally editing values), and the client POSTs the
  /// final numbers here. No image is sent — the user has
  /// vouched for the values.
  ///
  /// Default values for the macros (`protein`, `carbs`, `fat`,
  /// `sugarG`) are all `0`, matching the backend schema's
  /// `>= 0` constraint and the contract that a "zero-calorie"
  /// beverage (water) is a legitimate, common case. The
  /// backend's `volume_ml` has `gt: 0` so it's required and
  /// non-zero — a "drank 0 ml" row would be meaningless.
  Future<BeverageRecognitionResult> logManual({
    required String beverageName,
    required double volumeMl,
    required double calories,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    double sugarG = 0,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/food/log-beverage-manual',
        data: {
          'beverage_name': beverageName,
          'volume_ml': volumeMl,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
          'sugar_g': sugarG,
        },
      );

      final body = res.data;
      if (body == null) {
        throw const ApiException('Server returned an empty response.', messageKey: 'userFacingErrorServerEmpty');
      }
      return BeverageRecognitionResult.fromJson(body);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Extracts the basename of [path] (the segment after the last
  /// separator) as the upload filename. Falls back to
  /// `"upload.jpg"` if the path is bare or ends in a separator —
  /// `MultipartFile` requires a non-empty filename. Mirrors the
  /// identical helper in [FoodRecognitionApi] verbatim; extracting
  /// to a shared location is a follow-up.
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

  /// Photo + user-claimed name → plausibility check.
  ///
  /// Counterpart to the manual-confirm path in the beverage flow:
  /// once the user reviews the AI's `suggestion` and (optionally)
  /// edits the beverage name, this endpoint re-asks Gemini
  /// whether the edited name matches the photo. The single
  /// consumer is `photo_beverage_screen.dart`'s `_ManualConfirmView`,
  /// which uses the result to surface a "this looks like X, not Y"
  /// warning before the user commits the entry.
  ///
  /// Returns the parsed body as a plain `Map<String, dynamic>`
  /// rather than a typed DTO — the response shape is small
  /// (`plausible` + `detected_instead`) and a single one-shot
  /// call site is the only consumer. Promoting to a typed
  /// `BeverageVerificationResult` model is a follow-up if the
  /// shape grows.
  ///
  /// **Failure semantics:** `ApiException` is thrown on any
  /// transport / parse failure. The caller in
  /// `photo_beverage_screen.dart` treats those as inconclusive
  /// — the verification call is best-effort, and a network blip
  /// should not block the user's save. The 422-specific friendly
  /// Russian hint pattern used by the other endpoints is
  /// intentionally NOT applied here: a 422 on the verification
  /// path means Gemini's plausibility response was unparseable,
  /// which is a transient / vendor-side problem — surfacing it
  /// to the user as "we couldn't verify" (with the dialog
  /// hidden) is the right escalation, and the message would
  /// either way be unhelpful in Russian.
  Future<Map<String, dynamic>> verifyBeverageName({
    required File imageFile,
    required String claimedName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: _filenameFromPath(imageFile.path),
        ),
        'claimed_name': claimedName,
      });

      final res = await _dio.post<Map<String, dynamic>>(
        '/food/verify-beverage-name',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final body = res.data;
      if (body == null) {
        throw const ApiException('Server returned an empty response.', messageKey: 'userFacingErrorServerEmpty');
      }
      return body;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

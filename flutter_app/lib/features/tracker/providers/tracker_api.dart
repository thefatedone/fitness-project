// ignore_for_file: use_null_aware_elements
// Dart currently has no null-aware *value* syntax for map entries — `if (k
// != null) k: v` is the canonical pattern. The lint is a false positive
// here; silencing it file-wide keeps the request body readable.

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_api.dart';
import '../models/food_log_model.dart';
import '../models/water_log_model.dart';
import '../models/weight_log_model.dart';

/// HTTP client for the NutriMind food / water / weight tracker endpoints.
///
/// Single responsibility: talk to the seven `/api/v1/tracker/*` routes the
/// app needs, decode their payloads into the [FoodLogModel] /
/// [WaterLogModel] / [WeightLogModel] / [WeightHistoryEntry] types defined
/// alongside it, and surface any failure as an [ApiException] from the auth
/// layer (re-used so callers have one exception type to catch across the
/// app).
///
/// No caching, no state — this is a thin transport. Higher layers
/// (repositories, providers) layer business logic and UI state on top.
///
/// **List-mutation policy (REGRESSION GUARD):** the four `getXxx`
/// methods below return lists that are assigned *directly* into
/// [TrackerProvider]'s `foodLogs` / `waterLogs` / `weightHistory`
/// fields via `loadDailyData` / `loadWeightHistory`. They MUST
/// therefore build the return value with plain `.toList()` —
/// never `.toList(growable: false)`. A non-growable list assigned
/// to one of those fields is a landmine: the moment any caller
/// stops using safe-by-spread mutation (`[...foodLogs, x]`, which
/// copies regardless of growability) and switches to
/// `.add(...)` / `.remove(...)` / `.removeAt(...)`, the next call
/// crashes with "Cannot add to a fixed-length list". The same
/// rule is enforced in `tracker_provider.dart` — see the
/// `REGRESSION GUARD` on `TrackerProvider.updateLocalFoodEntry`
/// for the canonical write-up of the failure mode that this rule
/// prevents.
class TrackerApi {
  /// The shared HTTP client. Reusing [apiClient] means the auth-token
  /// interceptor from `core/api/api_client.dart` attaches the bearer
  /// header automatically — never add it manually here.
  final Dio _dio = apiClient.dio;

  // ----- Food logs -------------------------------------------------------------

  /// `GET /api/v1/tracker/daily?date_str=YYYY-MM-DD`
  ///
  /// [date] is normalised to a calendar-date string in the user's *local*
  /// timezone — matching what the existing web client does — so that a log
  /// written at 23:30 local on the 19th is still queryable as "the 19th"
  /// the next morning, regardless of UTC offsets.
  ///
  /// The returned list is assigned directly into
  /// `TrackerProvider.foodLogs`; see the class-level
  /// REGRESSION GUARD above for why this MUST end in
  /// plain `.toList()` (not `growable: false`).
  Future<List<FoodLogModel>> getDailyFood(DateTime date) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/tracker/daily',
        queryParameters: {'date_str': _formatDate(date)},
      );
      final list = res.data ?? const [];
      return list
          .cast<Map<String, dynamic>>()
          .map(FoodLogModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `POST /api/v1/tracker/food`. Sends the body via [FoodLogModel.toCreateJson].
  Future<FoodLogModel> addFood(FoodLogModel food) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/tracker/food',
        data: food.toCreateJson(),
      );
      final body = res.data;
      if (body == null) {
        throw const ApiException('Сервер вернул пустой ответ.');
      }
      return FoodLogModel.fromJson(body);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `DELETE /api/v1/tracker/food/{foodId}`.
  Future<void> deleteFood(String foodId) async {
    try {
      await _dio.delete<void>('/tracker/food/$foodId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ----- Water logs ------------------------------------------------------------

  /// `GET /api/v1/tracker/water?date_str=YYYY-MM-DD`.
  ///
  /// Return value assigned directly into
  /// `TrackerProvider.waterLogs`; see the class-level
  /// REGRESSION GUARD above.
  Future<List<WaterLogModel>> getWaterLogs(DateTime date) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/tracker/water',
        queryParameters: {'date_str': _formatDate(date)},
      );
      final list = res.data ?? const [];
      return list
          .cast<Map<String, dynamic>>()
          .map(WaterLogModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `POST /api/v1/tracker/water`. [amountMl] is the volume in millilitres.
  Future<WaterLogModel> addWater(DateTime date, int amountMl) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/tracker/water',
        data: {
          'date': date.toIso8601String(),
          'amount': amountMl,
        },
      );
      final body = res.data;
      if (body == null) {
        throw const ApiException('Сервер вернул пустой ответ.');
      }
      return WaterLogModel.fromJson(body);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `DELETE /api/v1/tracker/water/{waterId}`.
  Future<void> deleteWater(String waterId) async {
    try {
      await _dio.delete<void>('/tracker/water/$waterId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ----- Weight logs -----------------------------------------------------------

  /// `GET /api/v1/tracker/weight` (no date filter — returns the full history).
  ///
  /// Note: currently unused in the codebase. If a future caller wires
  /// this up to a provider field, follow the class-level
  /// REGRESSION GUARD and assign through plain `.toList()`.
  Future<List<WeightLogModel>> getWeightLogs() async {
    try {
      final res = await _dio.get<List<dynamic>>('/tracker/weight');
      final list = res.data ?? const [];
      return list
          .cast<Map<String, dynamic>>()
          .map(WeightLogModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `POST /api/v1/tracker/weight`. [note] is optional.
  Future<WeightLogModel> addWeight(
    DateTime date,
    double weight, {
    String? note,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/tracker/weight',
        data: {
          'date': date.toIso8601String(),
          'weight': weight,
          if (note != null) 'note': note,
        },
      );
      final body = res.data;
      if (body == null) {
        throw const ApiException('Сервер вернул пустой ответ.');
      }
      return WeightLogModel.fromJson(body);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `GET /api/v1/tracker/weight/history`. The `date` field on each row is a
  /// date-only string, so this method yields [WeightHistoryEntry] (with the
  /// matching loose-typed `date`) rather than [WeightLogModel].
  ///
  /// Return value assigned directly into
  /// `TrackerProvider.weightHistory`; see the class-level
  /// REGRESSION GUARD above.
  Future<List<WeightHistoryEntry>> getWeightHistory() async {
    try {
      final res = await _dio.get<List<dynamic>>('/tracker/weight/history');
      final list = res.data ?? const [];
      return list
          .cast<Map<String, dynamic>>()
          .map(WeightHistoryEntry.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ----- private helpers -------------------------------------------------------

  /// Formats a [DateTime] as `yyyy-MM-dd` in its local timezone, without
  /// pulling in `package:intl`. Two-digit padding for month / day keeps
  /// the output lexicographically sortable, which matches what the FastAPI
  /// `date_str` query parser expects.
  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

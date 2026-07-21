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
          .toList(growable: false);
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
          .toList(growable: false);
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

  // ----- Weight logs -----------------------------------------------------------

  /// `GET /api/v1/tracker/weight` (no date filter — returns the full history).
  Future<List<WeightLogModel>> getWeightLogs() async {
    try {
      final res = await _dio.get<List<dynamic>>('/tracker/weight');
      final list = res.data ?? const [];
      return list
          .cast<Map<String, dynamic>>()
          .map(WeightLogModel.fromJson)
          .toList(growable: false);
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
  Future<List<WeightHistoryEntry>> getWeightHistory() async {
    try {
      final res = await _dio.get<List<dynamic>>('/tracker/weight/history');
      final list = res.data ?? const [];
      return list
          .cast<Map<String, dynamic>>()
          .map(WeightHistoryEntry.fromJson)
          .toList(growable: false);
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

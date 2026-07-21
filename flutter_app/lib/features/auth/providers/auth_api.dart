import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/user_model.dart';

/// Thrown by [AuthApi] when the backend rejects a request or the network
/// is unreachable.
///
/// Single responsibility: carry a user-presentable message out of the HTTP
/// layer. Higher layers ([AuthProvider]) display this string directly in
/// toasts / banners, so the wording here is intentionally concise and
/// Russian-language to match the rest of the app's UI.
class ApiException implements Exception {
  /// Human-readable message, ready to show in the UI.
  final String message;

  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';

  /// Builds an [ApiException] from a Dio failure.
  ///
  /// Precedence:
  ///   1. If the backend returned an HTTP error body, extract its `detail`
  ///      field. FastAPI typically sends either `{"detail": "..."}` (custom
  ///      HTTPException) or `{"detail": [{loc, msg, type}, ...]}` (422
  ///      validation). We surface a single message in both cases.
  ///   2. If the failure was a network-level problem (timeout, no internet,
  ///      TLS error), return a Russian message that hints at connectivity.
  ///   3. As a last resort, fall back to the generic message requested by the
  ///      product spec.
  factory ApiException.fromDioError(DioException e) {
    // (1) Server-provided error message.
    final response = e.response;
    if (response != null) {
      final detail = _extractDetail(response.data);
      if (detail != null && detail.isNotEmpty) {
        return ApiException(detail);
      }
    }

    // (2) Network-layer failures.
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          'Сервер не отвечает. Проверь соединение и попробуй ещё раз.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'Нет связи с сервером. Проверь интернет-соединение.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          'Не удалось установить безопасное соединение с сервером.',
        );
      case DioExceptionType.cancel:
        return const ApiException('Запрос был отменён.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    // (3) Generic fallback.
    return const ApiException(
      'Что-то пошло не так. Проверь соединение и попробуй снова.',
    );
  }

  /// Pulls a user-presentable string out of the FastAPI error envelope.
  /// Handles both string `detail` and the list form used for validation
  /// errors. Returns `null` if the body shape is unrecognised.
  static String? _extractDetail(dynamic data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) return first['msg'] as String;
    }
    return null;
  }
}

/// Client-side mirror of the backend's password policy.
///
/// Returns `null` when [password] is acceptable, otherwise a Russian
/// explanation that the UI can show inline next to the password field.
///
/// Rules (must match `backend/app/api/v1/routes/auth.py`):
///   * At least 8 characters.
///   * First character must be uppercase.
///   * At least one digit somewhere in the string.
///
/// We use Unicode-aware patterns (`\p{Lu}`, `\p{Nd}`) so the client-side rule
/// matches the backend's `str.isupper()` / `str.isdigit()` checks, which are
/// Unicode-aware in Python 3 — i.e. `А` (Cyrillic A) and `１` (fullwidth 1)
/// are both accepted by both sides.
String? validatePassword(String password) {
  if (password.length < 8) {
    return 'Пароль должен содержать минимум 8 символов';
  }
  if (!RegExp(r'^\p{Lu}', unicode: true).hasMatch(password)) {
    return 'Первая буква пароля должна быть заглавной';
  }
  if (!RegExp(r'\p{Nd}', unicode: true).hasMatch(password)) {
    return 'Пароль должен содержать хотя бы одну цифру';
  }
  return null;
}

/// Auth-related network calls for the NutriMind mobile app.
///
/// Single responsibility: speak HTTP to the three auth/user endpoints the
/// app needs (`POST /auth/register`, `POST /auth/login`, `GET /users/me`),
/// translate Dio errors into [ApiException]s, and decode the typed payload
/// ([UserModel] for `/users/me`). Higher layers ([AuthProvider]) layer
/// caching, retry, and UI state on top.
///
/// All methods rethrow [ApiException] on failure so callers can `catch`
/// just one exception type and present a message directly.
class AuthApi {
  /// The shared HTTP client. Reusing [apiClient] ensures the auth-token
  /// interceptor (and any future cross-cutting config) is in effect.
  final Dio _dio = apiClient.dio;

  /// Registers a new account.
  ///
  /// Either [email] or [phone] must be non-null on the server side. We send
  /// both as `null` when absent rather than omitting the key, so the JSON
  /// shape is deterministic and easier to log.
  ///
  /// Returns the `access_token` issued by the backend. The caller is
  /// responsible for persisting it via [tokenStorage].
  Future<String> register({
    String? email,
    String? phone,
    required String password,
    required String fullName,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'phone': phone,
          'password': password,
          'full_name': fullName,
        },
      );
      return _extractAccessToken(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Logs the user in with either [email] or [phone] + [password].
  ///
  /// Returns the `access_token` issued by the backend. The caller is
  /// responsible for persisting it via [tokenStorage].
  Future<String> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'phone': phone,
          'password': password,
        },
      );
      return _extractAccessToken(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Fetches the authenticated user's profile from `GET /users/me`.
  ///
  /// Requires a valid access token to be present in [tokenStorage] — the
  /// auth interceptor on [apiClient.dio] will attach it automatically.
  /// On 401 the server's `detail` (e.g. "Invalid token") is surfaced as an
  /// [ApiException] so the caller can decide to log the user out.
  Future<UserModel> fetchCurrentUser() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/users/me');
      final data = res.data;
      if (data == null) {
        throw const ApiException('Сервер вернул пустой ответ.');
      }
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Pulls the `access_token` out of the standard `{access_token, token_type}`
  /// response envelope. Throws [ApiException] if the shape is unexpected so
  /// the user never sees a confusing `null` token downstream.
  String _extractAccessToken(Map<String, dynamic>? body) {
    if (body == null) {
      throw const ApiException('Сервер вернул пустой ответ.');
    }
    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Сервер не выдал токен авторизации.');
    }
    return token;
  }
}

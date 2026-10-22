import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_api.dart';
import '../models/saved_meal_model.dart';
import '../models/food_log_model.dart';
import '../models/water_log_model.dart';
import '../models/weight_log_model.dart';
import '../models/beverage_result.dart';
import '../models/food_recognition_result.dart';
import 'diary_recovery_store.dart';

class PendingSave {
  final String id, route, slot;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> query;
  final String? imageHash;
  final Map<String, dynamic> timeHeaders;
  const PendingSave({
    required this.id,
    required this.route,
    required this.slot,
    required this.payload,
    this.query = const {},
    this.imageHash,
    this.timeHeaders = const {},
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'route': route,
    'slot': slot,
    'payload': payload,
    'query': query,
    'image_hash': imageHash,
    'time_headers': timeHeaders,
  };
  factory PendingSave.fromJson(Map<String, dynamic> json) => PendingSave(
    id: json['id'] as String,
    route: json['route'] as String,
    slot: json['slot'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    query: Map<String, dynamic>.from(json['query'] as Map),
    imageHash: json['image_hash'] as String?,
    timeHeaders: Map<String, dynamic>.from(json['time_headers'] as Map? ?? {}),
  );
}

/// One uncertain JSON save per route. Photos retain keys by their byte hash.
/// Original bodies and timestamps survive restart, scoped by account/API host.
class SaveCoordinator extends ChangeNotifier {
  final Dio _dio;
  DiaryRecoveryStore? _store;
  Future<void>? _ready;
  int _generation = 0;
  Future<void> _stateTail = Future<void>.value();
  final _pending = <String, PendingSave>{};
  final _busy = <String>{};
  SaveCoordinator({Dio? dio, DiaryRecoveryStore? store})
    : _dio = dio ?? apiClient.dio {
    _store = store;
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  List<PendingSave> get pending =>
      _pending.values.where((v) => !_busy.contains(v.route)).toList();
  bool isBusy(String route) => _busy.contains(route);
  Future<void> get ready => _ready ??= _load();

  void bind(DiaryRecoveryStore? store) {
    if (_store?.namespace == store?.namespace) {
      return;
    }
    _generation++;
    _store = store;
    _ready = null;
    _pending.clear();
    _busy.clear();
    final generation = _generation;
    scheduleMicrotask(() async {
      try {
        await ready;
      } catch (_) {
        /* Retain disk data for another read. */
      }
      if (generation == _generation) {
        notifyListeners();
      }
    });
  }

  Future<void> _load() async {
    final generation = _generation;
    try {
      final data = await _store?.read('save-requests');
      if (generation != _generation) {
        return;
      }
      for (final value in (data?['requests'] as List? ?? [])) {
        final save = PendingSave.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        _pending[save.slot] = save;
      }
    } catch (_) {
      if (generation == _generation) {
        _ready = null;
      }
      rethrow;
    }
  }

  Future<T> _change<T>(int generation, Future<T> Function() operation) {
    final result = _stateTail.then((_) async {
      if (generation != _generation) {
        throw StateError('Account changed');
      }
      return operation();
    });
    _stateTail = result.then<void>((_) {}).catchError((Object _) {});
    return result;
  }

  Future<void> _persist(Map<String, PendingSave> entries) async =>
      _store?.write('save-requests', {
        'requests': entries.values.map((v) => v.toJson()).toList(),
      });

  // Tapping Retry seconds later must reuse the originally selected timestamp.
  String _semantic(Map<String, dynamic> body) {
    final normalized = Map<String, dynamic>.from(body);
    if (normalized['date'] case final String date) {
      normalized['date'] = date.split('T').first;
    }
    return jsonEncode({
      for (final key in normalized.keys.toList()..sort()) key: normalized[key],
    });
  }

  Future<T> json<T>(
    String route,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) decode,
  ) => _run(route: route, body: body, decode: decode);

  Future<T> photo<T>(
    String route,
    File image,
    Map<String, dynamic> query,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final hash = (await sha256.bind(image.openRead()).first).toString();
    return _run(
      route: route,
      body: const {},
      query: query,
      image: image,
      imageHash: hash,
      decode: decode,
    );
  }

  Future<T> _run<T>({
    required String route,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) decode,
    Map<String, dynamic> query = const {},
    File? image,
    String? imageHash,
  }) async {
    if (_busy.contains(route)) {
      throw const ApiException('Save in progress', messageKey: 'mealSaving');
    }
    final generation = _generation;
    _busy.add(route);
    notifyListeners();
    PendingSave? attempt;
    try {
      await ready;
      if (generation != _generation) {
        throw StateError('Account changed');
      }
      final slot = imageHash == null
          ? route
          : '$route:$imageHash:${jsonEncode(query)}';
      final active = await _change<PendingSave>(generation, () async {
        final existing = _pending[slot];
        if (existing != null) {
          if (_semantic(existing.payload) != _semantic(body) ||
              jsonEncode(existing.query) != jsonEncode(query)) {
            throw const ApiException(
              'Resolve the previous save first',
              messageKey: 'savePendingDifferent',
            );
          }
          return existing;
        }
        final captured = DateTime.now();
        final created = PendingSave(
          id: newMealId(),
          route: route,
          slot: slot,
          payload: Map<String, dynamic>.from(
            jsonDecode(jsonEncode(body)) as Map,
          ),
          query: Map.of(query),
          imageHash: imageHash,
          timeHeaders: {
            'X-Diary-Offset-Minutes': captured.timeZoneOffset.inMinutes
                .toString(),
            'X-Diary-Captured-At': captured.toUtc().toIso8601String(),
          },
        );
        await _persist({..._pending, slot: created});
        if (generation != _generation) {
          throw StateError('Account changed');
        }
        _pending[slot] = created;
        return created;
      });
      attempt = active;
      Object data = active.payload;
      if (image != null) {
        final extension = image.path.split('.').last.toLowerCase();
        final subtype = switch (extension) {
          'png' => 'png',
          'webp' => 'webp',
          'heic' => 'heic',
          'heif' => 'heif',
          _ => 'jpeg',
        };
        data = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            image.path,
            filename: 'upload.$extension',
            contentType: DioMediaType('image', subtype),
          ),
        });
      }
      final response = await _dio.post<Map<String, dynamic>>(
        route,
        data: data,
        queryParameters: active.query,
        options: Options(
          headers: {'Idempotency-Key': active.id, ...active.timeHeaders},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      if (generation != _generation) {
        throw StateError('Account changed');
      }
      if (response.data == null) {
        throw const ApiException(
          'Empty save response',
          messageKey: 'userFacingErrorServerEmpty',
        );
      }
      _validate(active, response.data!);
      final result = decode(response.data!);
      await _ack(active, generation);
      return result;
    } on DioException catch (error) {
      if (generation != _generation) rethrow;
      final status = error.response?.statusCode;
      // A definite rejection rolled back server-side. Timeouts, 429 and 5xx
      // remain uncertain; 409 needs inspection of the existing operation.
      if (attempt != null &&
          [400, 403, 404, 410, 413, 415, 422].contains(status)) {
        await _ack(attempt, generation);
      }
      if (status == 422 && imageHash != null) {
        throw ApiException(
          'Could not recognize the photo',
          messageKey: route == '/food/recognize-beverage'
              ? 'userFacingErrorBeverageRecognize'
              : 'userFacingErrorFoodPhotoRecognize',
        );
      }
      if (status == 410) {
        throw const ApiException(
          'Saved entry was deleted',
          messageKey: 'saveAlreadyDeleted',
        );
      }
      throw ApiException.fromDioError(error);
    } finally {
      if (generation == _generation) {
        _busy.remove(route);
        notifyListeners();
      }
    }
  }

  Future<void> _ack(PendingSave attempt, int generation) =>
      _change(generation, () async {
        final remaining = {..._pending}..remove(attempt.slot);
        await _persist(remaining);
        if (generation != _generation) {
          throw StateError('Account changed');
        }
        _pending.remove(attempt.slot);
      });

  void _validate(PendingSave save, Map<String, dynamic> data) {
    if (save.route.startsWith('/food/')) {
      final beverage = save.route != '/food/recognize-and-log';
      if (beverage && data['auto_logged'] is! bool) {
        throw const FormatException('Missing beverage save status');
      }
      if (data['auto_logged'] == false) {
        if (data['suggestion'] is! Map) {
          throw const FormatException('Missing beverage suggestion');
        }
      } else {
        if (data['food_log_id'] is! String ||
            (data['food_log_id'] as String).isEmpty ||
            data['nutrition'] is! Map ||
            data['logged_at'] is! String ||
            (beverage &&
                (data['water_log_id'] is! String ||
                    (data['water_log_id'] as String).isEmpty))) {
          throw const FormatException('Missing saved entry identifiers');
        }
      }
    }
    switch (save.route) {
      case '/tracker/food':
        FoodLogModel.fromJson(data);
      case '/tracker/water':
        WaterLogModel.fromJson(data);
      case '/tracker/weight':
        WeightLogModel.fromJson(data);
      case '/food/log-beverage-manual':
      case '/food/recognize-beverage':
        BeverageRecognitionResult.fromJson(data);
      case '/food/recognize-and-log':
        FoodRecognitionResult.fromJson(data);
    }
  }

  Future<Map<String, dynamic>> resolve(PendingSave save) async {
    if (save.imageHash == null) {
      return json(save.route, save.payload, (data) {
        _validate(save, data);
        return data;
      });
    }
    if (_busy.contains(save.route)) {
      throw const ApiException('Save in progress', messageKey: 'mealSaving');
    }
    final generation = _generation;
    _busy.add(save.route);
    notifyListeners();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/tracker/saves/${save.id}',
      );
      if (response.data == null) {
        throw const ApiException('Empty save response');
      }
      final data = response.data!;
      if (data['auto_logged'] == false) {
        throw const ApiException(
          'Select the same photo again',
          messageKey: 'savePhotoRetry',
        );
      }
      _validate(save, data);
      await _ack(save, generation);
      return data;
    } on DioException catch (error) {
      if (generation != _generation) rethrow;
      if (error.response?.statusCode == 410) {
        await _ack(save, generation);
        throw const ApiException(
          'Saved entry was deleted',
          messageKey: 'saveAlreadyDeleted',
        );
      }
      if (error.response?.statusCode == 404) {
        throw const ApiException(
          'Save not confirmed yet',
          messageKey: 'savePhotoRetry',
        );
      }
      throw ApiException.fromDioError(error);
    } finally {
      if (generation == _generation) {
        _busy.remove(save.route);
        notifyListeners();
      }
    }
  }
}

final saveCoordinator = SaveCoordinator();

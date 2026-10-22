import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutrimind/features/tracker/models/food_log_model.dart';
import 'package:nutrimind/features/tracker/models/saved_meal_model.dart';
import 'package:nutrimind/features/tracker/services/save_coordinator.dart';
import 'package:nutrimind/features/tracker/services/diary_recovery_store.dart';
import 'package:nutrimind/features/tracker/widgets/save_recovery_notice.dart';
import 'package:nutrimind/l10n/gen/app_localizations.dart';

Map<String, dynamic> food({
  String date = '2026-10-21T12:00:00',
  String name = 'Rice',
}) => {
  'date': date,
  'meal_type': 'lunch',
  'food_name': name,
  'quantity': 100,
  'unit': 'g',
  'calories': 130,
  'protein': 3,
  'carbs': 28,
  'fat': 1,
};
DiaryRecoveryStore store([String user = 'owner']) =>
    DiaryRecoveryStore(userId: user, environment: 'test');

class SaveServer implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final bodies = <Map<String, dynamic>>[];
  final saved = <String, Map<String, dynamic>>{};
  bool loseFirst = true, deleted = false, malformed = false, reject422 = false;
  Completer<void>? wait;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};
    bodies.add(Map<String, dynamic>.from(jsonDecode(jsonEncode(body)) as Map));
    if (wait != null) {
      await wait!.future;
    }
    final key = options.method == 'GET'
        ? options.path.split('/').last
        : options.headers['Idempotency-Key'] as String;
    if (deleted) {
      return response({}, 410);
    }
    if (reject422) {
      return response({}, 422);
    }
    if (options.method == 'GET' && !saved.containsKey(key)) {
      return response({}, 404);
    }
    saved.putIfAbsent(
      key,
      () => options.path.startsWith('/food/')
          ? {
              'success': true,
              'food_log_id': 'saved-${saved.length}',
              'auto_logged': true,
              'logged_at': '2026-10-21T12:00:00',
              'nutrition': {
                'food_name': 'Rice',
                'quantity': 100,
                'unit': 'g',
                'calories': 130,
                'protein': 3,
                'carbs': 28,
                'fat': 1,
              },
            }
          : {
              ...body,
              'id': 'saved-${saved.length}',
              'user_id': 'owner',
              'created_at': '2026-10-21T12:00:00',
            },
    );
    if (loseFirst) {
      loseFirst = false;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'Response lost after commit',
      );
    }
    return response(malformed ? {} : saved[key]!);
  }

  ResponseBody response(Map<String, dynamic> body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  void close({bool force = false}) {}
}

Dio dio(SaveServer server) =>
    Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = server;

class FailedStore extends DiaryRecoveryStore {
  FailedStore() : super(userId: 'owner', environment: 'test');
  @override
  Future<void> write(String key, Map<String, dynamic> value) async =>
      throw StateError('Storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'lost response retry across restart preserves key, body and original timestamp',
    () async {
      final server = SaveServer();
      var coordinator = SaveCoordinator(dio: dio(server), store: store());
      await expectLater(
        coordinator.json('/tracker/food', food(), FoodLogModel.fromJson),
        throwsException,
      );
      expect(coordinator.pending, hasLength(1));
      final first = server.calls.first.headers['Idempotency-Key'];
      coordinator.dispose();
      coordinator = SaveCoordinator(dio: dio(server), store: store());
      addTearDown(coordinator.dispose);
      final saved = await coordinator.json(
        '/tracker/food',
        food(date: '2026-10-21T12:05:00'),
        FoodLogModel.fromJson,
      );
      expect(saved.id, 'saved-0');
      expect(server.calls.last.headers['Idempotency-Key'], first);
      expect(server.bodies[0], server.bodies[1]);
      for (final header in ['X-Diary-Offset-Minutes', 'X-Diary-Captured-At']) {
        expect(server.calls.first.headers[header], isNotNull);
        expect(
          server.calls.last.headers[header],
          server.calls.first.headers[header],
        );
      }
      expect(server.saved, hasLength(1));
      expect(coordinator.pending, isEmpty);
      final again = await coordinator.json(
        '/tracker/food',
        food(),
        FoodLogModel.fromJson,
      );
      expect(again.id, isNot(saved.id));
      expect(server.saved, hasLength(2));
    },
  );
  test('changed values cannot silently replace an uncertain save', () async {
    final server = SaveServer();
    final coordinator = SaveCoordinator(dio: dio(server), store: store());
    addTearDown(coordinator.dispose);
    await expectLater(
      coordinator.json('/tracker/food', food(), FoodLogModel.fromJson),
      throwsException,
    );
    await expectLater(
      coordinator.json(
        '/tracker/food',
        food(name: 'Fish'),
        FoodLogModel.fromJson,
      ),
      throwsException,
    );
    expect(server.calls, hasLength(1));
    await coordinator.resolve(coordinator.pending.single);
    expect(coordinator.pending, isEmpty);
    expect(server.saved, hasLength(1));
  });
  test('failed storage prevents sending a save', () async {
    final server = SaveServer();
    final coordinator = SaveCoordinator(dio: dio(server), store: FailedStore());
    addTearDown(coordinator.dispose);
    await expectLater(
      coordinator.json('/tracker/food', food(), FoodLogModel.fromJson),
      throwsStateError,
    );
    expect(server.calls, isEmpty);
  });
  test('rapid calls to the same route dispatch one request', () async {
    final server = SaveServer()
      ..loseFirst = false
      ..wait = Completer<void>();
    final coordinator = SaveCoordinator(dio: dio(server), store: store());
    addTearDown(coordinator.dispose);
    final first = coordinator.json(
      '/tracker/food',
      food(),
      FoodLogModel.fromJson,
    );
    await expectLater(
      coordinator.json('/tracker/food', food(), FoodLogModel.fromJson),
      throwsException,
    );
    server.wait!.complete();
    await first;
    expect(server.calls, hasLength(1));
  });
  test(
    'concurrent saves of different types retain both durable attempts',
    () async {
      final server = SaveServer()..wait = Completer<void>();
      final coordinator = SaveCoordinator(dio: dio(server), store: store());
      addTearDown(coordinator.dispose);
      final first = coordinator
          .json('/tracker/food', food(), (v) => v)
          .then<void>((_) {}, onError: (Object _) {});
      final second = coordinator
          .json('/tracker/water', {
            'date': '2026-10-21',
            'amount': 250,
          }, (v) => v)
          .then<void>((_) {}, onError: (Object _) {});
      await Future<void>.delayed(Duration.zero);
      final persisted = await store().read('save-requests');
      expect(persisted!['requests'], hasLength(2));
      server.wait!.complete();
      await Future.wait([first, second]);
    },
  );
  test(
    'malformed responses keep the same save ID until decoding succeeds',
    () async {
      final server = SaveServer()
        ..loseFirst = false
        ..malformed = true;
      final coordinator = SaveCoordinator(dio: dio(server), store: store());
      addTearDown(coordinator.dispose);
      await expectLater(
        coordinator.json('/tracker/food', food(), FoodLogModel.fromJson),
        throwsA(isA<TypeError>()),
      );
      final key = server.calls.first.headers['Idempotency-Key'];
      server.malformed = false;
      await coordinator.json('/tracker/food', food(), FoodLogModel.fromJson);
      expect(server.calls.last.headers['Idempotency-Key'], key);
      expect(server.saved, hasLength(1));
    },
  );
  test(
    'identical photo bytes reuse the persisted key after restart and rename',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nutrimind-save-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final image = await File(
        '${directory.path}/first.jpg',
      ).writeAsBytes([255, 216, 1, 2, 3]);
      final copy = await image.copy('${directory.path}/renamed.jpg');
      final server = SaveServer();
      var coordinator = SaveCoordinator(dio: dio(server), store: store());
      await expectLater(
        coordinator.photo('/food/recognize-and-log', image, {
          'meal_type': 'lunch',
        }, (v) => v),
        throwsException,
      );
      final key = server.calls.first.headers['Idempotency-Key'];
      coordinator.dispose();
      coordinator = SaveCoordinator(dio: dio(server), store: store());
      addTearDown(coordinator.dispose);
      await coordinator.photo('/food/recognize-and-log', copy, {
        'meal_type': 'lunch',
      }, (v) => v);
      expect(server.calls.last.headers['Idempotency-Key'], key);
      expect(server.saved, hasLength(1));
    },
  );
  test(
    'deleted saved entries are acknowledged without silently recreating them',
    () async {
      final server = SaveServer();
      final coordinator = SaveCoordinator(dio: dio(server), store: store());
      addTearDown(coordinator.dispose);
      await expectLater(
        coordinator.json('/tracker/food', food(), FoodLogModel.fromJson),
        throwsException,
      );
      server.deleted = true;
      await expectLater(
        coordinator.resolve(coordinator.pending.single),
        throwsException,
      );
      expect(coordinator.pending, isEmpty);
      expect(server.saved, hasLength(1));
    },
  );
  test('account binding does not load another account pending saves', () async {
    final server = SaveServer();
    final coordinator = SaveCoordinator(dio: dio(server), store: store());
    addTearDown(coordinator.dispose);
    await expectLater(
      coordinator.json('/tracker/food', food(), FoodLogModel.fromJson),
      throwsException,
    );
    coordinator.bind(store('other'));
    await coordinator.ready;
    expect(coordinator.pending, isEmpty);
    expect((await store().read('save-requests'))!['requests'], hasLength(1));
  });
  testWidgets(
    'pending-save notice fits narrow screens and large text in RU EN KA',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final coordinator = SaveCoordinator(
        dio: dio(SaveServer()),
        store: store('ui'),
      );
      addTearDown(coordinator.dispose);
      await tester.runAsync(() async {
        final pending = PendingSave(
          id: newMealId(),
          route: '/tracker/food',
          slot: '/tracker/food',
          payload: food(name: 'Бурый рис с овощами'),
        );
        await store('ui').write('save-requests', {
          'requests': [pending.toJson()],
        });
        await coordinator.ready;
      });
      for (final locale in ['ru', 'en', 'ka']) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SaveRecoveryNotice(
                  coordinator: coordinator,
                  onResolve: (_) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: locale);
        expect(find.text('Бурый рис с овощами'), findsOneWidget);
      }
    },
  );
}

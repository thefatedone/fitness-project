import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nutrimind/core/api/api_client.dart';
import 'package:nutrimind/features/tracker/models/saved_meal_model.dart';
import 'package:nutrimind/features/tracker/models/food_log_model.dart';
import 'package:nutrimind/features/tracker/providers/tracker_provider.dart';
import 'package:nutrimind/features/tracker/providers/food_recognition_provider.dart';
import 'package:nutrimind/features/tracker/screens/meal_photo_screen.dart';
import 'package:nutrimind/features/tracker/widgets/meal_ingredient_dialog.dart';
import 'package:nutrimind/features/tracker/widgets/logged_meal_tile.dart';
import 'package:nutrimind/l10n/gen/app_localizations.dart';
import 'package:nutrimind/utils/accessibility_utils.dart';

SavedMealModel meal() => SavedMealModel(
  id: newMealId(),
  name: 'Обед',
  mealType: 'lunch',
  date: DateTime(2026, 10, 20),
  ingredients: const [
    MealIngredient(
      name: 'Рис',
      grams: 100,
      calories: 130,
      protein: 3,
      carbs: 28,
      fat: 1,
    ),
    MealIngredient(
      name: 'Курица',
      grams: 150,
      calories: 240,
      protein: 40,
      carbs: 0,
      fat: 8,
    ),
  ],
);

class QuietTracker extends TrackerProvider {
  @override
  Future<void> loadGarden() async {}
  @override
  Future<void> refreshStreakAfterSave() async {}
}

Widget host(Widget child, {String locale = 'ru', double scale = 1}) =>
    ReduceTransparencyScope(
      notifier: ReduceTransparencyNotifier.instance,
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: child,
      ),
    );

class MealAdapter implements HttpClientAdapter {
  final requests = <Map<String, dynamic>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(options.data)) as Map,
    );
    requests.add(body);
    if (requests.length == 1) {
      return ResponseBody.fromString(
        '{}',
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode([
        for (var i = 0; i < (body['ingredients'] as List).length; i++)
          {
            ...body['ingredients'][i] as Map,
            'id': '$i',
            'user_id': 'owner',
            'meal_id': body['id'],
            'meal_name': body['name'],
            'meal_type': body['meal_type'],
            'date': body['date'],
            'unit': 'g',
            'created_at': '2026-10-21T12:00:00',
          },
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('recipe restores portion totals and per-100g references', () {
    final source = meal();
    final restored = SavedMealModel.fromJson(source.toJson());
    expect(restored.toAnalysis().totals.kcal, 370);
    expect(restored.toAnalysis().items[1].per100g.kcal, 160);
    expect(restored.toJson(), source.toJson());
    expect(newMealId(), isNot(newMealId()));
  });
  testWidgets('weight rescales nutrition; invalid portions cannot save', (
    tester,
  ) async {
    MealIngredient? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showDialog<MealIngredient>(
                context: context,
                builder: (_) =>
                    MealIngredientDialog(ingredient: meal().ingredients.first),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '0');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    expect(find.text('Введите корректное значение'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(fields.at(0), 'Бурый рис');
    await tester.enterText(fields.at(1), '50');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(result!.name, 'Бурый рис');
    expect(result!.grams, 50);
    expect(result!.calories, 65);
    expect(result!.carbs, 14);
  });
  testWidgets('review saves whole dish; retry reuses snapshot and ID', (
    tester,
  ) async {
    final adapter = MealAdapter();
    final previousAdapter = apiClient.dio.httpClientAdapter;
    final interceptors = apiClient.dio.interceptors.toList();
    apiClient.dio.interceptors.clear();
    apiClient.dio.httpClientAdapter = adapter;
    addTearDown(() {
      apiClient.dio.httpClientAdapter = previousAdapter;
      apiClient.dio.interceptors.addAll(interceptors);
    });
    final tracker = QuietTracker()..selectedDate = DateTime(2026, 10, 21);
    final recognition = FoodRecognitionProvider()
      ..lastMealAnalysis = meal().toAnalysis();
    addTearDown(tracker.dispose);
    addTearDown(recognition.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TrackerProvider>.value(value: tracker),
          ChangeNotifierProvider.value(value: recognition),
        ],
        child: host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const MealPhotoScreen(mealType: 'lunch'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Название блюда',
      ),
      'Рис с курицей',
    );
    await tester.tap(find.text('Сохранить блюдо'));
    await tester.pumpAndSettle();
    expect(adapter.requests, hasLength(1));
    expect(tracker.foodLogs, isEmpty);
    expect(find.byType(MealPhotoScreen), findsOneWidget);
    await tester.tap(find.text('Сохранить блюдо'));
    await tester.pumpAndSettle();
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[0], adapter.requests[1]);
    expect(adapter.requests[0]['name'], 'Рис с курицей');
    expect(adapter.requests[0]['date'], startsWith('2026-10-21'));
    expect(adapter.requests[0]['ingredients'], hasLength(2));
    expect(tracker.foodLogs, hasLength(2));
    expect(tracker.totalCalories, 370);
    expect(find.byType(MealPhotoScreen), findsNothing);
  });
  testWidgets(
    'repeat editor fits narrow screens with large text in every locale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tracker = QuietTracker();
      final recognition = FoodRecognitionProvider();
      addTearDown(tracker.dispose);
      addTearDown(recognition.dispose);
      for (final locale in ['ru', 'en', 'ka']) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<TrackerProvider>.value(value: tracker),
              ChangeNotifierProvider.value(value: recognition),
            ],
            child: host(
              MealPhotoScreen(mealType: 'lunch', initialMeal: meal()),
              locale: locale,
              scale: 2,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: locale);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -650),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: locale);
      }
    },
  );
  testWidgets('logged dish expands and exposes repeat/delete actions', (
    tester,
  ) async {
    var repeated = false;
    var deleted = false;
    final source = meal();
    final rows = [
      for (var i = 0; i < source.ingredients.length; i++)
        FoodLogModel.fromJson({
          ...source.ingredients[i].toJson(),
          'id': '$i',
          'user_id': 'owner',
          'meal_id': source.id,
          'meal_name': source.name,
          'meal_type': 'lunch',
          'date': source.date.toIso8601String(),
          'unit': 'g',
          'created_at': source.date.toIso8601String(),
        }),
    ];
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ListView(
            children: [
              LoggedMealTile(
                ingredients: rows,
                onRepeat: () => repeated = true,
                onDelete: () => deleted = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Обед'));
    await tester.pumpAndSettle();
    expect(find.text('Рис'), findsOneWidget);
    await tester.tap(find.text('Повторить блюдо'));
    await tester.tap(find.text('Удалить'));
    expect(repeated, isTrue);
    expect(deleted, isTrue);
  });
}

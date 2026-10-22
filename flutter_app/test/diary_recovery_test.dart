import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutrimind/features/tracker/models/food_log_model.dart';
import 'package:nutrimind/features/tracker/models/water_log_model.dart';
import 'package:nutrimind/features/tracker/models/pending_diary_deletion.dart';
import 'package:nutrimind/features/tracker/models/saved_meal_model.dart';
import 'package:nutrimind/features/tracker/providers/tracker_api.dart';
import 'package:nutrimind/features/tracker/providers/tracker_provider.dart';
import 'package:nutrimind/features/tracker/services/diary_recovery_store.dart';
import 'package:nutrimind/features/tracker/widgets/diary_recovery_banner.dart';
import 'package:nutrimind/l10n/gen/app_localizations.dart';

final day = DateTime(2026, 10, 21);
FoodLogModel food(String id) => FoodLogModel(
  id: id,
  userId: 'owner',
  date: day,
  mealType: 'lunch',
  mealId: 'dish',
  mealName: 'Обед',
  foodName: id,
  calories: 100,
  protein: 10,
  carbs: 10,
  fat: 2,
  quantity: 100,
  unit: 'g',
  aiGenerated: false,
  createdAt: day,
);
final drink = WaterLogModel(
  id: 'water',
  userId: 'owner',
  date: day,
  amount: 250,
  createdAt: day,
);

class FakeApi extends TrackerApi {
  bool offline = false, loseDeleteResponse = false, failRestore = false;
  List<FoodLogModel> serverFoods = [food('rice'), food('fish')];
  List<WaterLogModel> serverWater = [drink];
  final requests = <PendingDiaryDeletion>[];
  final states = <String, String>{};
  @override
  Future<List<FoodLogModel>> getDailyFood(DateTime date) async {
    if (offline) {
      throw StateError('Offline');
    }
    return serverFoods.where((v) => v.date == date).toList();
  }

  @override
  Future<List<WaterLogModel>> getWaterLogs(DateTime date) async {
    if (offline) {
      throw StateError('Offline');
    }
    return serverWater.where((v) => v.date == date).toList();
  }

  @override
  Future<String> changeDeletion(PendingDiaryDeletion deletion) async {
    requests.add(deletion);
    if (offline || (deletion.restore && failRestore)) {
      throw StateError('Offline');
    }
    if (deletion.restore) {
      states[deletion.id] = 'restored';
      for (final f in deletion.foods) {
        if (!serverFoods.any((v) => v.id == f.id)) {
          serverFoods.add(f);
        }
      }
      for (final w in deletion.water) {
        if (!serverWater.any((v) => v.id == w.id)) {
          serverWater.add(w);
        }
      }
    } else if (states[deletion.id] != 'restored') {
      states[deletion.id] = 'deleted';
      serverFoods.removeWhere((v) => deletion.foods.any((f) => f.id == v.id));
      serverWater.removeWhere((v) => deletion.water.any((w) => w.id == v.id));
      if (loseDeleteResponse) {
        throw StateError('Response lost after commit');
      }
    }
    return states[deletion.id]!;
  }
}

class DelayedApi extends FakeApi {
  final delayed = Completer<List<FoodLogModel>>();
  @override
  Future<List<FoodLogModel>> getDailyFood(DateTime date) =>
      date == day ? delayed.future : Future.value([]);
}

class OneDelayedApi extends FakeApi {
  final first = Completer<List<FoodLogModel>>();
  bool waiting = true;
  @override
  Future<List<FoodLogModel>> getDailyFood(DateTime date) {
    if (waiting) {
      waiting = false;
      return first.future;
    }
    return super.getDailyFood(date);
  }
}

class QuietTracker extends TrackerProvider {
  QuietTracker(
    FakeApi api,
    DiaryRecoveryStore store, {
    super.undoWindow = const Duration(seconds: 10),
  }) : super(trackerApi: api, recoveryStore: store);
  @override
  Future<void> loadGarden() async {}
  @override
  Future<void> refreshStreakAfterSave() async {}
}

class FailingStore extends DiaryRecoveryStore {
  FailingStore() : super(userId: 'owner', environment: 'test');
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    if (key == 'deletion') {
      throw StateError('Disk unavailable');
    }
    return super.write(key, value);
  }
}

DiaryRecoveryStore store({
  String user = 'owner',
  String environment = 'test',
}) => DiaryRecoveryStore(userId: user, environment: environment);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('whole dish and water undo preserve IDs, grouping and totals', () async {
    final api = FakeApi();
    final tracker = QuietTracker(api, store());
    addTearDown(tracker.dispose);
    await tracker.loadDailyData(day);
    expect(await tracker.deleteFoodEntries(['rice', 'fish']), isTrue);
    expect(tracker.foodLogs, isEmpty);
    final id = tracker.pendingDeletion!.id;
    expect(await tracker.undoDeletion(), isTrue);
    expect(tracker.foodLogs.map((v) => v.id).toSet(), {'rice', 'fish'});
    expect(tracker.foodLogs.every((v) => v.mealId == 'dish'), isTrue);
    expect(tracker.totalCalories, 200);
    expect(api.requests.map((v) => v.id).toSet(), {id});
    expect(await tracker.deleteWaterEntry('water'), isTrue);
    expect(tracker.totalWaterMl, 0);
    expect(await tracker.undoDeletion(), isTrue);
    expect(tracker.totalWaterMl, 250);
    expect(tracker.pendingDeletion, isNull);
  });
  test(
    'lost delete response and offline undo survive process restart',
    () async {
      final api = FakeApi()..loseDeleteResponse = true;
      var tracker = QuietTracker(api, store());
      await tracker.loadDailyData(day);
      expect(await tracker.deleteFoodEntries(['rice', 'fish']), isFalse);
      expect(tracker.foodLogs, hasLength(2));
      final id = tracker.pendingDeletion!.id;
      expect(api.serverFoods, isEmpty);
      tracker.dispose();
      tracker = QuietTracker(api, store());
      await tracker.loadDailyData(day);
      expect(tracker.foodLogs, hasLength(2));
      expect(tracker.pendingDeletion!.id, id);
      api.failRestore = true;
      expect(await tracker.undoDeletion(), isFalse);
      expect(tracker.pendingDeletion!.restore, isTrue);
      expect(tracker.foodLogs, hasLength(2));
      tracker.dispose();
      tracker = QuietTracker(api, store());
      addTearDown(tracker.dispose);
      await tracker.loadDailyData(day);
      expect(tracker.foodLogs, hasLength(2));
      expect(tracker.pendingDeletion!.restore, isTrue);
      api.failRestore = false;
      expect(await tracker.retryPendingDeletion(), isTrue);
      expect(tracker.pendingDeletion, isNull);
      expect(api.serverFoods.map((v) => v.id).toSet(), {'rice', 'fish'});
      expect(await store().read('deletion'), isNull);
    },
  );
  test('failed local persistence prevents every destructive request', () async {
    final api = FakeApi();
    final tracker = QuietTracker(api, FailingStore());
    addTearDown(tracker.dispose);
    await tracker.loadDailyData(day);
    expect(await tracker.deleteFoodEntry('rice'), isFalse);
    expect(api.requests, isEmpty);
    expect(tracker.foodLogs, hasLength(2));
  });
  test('rapid duplicate delete taps dispatch only one operation', () async {
    final api = FakeApi();
    final tracker = QuietTracker(api, store());
    addTearDown(tracker.dispose);
    await tracker.loadDailyData(day);
    final results = await Future.wait([
      tracker.deleteFoodEntry('rice'),
      tracker.deleteFoodEntry('rice'),
    ]);
    expect(results.where((v) => v), hasLength(1));
    expect(api.requests, hasLength(1));
  });
  test('offline cache is date-, account- and environment-specific', () async {
    final api = FakeApi();
    var tracker = QuietTracker(api, store());
    await tracker.loadDailyData(day);
    await Future<void>.delayed(Duration.zero);
    tracker.dispose();
    api.offline = true;
    tracker = QuietTracker(api, store());
    await tracker.loadDailyData(day);
    expect(tracker.dailyDataStale, isTrue);
    expect(tracker.foodLogs, hasLength(2));
    await tracker.loadDailyData(day.add(const Duration(days: 1)));
    expect(tracker.foodLogs, isEmpty);
    expect(tracker.waterLogs, isEmpty);
    tracker.dispose();
    for (final other in [store(user: 'other'), store(environment: 'other')]) {
      final isolated = QuietTracker(api, other);
      addTearDown(isolated.dispose);
      await isolated.loadDailyData(day);
      expect(isolated.foodLogs, isEmpty);
    }
  });
  test(
    'meal snapshot survives restart with the same save ID and selected day',
    () async {
      final api = FakeApi();
      var tracker = QuietTracker(api, store());
      final draft = SavedMealModel(
        id: newMealId(),
        name: 'Обед',
        mealType: 'lunch',
        date: day,
        ingredients: const [
          MealIngredient(
            name: 'Рис',
            grams: 100,
            calories: 130,
            protein: 3,
            carbs: 28,
            fat: 1,
          ),
        ],
      );
      await tracker.persistMealDraft(draft);
      tracker.dispose();
      tracker = QuietTracker(api, store());
      addTearDown(tracker.dispose);
      await tracker.loadDailyData(day);
      expect(tracker.mealDraft!.toJson(), draft.toJson());
      await tracker.clearMealDraft('another');
      expect(tracker.mealDraft, isNotNull);
      await tracker.clearMealDraft(draft.id);
      expect(await store().read('meal-draft'), isNull);
    },
  );
  test(
    'committed meals update their original cached day before the draft is cleared',
    () async {
      final api = FakeApi();
      var tracker = QuietTracker(api, store());
      await tracker.loadDailyData(day);
      await tracker.loadDailyData(day.add(const Duration(days: 1)));
      await tracker.acceptCommittedMeal([food('new-meal')]);
      expect(tracker.foodLogs, isEmpty);
      tracker.dispose();
      api.offline = true;
      tracker = QuietTracker(api, store());
      addTearDown(tracker.dispose);
      await tracker.loadDailyData(day);
      expect(tracker.foodLogs.map((v) => v.id).toSet(), {
        'rice',
        'fish',
        'new-meal',
      });
      expect(tracker.totalWaterMl, 250);
    },
  );
  test('an older daily response cannot erase a newly saved entry', () async {
    final api = OneDelayedApi();
    final tracker = QuietTracker(api, store());
    addTearDown(tracker.dispose);
    final read = tracker.loadDailyData(day);
    await Future<void>.delayed(Duration.zero);
    final latest = food('newly-saved');
    api.serverFoods.add(latest);
    tracker.addLocalFoodEntry(latest);
    api.first.complete([food('rice'), food('fish')]);
    await read;
    await Future<void>.delayed(Duration.zero);
    expect(tracker.foodLogs.map((v) => v.id).toSet(), {
      'rice',
      'fish',
      'newly-saved',
    });
  });
  test('late date responses cannot overwrite the selected day', () async {
    final api = DelayedApi();
    final tracker = QuietTracker(api, store());
    addTearDown(tracker.dispose);
    final old = tracker.loadDailyData(day);
    await Future<void>.delayed(Duration.zero);
    await tracker.loadDailyData(day.add(const Duration(days: 1)));
    api.delayed.complete([food('old')]);
    await old;
    expect(tracker.selectedDate, day.add(const Duration(days: 1)));
    expect(tracker.foodLogs, isEmpty);
  });
  test(
    'late account responses cannot repopulate a different account',
    () async {
      final api = DelayedApi();
      final tracker = QuietTracker(api, store());
      addTearDown(tracker.dispose);
      final old = tracker.loadDailyData(day);
      await Future<void>.delayed(Duration.zero);
      tracker.bindAccount('other', environment: 'test');
      api.delayed.complete([food('private-old-account')]);
      await old;
      expect(tracker.foodLogs, isEmpty);
      expect(tracker.waterLogs, isEmpty);
      expect(tracker.pendingDeletion, isNull);
    },
  );
  test('a new save never overwrites an unresolved meal draft', () async {
    final tracker = QuietTracker(FakeApi(), store());
    addTearDown(tracker.dispose);
    final first = SavedMealModel(
      id: newMealId(),
      name: 'First',
      mealType: 'lunch',
      date: day,
      ingredients: const [],
    );
    final second = SavedMealModel(
      id: newMealId(),
      name: 'Second',
      mealType: 'lunch',
      date: day,
      ingredients: const [],
    );
    await tracker.persistMealDraft(first);
    await expectLater(
      tracker.persistMealDraft(second),
      throwsA(isA<UnresolvedMealDraft>()),
    );
    expect((await store().read('meal-draft'))!['id'], first.id);
  });
  test(
    'undo expiry reconciles the offline cache before forgetting the receipt',
    () async {
      final api = FakeApi();
      final tracker = QuietTracker(api, store(), undoWindow: Duration.zero);
      addTearDown(tracker.dispose);
      await tracker.loadDailyData(day);
      expect(await tracker.deleteFoodEntry('rice'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(tracker.pendingDeletion, isNull);
      api.offline = true;
      await tracker.loadDailyData(day);
      expect(tracker.foodLogs.map((v) => v.id).toList(), ['fish']);
    },
  );
  testWidgets(
    'recovery actions fit narrow screens and large text in all locales',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tracker = QuietTracker(FakeApi(), store())
        ..dailyDataStale = true
        ..pendingDeletion = PendingDiaryDeletion(
          id: newMealId(),
          foods: [food('rice')],
          water: [],
          undoUntil: day,
        );
      addTearDown(tracker.dispose);
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
                child: DiaryRecoveryBanner(
                  tracker: tracker,
                  onResumeMeal: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: locale);
      }
    },
  );
}

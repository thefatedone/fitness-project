import 'package:flutter/foundation.dart';

import '../../auth/providers/auth_api.dart';
import '../models/beverage_result.dart';
import '../models/food_log_model.dart';
import '../models/water_log_model.dart';
import '../models/weight_log_model.dart';
import 'tracker_api.dart';

/// `ChangeNotifier` that owns the food / water / weight tracker state for the
/// currently-selected day.
///
/// Single responsibility: load, mutate, and expose the list of tracker
/// entries for the day the user is looking at, plus their full weight
/// history, in a UI-friendly shape. All network calls route through
/// [TrackerApi]; all failure handling produces a single
/// [ApiException.message] string the UI can render directly.
///
/// The state model is intentionally small and per-day: switching the
/// date via [loadDailyData] replaces [foodLogs] / [waterLogs], but
/// [weightHistory] is global (the history endpoint returns everything).
class TrackerProvider extends ChangeNotifier {
  /// Local mid-night of "today" on app start. Loading another day overwrites
  /// this — it's the day the UI is currently displaying.
  DateTime selectedDate;

  /// Food entries logged for [selectedDate].
  List<FoodLogModel> foodLogs = const [];

  /// Water entries logged for [selectedDate].
  List<WaterLogModel> waterLogs = const [];

  /// Full weight history (newest-first per the backend).
  List<WeightHistoryEntry> weightHistory = const [];

  /// `true` while any tracker network call is in flight. UI uses this to
  /// disable the "+ Add" buttons and show a spinner.
  bool isLoading = false;

  /// Last user-facing error message, or `null` if the most recent action
  /// succeeded. Cleared at the start of every action.
  String? errorMessage;

  /// The shared HTTP client for tracker endpoints.
  final TrackerApi _trackerApi = TrackerApi();

  TrackerProvider() : selectedDate = _midnightOf(DateTime.now());

  // ---- computed views (no stored state) ------------------------------------

  /// Sum of every food entry's calories for [selectedDate].
  double get totalCalories =>
      foodLogs.fold<double>(0, (sum, f) => sum + f.calories);

  /// Sum of every food entry's protein in grams.
  double get totalProtein =>
      foodLogs.fold<double>(0, (sum, f) => sum + f.protein);

  /// Sum of every food entry's carbohydrates in grams.
  double get totalCarbs =>
      foodLogs.fold<double>(0, (sum, f) => sum + f.carbs);

  /// Sum of every food entry's fat in grams.
  double get totalFat =>
      foodLogs.fold<double>(0, (sum, f) => sum + f.fat);

  /// Sum of every water entry's volume in millilitres.
  int get totalWaterMl =>
      waterLogs.fold<int>(0, (sum, w) => sum + w.amount);

  /// Food entries grouped by `mealType`. The bucket set is derived
  /// dynamically from whatever meal types are actually present — the
  /// backend accepts any string, so we don't hardcode `"breakfast"` /
  /// `"lunch"` / `"dinner"` / `"snack"` here.
  Map<String, List<FoodLogModel>> get foodLogsByMeal {
    final grouped = <String, List<FoodLogModel>>{};
    for (final f in foodLogs) {
      grouped.putIfAbsent(f.mealType, () => []).add(f);
    }
    return grouped;
  }

  /// Most recent weight in [weightHistory], or `null` if no entries have
  /// been logged yet. The list is already newest-first per the backend.
  double? get latestWeight => weightHistory.isEmpty ? null : weightHistory.first.weight;

  /// Daily water-intake target in millilitres.
  ///
  /// Mirrors the web's `Math.round(userWeight * 35)` heuristic — a
  /// reasonable rough baseline of "drink 35 ml per kg of body weight
  /// per day" that lines up with common fitness-app defaults.
  ///
  /// The user's `currentWeight` lives on [AuthProvider.currentUser],
  /// not in this provider, so the cleanest path is to pass it in
  /// from the UI layer (where both providers are available via
  /// `context.watch`) rather than reaching across the
  /// tracker → auth dependency direction. The function is
  /// intentionally a plain static method (not a getter) so the UI
  /// doesn't need to subscribe to the auth provider just to call it
  /// — it can call once per build with the value it already read.
  static int computeDailyWaterGoalMl(double? currentWeightKg) {
    if (currentWeightKg == null) return 2000;
    return (currentWeightKg * 35).round();
  }

  // ---- public actions --------------------------------------------------------

  /// Loads both food and water logs for [date] in a single round-trip pair
  /// via [Future.wait]. Replaces [foodLogs] / [waterLogs] / [selectedDate]
  /// atomically on success. Errors from either call collapse into
  /// [errorMessage].
  Future<void> loadDailyData(DateTime date) async {
    selectedDate = _midnightOf(date);
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // A record of futures resolves to a record of results, preserving
      // each element's type. A plain `Future.wait([...])` over a mixed
      // `[Future<List<FoodLogModel>>, Future<List<WaterLogModel>>]` would
      // collapse to `Future<List<Object>>` and lose the per-list type.
      final (food, water) = await (
        _trackerApi.getDailyFood(selectedDate),
        _trackerApi.getWaterLogs(selectedDate),
      ).wait;
      foodLogs = food;
      waterLogs = water;
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the full weight history. Independent of [loadDailyData] — the
  /// history endpoint is global, not per-day.
  Future<void> loadWeightHistory() async {
    try {
      weightHistory = await _trackerApi.getWeightHistory();
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      notifyListeners();
    }
  }

  /// Adds a new food entry. The server-assigned row (with id +
  /// timestamps) is appended to [foodLogs] on success.
  Future<bool> addFoodEntry(FoodLogModel food) {
    return _runTrackerAction<FoodLogModel>(
      action: () => _trackerApi.addFood(food),
      onSuccess: (saved) {
        foodLogs = [...foodLogs, saved];
      },
    );
  }

  /// Removes the entry whose id matches [foodId] from [foodLogs] on
  /// success. Silently no-ops if the id is unknown (already deleted in a
  /// parallel tab / stale list).
  ///
  /// List-mutation note: the reassignment uses plain `.toList()`
  /// (defaults to `growable: true`) rather than
  /// `.toList(growable: false)`. The same is true for every other
  /// `foodLogs` / `waterLogs` reassignment in this file — see the
  /// corresponding comment on [updateLocalFoodEntry] for the
  /// rationale (a regression where these lists became non-growable
  /// caused "Cannot add to a fixed-length list" crashes downstream
  /// at `addLocalFoodEntry` time).
  Future<bool> deleteFoodEntry(String foodId) {
    return _runTrackerAction<void>(
      action: () => _trackerApi.deleteFood(foodId),
      onSuccess: (_) {
        foodLogs = foodLogs.where((f) => f.id != foodId).toList();
      },
    );
  }

  /// Removes the water entry whose id matches [waterId] from [waterLogs]
  /// on success. Same no-op-if-unknown semantics as
  /// [deleteFoodEntry]. The entry must come from TODAY's loaded
  /// `waterLogs`; the backend endpoint doesn't return entries from
  /// other days in this query, so deleting an id that's not in the
  /// current list is silently a no-op (matches the existing
  /// food-deleted pattern).
  ///
  /// List-mutation note: same as [deleteFoodEntry] — `.toList()`
  /// defaults to `growable: true`; never pass `growable: false`
  /// here.
  Future<bool> deleteWaterEntry(String waterId) {
    return _runTrackerAction<void>(
      action: () => _trackerApi.deleteWater(waterId),
      onSuccess: (_) {
        waterLogs = waterLogs.where((w) => w.id != waterId).toList();
      },
    );
  }

  /// Adds a water entry to [selectedDate]. The returned row is appended to
  /// [waterLogs].
  Future<bool> addWaterEntry(int amountMl) {
    return _runTrackerAction<WaterLogModel>(
      action: () => _trackerApi.addWater(selectedDate, amountMl),
      onSuccess: (saved) {
        waterLogs = [...waterLogs, saved];
      },
    );
  }

  /// Adds a new weight log. The returned [WeightLogModel] is converted to
  /// a [WeightHistoryEntry] (date re-formatted as `yyyy-MM-dd`, matching
  /// what `/tracker/weight/history` returns) and *prepended* — the
  /// history endpoint serves entries newest-first, so the new one belongs
  /// at the top.
  Future<bool> addWeightEntry(double weight, String? note) {
    return _runTrackerAction<WeightLogModel>(
      action: () => _trackerApi.addWeight(DateTime.now(), weight, note: note),
      onSuccess: (saved) {
        final entry = WeightHistoryEntry(
          id: saved.id,
          date: _formatYmd(saved.date),
          weight: saved.weight,
          note: saved.note,
        );
        weightHistory = [entry, ...weightHistory];
      },
    );
  }

  /// Appends a [FoodLogModel] that was *already* persisted server-side to
  /// [foodLogs] and notifies listeners. Used by
  /// [FoodRecognitionProvider] after a successful photo analysis — the
  /// backend has written the row before the response arrives, so the only
  /// remaining work is the local cache update.
  ///
  /// Skipped (silently) if a row with the same [FoodLogModel.id] is
  /// already present, so a duplicate notify from racey retry logic
  /// can't produce two entries in the UI list.
  void addLocalFoodEntry(FoodLogModel food) {
    if (foodLogs.any((f) => f.id == food.id)) return;
    foodLogs = [...foodLogs, food];
    notifyListeners();
  }

  /// Replaces an existing [FoodLogModel] in [foodLogs] (matched by
  /// [FoodLogModel.id]) with [updated] and notifies listeners. Used by
  /// [FoodRecognitionProvider] after a successful text reanalysis — the
  /// backend has UPDATed the same row in place (no duplicate id), so the
  /// local cache needs the matching entry replaced, not appended.
  ///
  /// Skipped (silently) when no entry with the same id is present in
  /// [foodLogs]. This is the right behaviour when, for example, the
  /// user is viewing *yesterday's* food list and re-analyzes an AI row
  /// from *today* — the day's list shouldn't suddenly grow an
  /// out-of-place row. The producer (the reanalysis flow) is
  /// authoritative about the user's intent; if a row genuinely
  /// belongs in [foodLogs] but is somehow missing, the next
  /// `loadDailyData(...)` will repopulate from the server.
  ///
  /// List-mutation note (REGRESSION GUARD): this method originally
  /// used `.toList(growable: false)`. That made [foodLogs] a
  /// fixed-length list, and the *next* call to
  /// [addLocalFoodEntry] — which DOES grow the list — crashed with
  /// "Unsupported operation: Cannot add to a fixed-length list".
  /// Every `foodLogs` / `waterLogs` reassignment in this file now
  /// uses the default `.toList()` (i.e. `growable: true`).
  /// Equivalently: treat every list field in this class as if
  /// passing `growable: false` is forbidden — any future code that
  /// does `foodLogs.add(...)` would otherwise become a latent
  /// crash that triggers only after this method runs first.
  void updateLocalFoodEntry(FoodLogModel updated) {
    final exists = foodLogs.any((f) => f.id == updated.id);
    if (!exists) return;
    foodLogs = foodLogs
        .map((f) => f.id == updated.id ? updated : f)
        .toList();
    notifyListeners();
  }

  /// Appends a [BeverageRecognitionResult] (auto-logged branch
  /// only) to BOTH [foodLogs] AND [waterLogs] in a single
  /// notification cycle.
  ///
  /// The backend's beverage endpoints dual-write a `FoodLog` row
  /// (calories / macros) and a `WaterLog` row (volume) in one
  /// transaction, so the local cache must reflect both inserts
  /// together — otherwise the day's water total would lag the
  /// food entry by one frame and the user would see a brief
  /// inconsistency.
  ///
  /// [aiGenerated] distinguishes the two call sites:
  ///   * `true` — the numbers came from Gemini's photo analysis
  ///     (the high-confidence auto-logged branch of
  ///     `/recognize-beverage`); the resulting row shows the
  ///     "Уточнить" edit affordance on the home screen.
  ///   * `false` — the numbers came from the user (the manual
  ///     confirm path); the resulting row is treated as
  ///     user-vetted and the "Уточнить" affordance is hidden.
  ///
  /// Skipped (silently) when [result.autoLogged] is `false` —
  /// there's nothing to add on the suggest-only branch. Skipped
  /// again if the resulting `food_log_id` is already present in
  /// [foodLogs] (de-dup semantics, identical to
  /// [addLocalFoodEntry]).
  void addBeverageEntry(
    BeverageRecognitionResult result, {
    required bool aiGenerated,
  }) {
    if (!result.autoLogged) return;
    if (result.nutrition == null) return;
    if (result.foodLogId == null) return;

    // De-dup on food_log_id (not just on the food entry): a
    // racey retry that re-invokes the same provider method twice
    // would otherwise produce two visible food rows AND two
    // duplicate water rows. Same pattern as addLocalFoodEntry.
    if (foodLogs.any((f) => f.id == result.foodLogId)) return;

    final nutrition = result.nutrition!;
    final loggedAt = result.loggedAt ?? DateTime.now();

    final foodLog = FoodLogModel(
      id: result.foodLogId!,
      userId: '',
      date: loggedAt,
      // Beverages get their own `mealType` bucket — `"drinks"` —
      // rather than being lumped into `"snack"` alongside cookies,
      // chips, etc. The previous convention (file-under-"snack")
      // made the daily summary awkward: a coffee at 3 PM and a
      // cookie at 3 PM both read as "snack" even though only one
      // is a beverage. Mirrors the backend's
      // `meal_type="drinks"` write in
      // `backend/app/api/v1/routes/food_recognition.py` —
      // keeping the two values identical means the locally-built
      // row and the server's eventual `loadDailyData(...)`
      // response render identically from the first frame (no
      // one-frame flash where the entry briefly lives under the
      // wrong section before a refetch corrects it). The
      // `meal_type` column is free-text on the `food_logs` table
      // (no DB-level enum constraint), so this rename is a pure
      // application-code sync — no migration required.
      mealType: 'drinks',
      foodName: nutrition.beverageName,
      calories: nutrition.calories,
      protein: nutrition.protein,
      carbs: nutrition.carbs,
      fat: nutrition.fat,
      // Beverages don't carry meaningful dietary fiber; the
      // server defaults to 0 and we mirror that here.
      fiber: 0,
      quantity: nutrition.volumeMl,
      unit: 'ml',
      photoUrl: null,
      aiGenerated: aiGenerated,
      createdAt: loggedAt,
    );
    final waterLog = WaterLogModel(
      id: result.waterLogId ?? '',
      userId: '',
      date: loggedAt,
      // The backend stores `amount` as an int (the schema is
      // `Integer`), so the volume gets rounded here too. The UI
      // also rounds partial-glass volumes down to the nearest
      // ml, matching the existing water quick-pick chip
      // behaviour.
      amount: nutrition.volumeMl.round(),
      createdAt: loggedAt,
    );

    // Build both new lists FIRST, then a single
    // notifyListeners(). Doing two separate notify calls would
    // cause a brief intermediate state where one list has the
    // new entry and the other doesn't, which the UI would
    // render as inconsistent for one frame. The same
    // REGRESSION GUARD reasoning as [updateLocalFoodEntry]
    // applies: plain `.toList()` everywhere (no `growable: false`).
    foodLogs = [...foodLogs, foodLog];
    waterLogs = [...waterLogs, waterLog];
    notifyListeners();
  }

  /// Clears [errorMessage] without otherwise touching state — useful for
  /// dismissing a banner after the user has read it.
  void clearError() {
    if (errorMessage != null) {
      errorMessage = null;
      notifyListeners();
    }
  }

  // ---- private helpers --------------------------------------------------------

  /// Shared body for [addFoodEntry] / [deleteFoodEntry] / [addWaterEntry] /
  /// [addWeightEntry].
  ///
  /// Mirrors the `_runAuthAction` helper in `auth_provider.dart`:
  ///   * Toggles [isLoading] / clears [errorMessage] once per call.
  ///   * Awaits [action] (which performs the network call and may throw an
  ///     [ApiException]).
  ///   * On success, defers to [onSuccess] to merge the result into local
  ///     state.
  ///   * On [ApiException], captures the message into [errorMessage].
  ///   * Always resets [isLoading] and notifies listeners exactly once at
  ///     the end.
  Future<bool> _runTrackerAction<T>({
    required Future<T> Function() action,
    required void Function(T result) onSuccess,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await action();
      onSuccess(result);
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (_) {
      // Defensive: any non-ApiException that escapes the tracker API
      // shouldn't crash the UI.
      errorMessage =
          'Что-то пошло не так. Проверь соединение и попробуй снова.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Strips the time-of-day component from [d], returning local midnight.
  /// All tracker queries are day-keyed, so a hair-thin time difference
  /// (e.g. 23:59:59.999) must not bump an entry onto the next day.
  static DateTime _midnightOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Formats a [DateTime] as `yyyy-MM-dd` in local time, matching the
  /// shape `/tracker/weight/history` already returns. Local helper — no
  /// `package:intl` dependency required.
  static String _formatYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

import 'package:flutter/foundation.dart';

import '../../auth/providers/auth_api.dart';
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
  Future<bool> deleteFoodEntry(String foodId) {
    return _runTrackerAction<void>(
      action: () => _trackerApi.deleteFood(foodId),
      onSuccess: (_) {
        foodLogs = foodLogs.where((f) => f.id != foodId).toList(growable: false);
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

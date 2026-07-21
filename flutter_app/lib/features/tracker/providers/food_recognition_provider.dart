import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../auth/providers/auth_api.dart';
import '../models/food_log_model.dart';
import '../models/food_recognition_result.dart';
import 'food_recognition_api.dart';
import 'tracker_provider.dart';

/// `ChangeNotifier` that owns the AI food-photo-recognition flow.
///
/// Single responsibility: hand a chosen photo off to [FoodRecognitionApi]
/// for Gemini-backed analysis, hold the most recent result / error so the
/// UI can render a confirmation state, and merge the resulting row into
/// the day's [TrackerProvider.foodLogs] (the backend persists server-side;
/// this provider owns the local cache invalidation).
///
/// Stateless across attempts — [reset] should be called when leaving the
/// photo flow so a stale result/error doesn't bleed into the next try.
class FoodRecognitionProvider extends ChangeNotifier {
  /// `true` while a Gemini round-trip is in flight.
  bool isAnalyzing = false;

  /// Most recent successful analysis, or `null` if none / cleared.
  FoodRecognitionResult? lastResult;

  /// Most recent user-presentable error, or `null` if none / cleared.
  String? errorMessage;

  /// Underlying transport. Single shared instance — clients of this
  /// provider don't need to inject one.
  final FoodRecognitionApi _api = FoodRecognitionApi();

  /// Sends [imageFile] to Gemini, surfaces success / failure to listeners,
  /// and (on success) prepends the freshly-written food row into the given
  /// [trackerProvider] so the UI list updates without a re-fetch.
  ///
  /// Returns `true` on success, `false` on failure ([errorMessage] is set
  /// in either case for UI display).
  Future<bool> analyzePhoto({
    required File imageFile,
    required String mealType,
    required TrackerProvider trackerProvider,
  }) async {
    isAnalyzing = true;
    errorMessage = null;
    lastResult = null;
    notifyListeners();

    try {
      final result = await _api.recognizeAndLog(
        imageFile: imageFile,
        mealType: mealType,
      );

      lastResult = result;

      // Build a local FoodLogModel from the recognition payload so the
      // day's food list reflects the new row without a /tracker/daily
      // round-trip. `userId` is left empty — not returned by this
      // endpoint and never displayed. `aiGenerated` is true to match the
      // PhotoLogModal's existing data shape on the web client.
      final local = FoodLogModel(
        id: result.foodLogId,
        userId: '',
        date: result.loggedAt,
        mealType: result.mealType,
        foodName: result.foodName,
        calories: result.calories,
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
        fiber: result.fiber,
        quantity: result.quantity,
        unit: result.unit,
        photoUrl: null,
        aiGenerated: true,
        createdAt: result.loggedAt,
      );
      trackerProvider.addLocalFoodEntry(local);

      isAnalyzing = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // The 422 message has already been humanised by
      // `FoodRecognitionApi`; we just forward it.
      errorMessage = e.message;
      isAnalyzing = false;
      notifyListeners();
      return false;
    } catch (_) {
      // Defensive: any non-ApiException (parse error, OOM, …) shouldn't
      // crash the UI — the user just sees a generic hint.
      errorMessage =
          'Не удалось обработать фото. Попробуй снова.';
      isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  /// Clears [lastResult] and [errorMessage] and notifies. Call when
  /// leaving the photo-recognition flow so a stale "✅ Logged!"
  /// confirmation from the previous attempt doesn't show up on the next
  /// entry to the screen.
  void reset() {
    final hadSomething = lastResult != null || errorMessage != null;
    lastResult = null;
    errorMessage = null;
    if (hadSomething) notifyListeners();
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../auth/providers/auth_api.dart';
import '../models/food_log_model.dart';
import '../models/food_recognition_result.dart';
import 'food_recognition_api.dart';
import 'tracker_provider.dart';

/// `ChangeNotifier` that owns the AI food-recognition flows —
/// both the initial photo analysis and the follow-up "edit the
/// description and re-analyze" path.
///
/// Single responsibility: hand inputs off to [FoodRecognitionApi]
/// for Gemini-backed analysis, hold the most recent result / error
/// so the UI can render a confirmation state, and merge the
/// resulting row into the day's [TrackerProvider.foodLogs]
/// (the backend persists server-side; this provider owns the local
/// cache invalidation).
///
/// Stateless across attempts — [reset] should be called when leaving
/// either flow (photo or edit) so a stale result/error doesn't bleed
/// into the next try.
class FoodRecognitionProvider extends ChangeNotifier {
  /// `true` while a Gemini round-trip is in flight.
  bool isAnalyzing = false;

  /// Most recent successful analysis, or `null` if none / cleared.
  /// Same field is populated by both [analyzePhoto] and
  /// [reanalyzeDescription] — the two flows produce byte-identical
  /// result shapes (per the backend's contract) so the UI can render
  /// them with the same widget regardless of origin.
  FoodRecognitionResult? lastResult;

  /// Most recent user-presentable error, or `null` if none / cleared.
  String? errorMessage;

  /// Per-row Gemini description cache.
  ///
  /// Populated every time an analysis (photo or reanalysis) succeeds:
  /// `descriptionsByFoodLogId[result.foodLogId] = result.description`.
  /// Read by the home screen's "Уточнить" handler so the edit form
  /// can pre-fill with the most recent description Gemini produced
  /// for that row — when the user opens the editor within the same
  /// app session, they continue editing from what they last saw
  /// rather than starting from scratch.
  ///
  /// Why a client-side cache and not a backend column: [FoodLogModel]
  /// does not carry the AI description, and adding a backend column
  /// would be an Alembic migration plus a model/schema change
  /// (explicitly out of scope per the spec). The cache lives in
  /// process memory and is lost when the app is killed — when that
  /// happens, the edit form falls back to an empty TextFormField
  /// and the user types their correction from scratch, which the
  /// spec calls "a perfectly reasonable UX fallback".
  final Map<String, String> descriptionsByFoodLogId = {};

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
      // Cache the description so a later "Уточнить" tap from the home
      // screen can pre-fill the edit form with the same text the user
      // last approved. See [descriptionsByFoodLogId] for the lifetime.
      descriptionsByFoodLogId[result.foodLogId] = result.description;

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

  /// Sends the user's [description] (free-text edit of the original
  /// description, NOT an image) to Gemini, surfaces success / failure
  /// to listeners, and (on success) calls
  /// `trackerProvider.updateLocalFoodEntry(...)` so the same row is
  /// replaced in-place in the day's food list — no duplicate id, no
  /// off-by-one row.
  ///
  /// Returns `true` on success, `false` on failure ([errorMessage] is
  /// set in either case for UI display). The flow mirrors
  /// [analyzePhoto] byte-for-byte except for the cache write (which
  /// would clobber the user's edit with the same value) being
  /// skipped deliberately — see below.
  Future<bool> reanalyzeDescription({
    required String foodId,
    required String description,
    required TrackerProvider trackerProvider,
  }) async {
    isAnalyzing = true;
    errorMessage = null;
    lastResult = null;
    notifyListeners();

    try {
      final result = await _api.reanalyzeDescription(
        foodId: foodId,
        description: description,
      );

      lastResult = result;
      // Deliberately DO NOT re-write `descriptionsByFoodLogId[foodId]`
      // from this result. After a successful reanalyze, the most
      // "fresh" description is the user's *own edited text* (which is
      // what they'd want to see in the field next time), not Gemini's
      // rewritten one — if we overwrote it, a subsequent "Уточнить"
      // pre-fill would show Gemini's prose rather than the user's.
      // The user's text lives in the edit screen's controller; it's
      // not persisted anywhere — if the cache becomes stale because
      // the user kept re-analysing, that's the deliberate trade-off.

      // Build a local FoodLogModel from the recognition payload. Same
      // shape as [analyzePhoto]; the backend has already UPDATEd the
      // same row server-side, so reusing the existing id (`result.foodLogId`
      // which == `foodId`) and `addLocalFoodEntry`'s de-dupe semantics
      // would be a no-op — `updateLocalFoodEntry` is the right
      // partner here because it expects the row to already be present
      // and replaces it in place.
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
      trackerProvider.updateLocalFoodEntry(local);

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
          'Не удалось обработать описание. Попробуй снова.';
      isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  /// Clears [lastResult] and [errorMessage] and notifies. Call when
  /// leaving either recognition flow (photo or edit) so a stale
  /// "✅ Logged!" confirmation from the previous attempt doesn't show
  /// up on the next entry to the screen.
  void reset() {
    final hadSomething = lastResult != null || errorMessage != null;
    lastResult = null;
    errorMessage = null;
    if (hadSomething) notifyListeners();
  }
}

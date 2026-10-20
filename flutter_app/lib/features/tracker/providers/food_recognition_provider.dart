import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/gen/app_localizations_lookup.dart';

import '../../auth/providers/auth_api.dart';
import '../models/food_log_model.dart';
import '../models/food_recognition_result.dart';
import '../models/meal_analysis_result.dart';
import 'food_recognition_api.dart';
import 'meal_photo_api.dart';
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
  /// `true` while a Gemini round-trip is in flight. Shared between the
  /// single-item photo flow ([analyzePhoto]) and the meal-photo flow
  /// ([analyzeMealPhoto]) — the UI only ever shows one spinner at a
  /// time, and the two flows are mutually exclusive entry points, so
  /// a single flag is enough.
  bool isAnalyzing = false;

  /// Most recent successful analysis, or `null` if none / cleared.
  /// Same field is populated by both [analyzePhoto] and
  /// [reanalyzeDescription] — the two flows produce byte-identical
  /// result shapes (per the backend's contract) so the UI can render
  /// them with the same widget regardless of origin.
  FoodRecognitionResult? lastResult;

  /// Most recent successful meal-photo (multi-item) analysis, or
  /// `null` if none / cleared. Distinct from [lastResult] because the
  /// shapes are intentionally different: this one is a list of items
  /// the user reviews and POSTs individually via
  /// `trackerProvider.addFoodEntry(...)`, not a single already-saved
  /// row. The single-item screen renders [lastResult]; the meal-photo
  /// screen renders [lastMealAnalysis].
  MealAnalysisResult? lastMealAnalysis;

  /// Most recent user-presentable error, or `null` if none / cleared.
  ///
  /// Setting [errorMessageKey] lets the consumer [localizeError] look
  /// up the active-locale copy via `AppLocalizations.of(context)` — see
  /// the resolver below.
  String? errorMessage;
  String? errorMessageKey;

  /// Translate the current error state to the active locale. Falls back
  /// through the key → legacy string → generic-error chain.
  static String localizeError(BuildContext context, FoodRecognitionProvider p) {
    final l10n = AppLocalizations.of(context);
    if (p.errorMessageKey != null) {
      final fromL10n = l10n.lookup(p.errorMessageKey!);
      if (fromL10n != null) return fromL10n;
    }
    return p.errorMessage ?? l10n.commonError;
  }

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

  /// Underlying transport for the meal-photo (multi-item) flow. Kept
  /// separate from [_api] so the two flows can evolve independently
  /// — the meal endpoint lives under a different router and returns a
  /// different shape, and conflating them would just complicate the
  /// shared client's call sites for no benefit.
  final MealPhotoApi _mealApi = MealPhotoApi();

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
      // crash the UI — the user just sees a generic hint. The
      // `errorMessageKey` lets the consumer [localizeError] render
      // the active locale's copy.
      errorMessage = null;
      errorMessageKey = 'userFacingErrorPhotoProcess';
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
      // crash the UI — the user just sees a generic hint. The
      // `errorMessageKey` lets the consumer [localizeError] render
      // the active locale's copy.
      errorMessage = null;
      errorMessageKey = 'userFacingErrorDescriptionProcess';
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

  /// Sends [imageFile] to the meal-photo endpoint, surfaces success
  /// / failure to listeners, and (on success) stores the multi-item
  /// estimate in [lastMealAnalysis]. Unlike [analyzePhoto], the
  /// backend does NOT persist anything server-side — the user reviews
  /// the items on the (future) screen, edits portions, and then the
  /// screen calls `trackerProvider.addFoodEntry(model)` per accepted
  /// item to persist them one-by-one. The provider therefore does
  /// NOT touch [trackerProvider] itself.
  ///
  /// Returns `true` on success, `false` on failure ([errorMessage] /
  /// [errorMessageKey] are set in either case for UI display). The
  /// shared [isAnalyzing] flag is driven by this flow; the future
  /// screen treats it as "the spinner is up".
  Future<bool> analyzeMealPhoto({
    required File imageFile,
    required String mealType,
    required TrackerProvider trackerProvider,
  }) async {
    isAnalyzing = true;
    errorMessage = null;
    errorMessageKey = null;
    lastMealAnalysis = null;
    notifyListeners();

    try {
      final result = await _mealApi.analyzeMealPhoto(
        imageFile: imageFile,
        mealType: mealType,
      );

      // Single-item screen reads [lastResult]; meal-photo screen reads
      // [lastMealAnalysis]. Clearing [lastResult] here is defensive —
      // if a stale single-item result was somehow still in memory
      // (the two flows should be mutually exclusive in practice, but
      // the screens could re-render out of order), the meal screen
      // should never see a mixed state.
      lastResult = null;
      lastMealAnalysis = result;

      // Empty-but-no_food_detected false is still a success — we
      // hand the (possibly empty) result back to the UI so it can
      // render the appropriate empty-state. The screen decides
      // whether to show the "no food detected" copy or the
      // "nothing to save" copy.

      // Deliberately do NOT call trackerProvider.addLocalFoodEntry /
      // addBeverageEntry here: the meal-photo endpoint is no-save
      // by design, and pre-loading the per-item POSTs into the day's
      // list before the user has reviewed them would put half-baked
      // rows into the visible list. The future screen holds the
      // reference for the eventual per-item `addFoodEntry` calls.
      // The unused parameter triggers no lint — [trackerProvider]
      // is in scope by virtue of being part of the public API.

      isAnalyzing = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // The per-status messages have already been humanised by
      // [MealPhotoApi]; we forward them verbatim and let the matching
      // `messageKey` drive the active-locale copy.
      errorMessage = e.message;
      errorMessageKey = e.messageKey;
      isAnalyzing = false;
      notifyListeners();
      return false;
    } catch (_) {
      // Defensive: any non-ApiException (parse error, OOM, …) shouldn't
      // crash the UI — the user just sees a generic hint. The
      // `errorMessageKey` lets the consumer [localizeError] render
      // the active locale's copy.
      errorMessage = null;
      errorMessageKey = 'userFacingErrorPhotoProcess';
      isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  /// Clears [lastMealAnalysis] (and [errorMessage], in case a prior
  /// meal-photo attempt failed) and notifies. Call when leaving the
  /// meal-photo flow so a stale "items ready" state from a previous
  /// attempt doesn't show up on the next entry to the screen.
  void resetMealAnalysis() {
    final hadSomething = lastMealAnalysis != null || errorMessage != null;
    lastMealAnalysis = null;
    errorMessage = null;
    errorMessageKey = null;
    if (hadSomething) notifyListeners();
  }
}

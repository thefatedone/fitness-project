import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/gen/app_localizations_lookup.dart';

import '../../auth/providers/auth_api.dart';
import '../models/beverage_result.dart';
import 'beverage_api.dart';
import 'tracker_provider.dart';

/// `ChangeNotifier` that owns the AI beverage-recognition flows —
/// the initial photo analysis (auto-logged or suggest-only) and
/// the follow-up "edit the values and confirm" path.
///
/// Single responsibility: hand inputs off to [BeverageApi] for
/// Gemini-backed analysis (or user-confirmed values, in the
/// manual path), hold the most recent result / error so the UI
/// can render the appropriate confirmation state, and merge the
/// resulting dual-write into the day's [TrackerProvider.foodLogs]
/// AND [TrackerProvider.waterLogs] (the backend persists both
/// server-side; this provider owns the local cache invalidation).
///
/// Stateless across attempts — [reset] should be called when
/// leaving the beverage flow so a stale result/error doesn't
/// bleed into the next try.
class BeverageProvider extends ChangeNotifier {
  /// `true` while a Gemini round-trip is in flight.
  bool isAnalyzing = false;

  /// Most recent successful analysis, or `null` if none / cleared.
  /// Carries the server-side `autoLogged` flag — the UI branches
  /// on `lastResult!.autoLogged` to decide whether to render the
  /// auto-logged result card or the manual-confirm form.
  BeverageRecognitionResult? lastResult;

  /// Most recent user-presentable error, or `null` if none / cleared.
  ///
  /// Setting [errorMessageKey] lets the consumer [localizeError] look
  /// up the active-locale copy via `AppLocalizations.of(context)`.
  String? errorMessage;
  String? errorMessageKey;

  /// Translate the current error state to the active locale. Falls back
  /// through the key → legacy string → generic-error chain.
  static String localizeError(BuildContext context, BeverageProvider p) {
    final l10n = AppLocalizations.of(context);
    if (p.errorMessageKey != null) {
      final fromL10n = l10n.lookup(p.errorMessageKey!);
      if (fromL10n != null) return fromL10n;
    }
    return p.errorMessage ?? l10n.commonError;
  }

  /// Underlying transport. Single shared instance — clients of
  /// this provider don't need to inject one.
  final BeverageApi _api = BeverageApi();

  /// Sends [imageFile] to Gemini, surfaces success / failure to
  /// listeners, and (on success) merges the dual-written row into
  /// the given [trackerProvider] so the day's food AND water lists
  /// update without a re-fetch.
  ///
  /// Returns `true` on success, `false` on failure ([errorMessage]
  /// is set in either case for UI display). The UI does NOT
  /// branch on this return — it branches on
  /// `lastResult!.autoLogged` to render either the auto-logged
  /// result card or the manual-confirm form. The return value is
  /// kept for symmetry with the other providers and to allow
  /// callers to short-circuit on network-level failures.
  Future<bool> analyzePhoto({
    required File imageFile,
    required TrackerProvider trackerProvider,
  }) async {
    isAnalyzing = true;
    errorMessage = null;
    lastResult = null;
    notifyListeners();

    try {
      final result = await _api.recognizeBeverage(imageFile);
      lastResult = result;

      // The dual-write only happened server-side on the
      // auto-logged branch; on the suggest-only branch there's
      // nothing to merge yet (the user has to confirm first via
      // `confirmManual`).
      if (result.autoLogged) {
        trackerProvider.addBeverageEntry(result, aiGenerated: true);
      }

      isAnalyzing = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // The 422 message has already been humanised by
      // `BeverageApi`; we just forward it.
      errorMessage = e.message;
      isAnalyzing = false;
      notifyListeners();
      return false;
    } catch (_) {
      // Defensive: any non-ApiException (parse error, OOM, …)
      // shouldn't crash the UI — the user just sees a generic
      // hint. The `errorMessageKey` lets the consumer [localizeError]
      // render the active locale's copy.
      errorMessage = null;
      errorMessageKey = 'userFacingErrorPhotoProcess';
      isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  /// Sends the user's confirmed (possibly edited) values back to
  /// the server, surfaces success / failure to listeners, and on
  /// success merges the dual-written row into the given
  /// [trackerProvider] — same as `analyzePhoto`'s auto-logged
  /// branch, but `aiGenerated: false` to reflect that the values
  /// are user-vetted (which gates the home screen's "Уточнить"
  /// affordance off for this row).
  ///
  /// All macro parameters default to `0` (matching the backend's
  /// `>= 0` constraint), so a "zero-calorie" entry like plain
  /// water can be confirmed with just name / volume / calories.
  Future<bool> confirmManual({
    required String beverageName,
    required double volumeMl,
    required double calories,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    double sugarG = 0,
    required TrackerProvider trackerProvider,
  }) async {
    isAnalyzing = true;
    errorMessage = null;
    lastResult = null;
    notifyListeners();

    try {
      final result = await _api.logManual(
        beverageName: beverageName,
        volumeMl: volumeMl,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        sugarG: sugarG,
      );
      lastResult = result;
      trackerProvider.addBeverageEntry(result, aiGenerated: false);

      isAnalyzing = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      isAnalyzing = false;
      notifyListeners();
      return false;
    } catch (_) {
      // Defensive: any non-ApiException (parse error, OOM, …)
      // shouldn't crash the UI. The `errorMessageKey` lets the
      // consumer [localizeError] render the active locale's copy.
      errorMessage = null;
      errorMessageKey = 'photoBeverageSaveError';
      isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  /// Clears [lastResult] and [errorMessage] and notifies. Call
  /// when leaving the beverage-recognition flow so a stale "✅
  /// Logged" confirmation from the previous attempt doesn't
  /// bleed into the next entry to the screen.
  void reset() {
    final hadSomething = lastResult != null || errorMessage != null;
    lastResult = null;
    errorMessage = null;
    if (hadSomething) notifyListeners();
  }
}

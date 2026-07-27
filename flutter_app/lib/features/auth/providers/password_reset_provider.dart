import 'package:flutter/foundation.dart';

import 'auth_api.dart';
import 'password_reset_api.dart';

/// `ChangeNotifier` for the three-step password-reset flow
/// (request-code → verify-code → commit-reset).
///
/// Single responsibility: hold the cross-step state (the email the
/// user typed in step 1, the 6-digit code they typed in step 2) and
/// the loading/error flags the UI needs; the actual HTTP work is in
/// [PasswordResetApi].
///
/// Step-to-step data flow: each step writes the *just-collected* field
/// into this provider (via the `email` / `code` fields) so subsequent
/// steps don't have to re-prompt for it. The pattern is the same one
/// the onboarding wizard uses for [OnboardingData] — a single shared
/// state holder threaded through the flow.
class PasswordResetProvider extends ChangeNotifier {
  /// Email the user entered in step 1. Used by step 2 and step 3 so
  /// they don't have to re-prompt for it.
  String email = '';

  /// 6-digit code the user entered in step 2. Used by step 3
  /// (`resetPassword`) so the API call can hand the same code the
  /// user already verified.
  String code = '';

  /// `true` while any of the three HTTP calls is in flight. UI uses
  /// this to disable the next-step button and show a spinner.
  bool isLoading = false;

  /// Last user-facing error message (Russian, populated by the API
  /// layer's `ApiException.message` extraction). Cleared at the start
  /// of every action.
  String? errorMessage;

  /// Underlying HTTP client. Single shared instance — feature
  /// clients don't inject / fake it.
  final PasswordResetApi _api = PasswordResetApi();

  // ---- step 1: request a code -------------------------------------------

  /// Step 1. Asks the backend to email a 6-digit code. Stores the
  /// email so step 2 and 3 can re-use it without re-prompting.
  /// Returns `true` on success (regardless of whether the email
  /// actually mapped to a user — the backend is generic on this
  /// path by design), `false` on a transport-level error.
  Future<bool> requestCode(String emailInput) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.requestCode(emailInput);
      email = emailInput;
      isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---- step 2: verify the code -----------------------------------------

  /// Step 2. Tells the backend "is this code currently redeemable?"
  /// without burning it. The backend returns 200 with `{valid: true}`
  /// for a usable code and 400 (with the generic bad-code copy) for
  /// any failure mode. Either way, we use the just-typed code as the
  /// `code` field for step 3 only after a successful verify.
  Future<bool> verifyCode(String codeInput) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.verifyCode(email: email, code: codeInput);
      code = codeInput;
      isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---- step 3: commit the new password ----------------------------------

  /// Step 3. Hands the email + code (both stored from steps 1 and 2)
  /// plus the user-typed `newPassword` to the backend, which re-verifies
  /// the code server-side and either swaps the password hash + burns
  /// the code, or surfaces a 400 with a Russian detail (either the
  /// generic "Неверный или истёкший код." or a password-strength
  /// error). Caller surfaces the message verbatim in a SnackBar.
  ///
  /// Note: the provider does NOT clear `email` / `code` on success —
  /// the caller (the screen) drives the navigation away to LoginScreen
  /// and is responsible for calling [reset] on its way out. Doing the
  /// reset here would race the screen's dispose order.
  Future<bool> resetPassword(String newPassword) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---- housekeeping -----------------------------------------------------

  /// Wipe email / code / errorMessage back to fresh. Call this on
  /// navigation *out* of the flow (success, cancel, or "user gave
  /// up and is going to the login screen anyway") so a subsequent
  /// re-entry into the reset flow doesn't carry over stale state from
  /// a previous attempt. Mirrors the auto-dispose hygiene of other
  /// feature providers (e.g. [OnboardingData] re-creation on each
  /// wizard push).
  void reset() {
    email = '';
    code = '';
    errorMessage = null;
    notifyListeners();
  }

  /// Clears the SnackBar copy without otherwise touching state. The
  /// UI typically calls this after showing a snackbar so the same
  /// error doesn't re-show on the next rebuild.
  void clearError() {
    if (errorMessage != null) {
      errorMessage = null;
      notifyListeners();
    }
  }
}

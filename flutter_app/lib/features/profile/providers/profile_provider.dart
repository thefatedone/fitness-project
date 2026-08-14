import 'package:flutter/foundation.dart';

import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_api.dart';
import '../../auth/providers/auth_provider.dart';
import 'profile_api.dart';

// ============================================================================
// Profile-screen option lists
// ============================================================================
//
// These top-level constants are consumed by the profile screen's
// dropdowns / chip rows. The `value`s are the *English, enum-like*
// strings the backend stores verbatim on the user row — the web client
// already writes exactly these strings to the database, so the mobile
// app reuses them to keep the data shape portable across clients.
// All user-visible labels are Russian.
//
// Keep these in lockstep with the `profile/page.tsx` value arrays on
// the web side so a user who edited their preferences on web and then
// logs in on mobile sees the same options.

/// Tag values the backend stores for dietary preferences.
const List<String> dietaryOptions = [
  'Vegetarian',
  'Vegan',
  'Keto',
  'Paleo',
  'Low-Carb',
  'Low-Fat',
  'Mediterranean',
  'Dash',
  'Halal',
  'Kosher',
];

/// English fallback translations of [dietaryOptions] for the UI.
/// When the active locale is Russian (or Georgian in a future
/// revision), the UI layer looks up the localised string from
/// `AppLocalizations`; this map is only the default when no
/// translation is found (defensive — should never trigger under
/// normal flow).
const Map<String, String> dietaryLabelsEn = {
  'Vegetarian': 'Vegetarian',
  'Vegan': 'Vegan',
  'Keto': 'Keto',
  'Paleo': 'Paleo',
  'Low-Carb': 'Low-carb',
  'Low-Fat': 'Low-fat',
  'Mediterranean': 'Mediterranean',
  'Dash': 'DASH',
  'Halal': 'Halal',
  'Kosher': 'Kosher',
};

/// Tag values the backend stores for food allergies.
const List<String> allergyOptions = [
  'Nuts',
  'Shellfish',
  'Eggs',
  'Soy',
  'Wheat',
  'Fish',
  'Milk',
];

/// English fallback translations of [allergyOptions] for the UI.
/// See [dietaryLabelsEn] for the same fallback contract.
const Map<String, String> allergyLabelsEn = {
  'Nuts': 'Nuts',
  'Shellfish': 'Shellfish',
  'Eggs': 'Eggs',
  'Soy': 'Soy',
  'Wheat': 'Wheat',
  'Fish': 'Fish',
  'Milk': 'Milk',
};

/// Activity-level options. Each entry is `{value, label}` so the
/// dropdown can store the enum-like backend value but display the
/// localised label. The labels here are English fallbacks — the
/// profile screen applies localisation at render time.
const List<Map<String, String>> activityLevels = [
  {'value': 'sedentary', 'label': 'Sedentary'},
  {'value': 'lightly_active', 'label': 'Lightly active'},
  {'value': 'moderately_active', 'label': 'Moderately active'},
  {'value': 'very_active', 'label': 'Very active'},
  {'value': 'extra_active', 'label': 'Extra active'},
];

/// Primary-goal options — value/label/emoji, mirroring the web client.
/// English fallback labels — localised at render time by the UI.
const List<Map<String, String>> primaryGoals = [
  {'value': 'lose_weight', 'label': 'Lose weight', 'emoji': '🔥'},
  {'value': 'maintain', 'label': 'Maintain weight', 'emoji': '⚖️'},
  {'value': 'gain_muscle', 'label': 'Gain muscle', 'emoji': '💪'},
  {'value': 'eat_healthier', 'label': 'Eat healthier', 'emoji': '🥗'},
];

// ============================================================================
// Provider
// ============================================================================

/// `ChangeNotifier` for the profile-edit / profile-photo-upload flow.
///
/// Single responsibility: wrap the two [ProfileApi] calls (`updateProfile`
/// and `uploadPhoto`) in a UI-friendly loading/error lifecycle, and
/// *push* the resulting [UserModel] into [AuthProvider] so every other
/// screen (tracker summary, weight chart, meal targets, …) sees the
/// fresh data on the next frame.
///
/// We deliberately do NOT hold a reference to the [AuthProvider] as a
/// field. Two `ChangeNotifier`s observing each other would create a
/// fragile, hard-to-test coupling — and the only consumer-facing need
/// here is a *write*, not a read. The UI layer calls
/// `authProvider.updateCurrentUser(...)` directly, passing in the
/// `AuthProvider` it already has via `context.read`.
class ProfileProvider extends ChangeNotifier {
  /// `true` while a `PUT /users/me` is in flight.
  bool isSaving = false;

  /// `true` while a `POST /users/me/photo` is in flight.
  bool isUploadingPhoto = false;

  /// Last user-facing error message, or `null` if the most recent
  /// action succeeded. Cleared at the start of every action.
  String? errorMessage;

  final ProfileApi _profileApi = ProfileApi();

  // ---- public actions --------------------------------------------------------

  /// Persists a partial update of the user's profile fields.
  ///
  /// [fields] is forwarded to `PUT /users/me` verbatim — the caller is
  /// responsible for sending *only* the keys that actually changed
  /// (PATCH-like semantics over a PUT verb). On success, the freshly
  /// returned [UserModel] is patched into [AuthProvider] so dependent
  /// screens reflect the new targets immediately.
  ///
  /// Returns `true` on success, `false` otherwise (with [errorMessage]
  /// populated).
  Future<bool> saveProfile({
    required AuthProvider authProvider,
    required Map<String, dynamic> fields,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final updated = await _profileApi.updateProfile(fields);
      // Push the fresh user into the shared auth state. The next
      // context.watch<AuthProvider>() rebuild (e.g. on the tracker
      // home) picks up the new name / targets / photo automatically.
      authProvider.updateCurrentUser(updated);
      isSaving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Uploads a base64-encoded profile photo and refreshes the
  /// cached [AuthProvider.currentUser] so the new URL renders
  /// everywhere immediately.
  ///
  /// The backend's `POST /users/me/photo` already commits the
  /// `profile_photo` column on the user row — we deliberately skip a
  /// second `PUT /users/me`. The local [UserModel] still has the old
  /// (likely `null`) photo URL though, so we patch that one field via
  /// [UserModel.copyWith] and push the result through
  /// [AuthProvider.updateCurrentUser].
  ///
  /// Returns `false` defensively if [authProvider] has no
  /// `currentUser` yet (this method is only reachable when
  /// authenticated, so this is "shouldn't happen" — but a `null`
  /// here would crash on the `!` bang, so we guard).
  Future<bool> uploadAndSavePhoto({
    required AuthProvider authProvider,
    required String base64Image,
  }) async {
    isUploadingPhoto = true;
    errorMessage = null;
    notifyListeners();

    try {
      final photoUrl = await _profileApi.uploadPhoto(base64Image);

      final current = authProvider.currentUser;
      if (current == null) {
        isUploadingPhoto = false;
        notifyListeners();
        return false;
      }

      authProvider.updateCurrentUser(
        current.copyWith(profilePhoto: photoUrl),
      );
      isUploadingPhoto = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      isUploadingPhoto = false;
      notifyListeners();
      return false;
    }
  }

  /// Clears [errorMessage] — useful for dismissing a banner after the
  /// user has read it. Notifies only if the value actually changed.
  void clearError() {
    if (errorMessage != null) {
      errorMessage = null;
      notifyListeners();
    }
  }
}

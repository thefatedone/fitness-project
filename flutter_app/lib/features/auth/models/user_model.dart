/// Immutable representation of a NutriMind user as returned by
/// `GET /api/v1/users/me`.
///
/// Single responsibility: parse the snake-case JSON payload the backend hands
/// us into a strongly-typed Dart value that the rest of the app can consume
/// without worrying about null-safety footguns or string-to-number coercion.
///
/// All optional fields from the API contract are nullable here. Parsing is
/// defensive: a missing or `null` value in the response yields `null` on the
/// Dart side rather than a crash — the server is allowed to leave fields
/// empty until the user fills in their profile (e.g. `bmr` stays `null`
/// until height and weight are known).
class UserModel {
  /// Server-assigned UUID (the `sub` claim in the JWT).
  final String id;

  /// Email address. `null` if the user signed up with a phone number only.
  final String? email;

  /// Phone number (E.164 or whatever the user typed). `null` for email-only
  /// signups.
  final String? phone;

  /// User-supplied display name. Always present.
  final String fullName;

  /// Server-assigned role string (e.g. `"USER"`, `"ADMIN"`).
  final String role;

  /// ISO 8601 date-of-birth, or `null` if not provided.
  final DateTime? dateOfBirth;

  /// Self-reported sex, free-form string (`"male"`, `"female"`, …). `null`
  /// when not set.
  final String? sex;

  /// Height in centimetres.
  final double? height;

  /// Most recently logged weight in kilograms.
  final double? currentWeight;

  /// Goal weight in kilograms.
  final double? targetWeight;

  /// Activity level bucket (e.g. `"sedentary"`, `"moderately_active"`).
  final String? activityLevel;

  /// Primary fitness goal (`"lose_weight"`, `"gain_muscle"`, `"maintain"`,
  /// `"eat_healthier"`).
  final String? primaryGoal;

  /// Comma-separated list of dietary preferences as stored on the server.
  /// `null` if none.
  final String? dietaryPreferences;

  /// Comma-separated list of allergens. `null` if none.
  final String? foodAllergies;

  /// Desired weekly weight-loss pace in kg/week. `null` when not set.
  final double? weightLossPace;

  /// Mifflin-St Jeor BMR (kcal/day). Server-computed; `null` until the user
  /// has supplied height + weight.
  final double? bmr;

  /// Total Daily Energy Expenditure (kcal/day). `null` until BMR exists.
  final double? tdee;

  /// Personal daily calorie target. Stored as an integer on the backend.
  final int? dailyCalTarget;

  /// Personal daily protein target in grams.
  final double? proteinTarget;

  /// Personal daily carbohydrate target in grams.
  final double? carbsTarget;

  /// Personal daily fat target in grams.
  final double? fatTarget;

  /// `false` if the admin has suspended the account.
  final bool isActive;

  /// Account creation timestamp (ISO 8601). Always present.
  final DateTime createdAt;

  /// URL of the uploaded profile photo on the backend, or `null`.
  final String? profilePhoto;

  /// `true` once the user has verified ownership of their email via
  /// the 6-digit-code flow. The backend's column is `nullable=False`
  /// with a `default=False` server default, so this is never `null`
  /// from a `from_attributes` read; we type it as plain `bool` rather
  /// than `Optional<bool>`. The mobile app's "verify your email"
  /// banner reads this flag to know whether to render.
  ///
  /// Verification is a *soft reminder* — the user can use the entire
  /// app with this still false. The flag just drives the in-app
  /// banner so the user notices and can verify on their own schedule.
  final bool isEmailVerified;

  /// Sign-in methods on file for this account. `null` (or empty)
  /// means the backend doesn't include the field — older server
  /// builds, or a cached response from before the field landed.
  /// The profile screen treats both as "no methods to show" and
  /// hides the section rather than showing an empty card.
  ///
  /// Items are returned in the backend's fixed display order
  /// (password → google → apple → phone → anything else, oldest-
  /// first within a provider), and each `displayIdentifier` is
  /// already masked server-side (`a***@gmail.com` for email,
  /// `+1******7890` for phone, ``null`` when nothing is on file).
  /// The list is read-only — there's no client-side action to
  /// link or unlink a method from this screen.
  ///
  /// Non-nullable: `fromJson` always returns at least an empty
  /// list (a missing / non-list JSON value, or a per-item parse
  /// failure, all collapse to `[]`). The constructor default is
  /// also `const <SignInMethod>[]` so callers that build a
  /// `UserModel` from scratch don't need to supply the field.
  final List<SignInMethod> signInMethods;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.isEmailVerified,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.sex,
    this.height,
    this.currentWeight,
    this.targetWeight,
    this.activityLevel,
    this.primaryGoal,
    this.dietaryPreferences,
    this.foodAllergies,
    this.weightLossPace,
    this.bmr,
    this.tdee,
    this.dailyCalTarget,
    this.proteinTarget,
    this.carbsTarget,
    this.fatTarget,
    this.profilePhoto,
    this.signInMethods = const <SignInMethod>[],
  });

  /// Builds a [UserModel] from the JSON payload returned by
  /// `GET /api/v1/users/me`.
  ///
  /// Every conversion is null-safe — an absent key, an explicit `null`, or a
  /// value of the wrong type all collapse to `null` on the Dart side rather
  /// than throwing, so a partial server response (e.g. an in-progress
  /// onboarding flow) won't crash the app.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String? ?? 'USER',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      // `is_email_verified` defaults to false on the server side too,
      // so an absent key on a partially-built row collapses to
      // false (which is correct — the user hasn't verified yet).
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth']),
      sex: json['sex'] as String?,
      height: _asDouble(json['height']),
      currentWeight: _asDouble(json['current_weight']),
      targetWeight: _asDouble(json['target_weight']),
      activityLevel: json['activity_level'] as String?,
      primaryGoal: json['primary_goal'] as String?,
      dietaryPreferences: json['dietary_preferences'] as String?,
      foodAllergies: json['food_allergies'] as String?,
      weightLossPace: _asDouble(json['weight_loss_pace']),
      bmr: _asDouble(json['bmr']),
      tdee: _asDouble(json['tdee']),
      dailyCalTarget: _asInt(json['daily_cal_target']),
      proteinTarget: _asDouble(json['protein_target']),
      carbsTarget: _asDouble(json['carbs_target']),
      fatTarget: _asDouble(json['fat_target']),
      profilePhoto: json['profile_photo'] as String?,
      // Defensive: older backends (or a cached response from before
      // the field landed) won't include `sign_in_methods`. Treat
      // missing / null / a non-list as "no methods" — the profile
      // screen hides the section rather than rendering an empty
      // card. Each entry is parsed in isolation so one malformed
      // row doesn't poison the whole list.
      signInMethods: _parseSignInMethods(json['sign_in_methods']),
    );
  }

  /// Returns a new [UserModel] with the same field values as this one,
  /// except where overridden by a non-`null` named argument.
  ///
  /// Intentionally minimal — only fields that the app needs to patch
  /// locally are exposed. As more screens need to write subsets of
  /// fields, add the relevant parameter to this method (and only
  /// those). Keeping it minimal today sidesteps the maintenance
  /// liability of a 25-parameter auto-generated copyWith.
  ///
  /// Each nullable parameter behaves the same way: `null` (the default)
  /// keeps the current value. There's currently no caller wanting to
  /// *clear* `profilePhoto` or `isEmailVerified` back to their empty
  /// state, so a single nullable-arg shape is enough for each.
  UserModel copyWith({String? profilePhoto, bool? isEmailVerified}) {
    return UserModel(
      id: id,
      email: email,
      phone: phone,
      fullName: fullName,
      role: role,
      dateOfBirth: dateOfBirth,
      sex: sex,
      height: height,
      currentWeight: currentWeight,
      targetWeight: targetWeight,
      activityLevel: activityLevel,
      primaryGoal: primaryGoal,
      dietaryPreferences: dietaryPreferences,
      foodAllergies: foodAllergies,
      weightLossPace: weightLossPace,
      bmr: bmr,
      tdee: tdee,
      dailyCalTarget: dailyCalTarget,
      proteinTarget: proteinTarget,
      carbsTarget: carbsTarget,
      fatTarget: fatTarget,
      isActive: isActive,
      createdAt: createdAt,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

  // -- private coercion helpers ------------------------------------------------

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Coerces JSON `number` (which may arrive as `int` or `double`) to
  /// `double?`. Returns `null` if the value is missing, `null`, or NaN.
  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Same coercion, but to `int?`. The backend uses `Integer` for
  /// `daily_cal_target` but we still accept a `double` if the server ever
  /// changes its mind.
  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Parses the `sign_in_methods` list defensively. Anything that
  /// isn't a list (null, an object, a string) yields an empty
  /// list — the profile screen treats that as "no methods to
  /// show". Each item is parsed independently; one malformed
  /// row doesn't poison the whole list (we drop it and keep the
  /// rest, so a server-side bug on one entry doesn't blank the
  /// whole UI for the user).
  static List<SignInMethod> _parseSignInMethods(dynamic raw) {
    if (raw is! List) return const <SignInMethod>[];
    final result = <SignInMethod>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = SignInMethod.fromJson(
        (item as Map).cast<String, dynamic>(),
      );
      if (m != null) result.add(m);
    }
    return result;
  }
}


/// One sign-in method on file for the current user. Mirrors the
/// backend's `SignInMethod` Pydantic model.
///
/// `provider` is the wire name from the IdP — known values today
/// are `password`, `google`, `apple`, `phone`; unknown values
/// (anything the server doesn't recognise — e.g. a future
/// `github`) pass through with the raw string so adding a new IdP
/// doesn't require a Dart rebuild. The profile screen renders
/// unknown providers with a generic icon and the raw name.
///
/// `displayIdentifier` is already masked server-side
/// (`a***@gmail.com` for email-based, `+1******7890` for phone, or
/// `null` when nothing useful is on file). NEVER mutate or un-mask
/// it client-side.
///
/// `linkedAt` is the moment the method was attached to the
/// account. Used by the profile screen to render a "Linked
/// 2025-01-15" subtitle.
class SignInMethod {
  final String provider;
  final String? displayIdentifier;
  final DateTime linkedAt;

  const SignInMethod({
    required this.provider,
    required this.linkedAt,
    this.displayIdentifier,
  });

  /// Parses a single `sign_in_methods` entry. Returns `null` on
  /// malformed input so the caller can drop just that entry
  /// without losing the whole list.
  static SignInMethod? fromJson(Map<String, dynamic> json) {
    final provider = json['provider'];
    final linkedAtRaw = json['linked_at'];
    if (provider is! String || linkedAtRaw is! String) return null;
    final linkedAt = DateTime.tryParse(linkedAtRaw);
    if (linkedAt == null) return null;
    return SignInMethod(
      provider: provider,
      linkedAt: linkedAt,
      displayIdentifier: json['display_identifier'] as String?,
    );
  }
}

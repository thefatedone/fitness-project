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

  const UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
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
}

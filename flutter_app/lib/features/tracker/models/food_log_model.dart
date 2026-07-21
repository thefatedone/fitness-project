/// Immutable representation of a single food entry as returned by the
/// NutriMind tracker endpoints.
///
/// Single responsibility: parse the snake_case JSON payloads
/// (`FoodLogResponse` from `GET /tracker/daily`, `POST /tracker/food`, etc.)
/// into a strongly-typed Dart value, and serialise back to the request shape
/// (`FoodLogCreate`) that `POST /tracker/food` expects.
///
/// Defensive by default: missing keys, explicit `null`s, or wrong-typed
/// values all collapse to `null` / safe defaults rather than throwing.
class FoodLogModel {
  /// Server-assigned UUID.
  final String id;

  /// Owning user's UUID.
  final String userId;

  /// Meal timestamp (ISO 8601 on the wire, DateTime in the model).
  final DateTime date;

  /// Slot within the day: `"breakfast"`, `"lunch"`, `"dinner"`, or `"snack"`.
  final String mealType;

  /// Free-text name of the food (e.g. `"Chicken breast"`).
  final String foodName;

  /// Total calories for [quantity] [unit].
  final double calories;

  /// Total protein in grams.
  final double protein;

  /// Total carbohydrates in grams.
  final double carbs;

  /// Total fat in grams.
  final double fat;

  /// Total fiber in grams; `null` when not tracked.
  final double? fiber;

  /// Numeric amount (e.g. `150`).
  final double quantity;

  /// Unit of [quantity] — `"g"`, `"ml"`, `"piece"`, etc.
  final String unit;

  /// URL of the optional uploaded photo; `null` if none.
  final String? photoUrl;

  /// `true` when this row was produced by the AI photo-recognition flow.
  final bool aiGenerated;

  /// Server-side creation timestamp.
  final DateTime createdAt;

  const FoodLogModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.mealType,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.quantity,
    required this.unit,
    required this.aiGenerated,
    required this.createdAt,
    this.fiber,
    this.photoUrl,
  });

  /// Builds a [FoodLogModel] from the `FoodLogResponse` JSON.
  factory FoodLogModel.fromJson(Map<String, dynamic> json) {
    return FoodLogModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      mealType: json['meal_type'] as String,
      foodName: json['food_name'] as String,
      calories: _asDouble(json['calories']),
      protein: _asDouble(json['protein']),
      carbs: _asDouble(json['carbs']),
      fat: _asDouble(json['fat']),
      fiber: json['fiber'] == null ? null : _asDouble(json['fiber']),
      quantity: _asDouble(json['quantity']),
      unit: json['unit'] as String,
      photoUrl: json['photo_url'] as String?,
      aiGenerated: json['ai_generated'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Serialises to the `FoodLogCreate` request body for `POST /tracker/food`.
  ///
  /// Server-managed fields (`id`, `user_id`, `ai_generated`, `created_at`)
  /// are intentionally omitted — the backend populates those itself.
  Map<String, dynamic> toCreateJson() {
    return {
      'date': date.toIso8601String(),
      'meal_type': mealType,
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      if (fiber != null) 'fiber': fiber,
      'quantity': quantity,
      'unit': unit,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }

  /// Coerces a JSON `number` (which the backend may serialise as `int` or
  /// `double`) to `double`. Returns `0` only when the field is genuinely
  /// missing — nutrient totals are required by the schema.
  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

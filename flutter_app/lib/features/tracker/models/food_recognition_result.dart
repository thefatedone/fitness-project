/// Result of `POST /api/v1/food/recognize-and-log`.
///
/// Single responsibility: parse the (nested) backend response into a flat,
/// UI-friendly value. Because the backend already writes the
/// `food_logs` row before returning, this class carries no "save" intent —
/// the [foodLogId] is a server-assigned reference the UI can show in a
/// confirmation toast.
class FoodRecognitionResult {
  /// Server-assigned UUID of the already-written `food_logs` row.
  final String foodLogId;

  /// Name Gemini extracted (e.g. `"Chicken Caesar salad"`).
  final String foodName;

  /// Total calories in the recognised serving.
  final double calories;

  /// Total protein in grams.
  final double protein;

  /// Total carbohydrates in grams.
  final double carbs;

  /// Total fat in grams.
  final double fat;

  /// Total fiber in grams. Backend always returns this (defaulted to 0
  /// when not visible in the image), so we don't model it as nullable.
  final double fiber;

  /// Recognised serving size (e.g. `1`).
  final double quantity;

  /// Serving unit (e.g. `"plate"`, `"bowl"`, `"g"`).
  final String unit;

  /// Gemini's own confidence label: `"high"`, `"medium"`, or `"low"`.
  final String confidence;

  /// Short prose description of what was detected.
  final String description;

  /// Server-side timestamp when the row was written (ISO 8601 on the wire).
  final DateTime loggedAt;

  /// Echoes the `meal_type` query parameter so the UI can confirm which
  /// meal slot the entry was filed under.
  final String mealType;

  /// List of ingredient names Gemini saw in the image. May be empty.
  final List<String> ingredients;

  /// User-allergy conflicts surfaced by the server. Empty when the user has
  /// no allergies or none of the detected ingredients triggered a rule.
  final List<String> allergyWarnings;

  /// `true` iff [allergyWarnings] is non-empty. Mirrors the server's
  /// `has_allergy_warning` flag so the UI doesn't have to derive it.
  final bool hasAllergyWarning;

  const FoodRecognitionResult({
    required this.foodLogId,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.quantity,
    required this.unit,
    required this.confidence,
    required this.description,
    required this.loggedAt,
    required this.mealType,
    required this.ingredients,
    required this.allergyWarnings,
    required this.hasAllergyWarning,
  });

  /// Builds a [FoodRecognitionResult] from the response body.
  ///
  /// The backend returns the nutritional payload under a nested
  /// `"nutrition"` object; we flatten that into top-level fields so the
  /// UI doesn't have to know about the wire shape. `allergy_warning` and
  /// `has_allergy_warning` are conditionally present (only when the user
  /// has allergies and a conflict was found) — both fall back to safe
  /// defaults.
  factory FoodRecognitionResult.fromJson(Map<String, dynamic> json) {
    final nutrition = (json['nutrition'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ingredientsJson = json['ingredients'] as List<dynamic>? ?? const <dynamic>[];

    return FoodRecognitionResult(
      foodLogId: (json['food_log_id'] as String?) ?? '',
      foodName: (nutrition['food_name'] as String?) ?? '',
      calories: _asDouble(nutrition['calories']),
      protein: _asDouble(nutrition['protein']),
      carbs: _asDouble(nutrition['carbs']),
      fat: _asDouble(nutrition['fat']),
      fiber: _asDouble(nutrition['fiber']),
      quantity: _asDouble(nutrition['quantity'], fallback: 1),
      unit: (nutrition['unit'] as String?) ?? 'serving',
      confidence: (nutrition['confidence'] as String?) ?? 'medium',
      description: (nutrition['description'] as String?) ?? '',
      loggedAt: DateTime.parse(json['logged_at'] as String),
      mealType: (json['meal_type'] as String?) ?? '',
      ingredients: ingredientsJson
          .map((e) => e.toString())
          .toList(growable: false),
      allergyWarnings: ((json['allergy_warning'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      hasAllergyWarning: json['has_allergy_warning'] as bool? ?? false,
    );
  }

  /// Coerces a JSON `number` (which may arrive as `int` or `double`, or
  /// `null` when the backend omitted it) to `double`. Falls back to 0 —
  /// this DTO is for *display*, not for re-sending, so defaulting to 0
  /// for missing values is safer than throwing.
  static double _asDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }
}

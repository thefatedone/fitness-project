/// Result models for `POST /api/v1/food/recognize-beverage` and
/// `POST /api/v1/food/log-beverage-manual`.
///
/// The two endpoints share a single response envelope with two
/// distinct *shapes*, gated on the server-side `auto_logged` flag:
/// when high-confidence, the server has already dual-written a
/// `FoodLog` + `WaterLog` pair and returns the row ids + the
/// committed nutrition; when medium/low, the server has NOT
/// written anything and returns only a *suggestion* payload the
/// client should pre-fill into a manual-confirmation form. Both
/// shapes parse into a single [BeverageRecognitionResult] so the
/// Flutter UI can branch on a single `autoLogged` flag.
library;

/// Nutritional payload for a single beverage — the seven fields
/// that the backend guarantees on both branches (the auto-logged
/// `nutrition` object and the medium/low-confidence `suggestion`
/// object).
///
/// `confidence` and `description` are optional because they only
/// appear on the `suggestion` payload (the auto-logged branch
/// carries them at the response envelope level instead). Storing
/// them here — rather than in a separate `BeverageSuggestion`
/// class — keeps the type simple and lets a single
/// [BeverageRecognitionResult.suggestion] field carry the full
/// suggestion in one place.
class BeverageNutrition {
  /// Display name for the beverage (e.g. "Coca-Cola", "Sparkling
  /// water"). Always non-empty on a successful parse; the server
  /// may return `""` only on a malformed Gemini response, in which
  /// case we fall back to the sentinel below.
  final String beverageName;

  /// Estimated volume in millilitres. Matches the `quantity` on
  /// the dual-written `FoodLog` row and the `amount` on the
  /// `WaterLog` row — the server uses the same value for both
  /// writes.
  final double volumeMl;

  /// Total calories for the estimated [volumeMl]. NOT per 100ml —
  /// the server's prompt is explicit about this and the UI should
  /// not divide.
  final double calories;

  /// Total protein in grams.
  final double protein;

  /// Total carbohydrates in grams.
  final double carbs;

  /// Total fat in grams.
  final double fat;

  /// Total sugar in grams. The beverage-specific field — the
  /// photo-recognition prompt asks for sugar separately because
  /// sugar is the primary nutritionally-relevant fact for drinks,
  /// and the daily summary UI surfaces it as its own chip.
  final double sugarG;

  /// `"high"` / `"medium"` / `"low"`. Only populated on the
  /// `suggestion` payload (the auto-logged `nutrition` doesn't
  /// carry it — the value lives at the envelope level on that
  /// branch).
  final String? confidence;

  /// Free-text description of the visual cues Gemini used to
  /// identify the beverage (e.g. "Fizzy amber liquid in a clear
  /// glass, no branding visible"). Only populated on the
  /// `suggestion` payload.
  final String? description;

  const BeverageNutrition({
    required this.beverageName,
    required this.volumeMl,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugarG,
    this.confidence,
    this.description,
  });

  /// Builds a [BeverageNutrition] from one of the JSON payloads
  /// the backend returns. Both the `nutrition` and `suggestion`
  /// keys share the same seven numeric fields, so this parser
  /// handles both.
  factory BeverageNutrition.fromJson(Map<String, dynamic> json) {
    return BeverageNutrition(
      beverageName: (json['beverage_name'] as String?) ?? '',
      volumeMl: _asDouble(json['volume_ml']),
      calories: _asDouble(json['calories']),
      protein: _asDouble(json['protein']),
      carbs: _asDouble(json['carbs']),
      fat: _asDouble(json['fat']),
      sugarG: _asDouble(json['sugar_g']),
      confidence: json['confidence'] as String?,
      description: json['description'] as String?,
    );
  }

  /// Coerces a JSON number (which may arrive as `int` or `double`,
  /// or `null` when the backend omitted it) to `double`. Falls
  /// back to `0` — this DTO is for *display*, not for re-sending,
  /// so defaulting to `0` for missing values is safer than
  /// throwing. Same pattern as [FoodRecognitionResult].
  static double _asDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }
}

/// Parsed response of either beverage endpoint. See
/// [BeverageRecognitionResult.fromJson] for the dispatch on
/// `auto_logged`.
class BeverageRecognitionResult {
  /// `true` if the server dual-wrote a `FoodLog` + `WaterLog`
  /// pair (high-confidence photo path or any manual log). `false`
  /// when the server returned only a suggestion for the user to
  /// confirm (medium/low-confidence photo path).
  final bool autoLogged;

  /// Server-assigned UUID of the dual-written `FoodLog` row.
  /// `null` when [autoLogged] is `false`.
  final String? foodLogId;

  /// Server-assigned UUID of the dual-written `WaterLog` row.
  /// `null` when [autoLogged] is `false`.
  final String? waterLogId;

  /// The committed nutrition payload on the auto-logged branch.
  /// `null` when [autoLogged] is `false`.
  final BeverageNutrition? nutrition;

  /// Top-level confidence on the auto-logged branch — always
  /// `"high"` there by the server's contract (low/medium never
  /// auto-logs). `null` on the suggest-only branch; for that
  /// branch the UI reads [suggestion]?.confidence.
  final String? confidence;

  /// ISO 8601 timestamp on the auto-logged branch — the
  /// server-side `date` of the dual-written row. `null` on the
  /// suggest-only branch.
  final DateTime? loggedAt;

  /// User-allergy conflicts surfaced by the server on the
  /// auto-logged branch. Empty on the suggest-only branch (the
  /// server doesn't run the allergen check on non-auto-logged
  /// responses).
  final List<String> allergyWarnings;

  /// `true` iff [allergyWarnings] is non-empty. Mirrors the
  /// server's `has_allergy_warning` flag so the UI doesn't have
  /// to derive it.
  final bool hasAllergyWarning;

  /// Pre-fill hint for the manual-confirmation form on the
  /// suggest-only branch. `null` on the auto-logged branch.
  final BeverageNutrition? suggestion;

  const BeverageRecognitionResult({
    required this.autoLogged,
    required this.foodLogId,
    required this.waterLogId,
    required this.nutrition,
    required this.confidence,
    required this.loggedAt,
    required this.allergyWarnings,
    required this.hasAllergyWarning,
    required this.suggestion,
  });

  /// Builds a [BeverageRecognitionResult] from either endpoint's
  /// JSON body. Dispatches on the server's `auto_logged` flag to
  /// decide which fields to populate.
  factory BeverageRecognitionResult.fromJson(Map<String, dynamic> json) {
    final autoLogged = json['auto_logged'] as bool? ?? false;

    if (autoLogged) {
      // Auto-logged branch: dual write happened server-side. The
      // server returns the committed `food_log_id`, `water_log_id`,
      // and `nutrition` block at the envelope level, plus the
      // `confidence` (always "high") and `logged_at`. The
      // allergy-warning fields are conditionally present — they
      // only show up when the user has an allergy AND the
      // beverage name triggered a rule.
      final nutritionJson = json['nutrition'] as Map?;
      return BeverageRecognitionResult(
        autoLogged: true,
        foodLogId: json['food_log_id'] as String?,
        waterLogId: json['water_log_id'] as String?,
        nutrition: nutritionJson == null
            ? null
            : BeverageNutrition.fromJson(
                nutritionJson.cast<String, dynamic>(),
              ),
        confidence: json['confidence'] as String?,
        loggedAt: _parseTimestamp(json['logged_at']),
        allergyWarnings: ((json['allergy_warning'] as List<dynamic>?) ??
                const <dynamic>[])
            .map((e) => e.toString())
            .toList(growable: false),
        hasAllergyWarning: json['has_allergy_warning'] as bool? ?? false,
        // No suggestion on the auto-logged branch.
        suggestion: null,
      );
    }

    // Suggest-only branch: no writes happened server-side. The
    // response is a flat `suggestion` payload with the seven
    // nutrition fields + a confidence ("medium"/"low") + a
    // description of the visual cues the model used. We surface
    // the suggestion's confidence at the envelope level too so
    // the UI has a single `result.confidence` to read for badge
    // styling — without this, the UI would have to know whether
    // to look at `result.confidence` or `result.suggestion?.confidence`
    // depending on the branch.
    final suggestionJson = json['suggestion'] as Map?;
    final suggestion = suggestionJson == null
        ? null
        : BeverageNutrition.fromJson(suggestionJson.cast<String, dynamic>());
    return BeverageRecognitionResult(
      autoLogged: false,
      foodLogId: null,
      waterLogId: null,
      nutrition: null,
      // Mirror onto the envelope-level field for UI convenience.
      confidence: suggestion?.confidence,
      loggedAt: null,
      allergyWarnings: const <String>[],
      hasAllergyWarning: false,
      suggestion: suggestion,
    );
  }

  /// Parses an ISO 8601 string the server may or may not have
  /// returned. Returns `null` on a missing field rather than
  /// throwing — the absence is meaningful on the suggest-only
  /// branch where there's no committed timestamp.
  static DateTime? _parseTimestamp(dynamic v) {
    if (v is! String) return null;
    try {
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }
}

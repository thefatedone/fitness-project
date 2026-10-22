/// Result of `POST /api/v1/tracker/food/analyze-photo`.
///
/// Single responsibility: parse the multi-item Anthropic-backed
/// plate-analyse response into a flat, UI-friendly value. Unlike
/// [FoodRecognitionResult], this DTO is *no-save* — the backend has not
/// written any `food_logs` rows yet, it has only suggested ingredients
/// with per-100g macros and a per-item `grams` portion estimate. The
/// user reviews the items, edits ingredients and portions, then sends the
/// complete dish to `/tracker/meals` in one atomic request.
class MealAnalysisResult {
  /// `true` when the model inspected the image and found no edible items.
  /// When `true`, [items] is empty and [totals] is all-zero. The UI uses
  /// this as the "no food" hint path rather than guessing from list
  /// length, because an empty list is also legal in some corner cases
  /// (model errored after plate detection but before item detection).
  final bool noFoodDetected;

  /// Optional bounding box around the detected plate, in *normalised*
  /// image coordinates (0..1 on both axes). `null` when the model
  /// didn't locate a plate (e.g. the `noFoodDetected` case, or a flat
  /// image with no clear circular dish). The future screen overlay uses
  /// this to draw a translucent rectangle on top of the captured photo.
  final PlateBox? plateBox;

  /// Suggested items (one row per detected ingredient / dish). May be
  /// empty even when [noFoodDetected] is `false` (e.g. plate detected
  /// but segmentation failed) — UI should treat empty as "nothing to
  /// save" and surface a fallback message.
  final List<AnalyzedItem> items;

  /// Sum of every [AnalyzedItem.totals]. The future screen renders
  /// these prominently above the item list so the user can see the
  /// overall estimate before tapping Save.
  final MacroTotals totals;

  const MealAnalysisResult({
    required this.noFoodDetected,
    required this.plateBox,
    required this.items,
    required this.totals,
  });

  /// Builds a [MealAnalysisResult] from the response body.
  ///
  /// Edge cases handled here (defensively, matching the existing
  /// `FoodRecognitionResult.fromJson` philosophy):
  ///   * `plate_box` may be absent (empty plate / no plate detected) →
  ///     [plateBox] is `null`.
  ///   * `items` may be `[]` → [items] is an empty list.
  ///   * numeric fields may arrive as `int` or `double` from the JSON
  ///     decoder; we coerce to `double` via `.toDouble()`.
  ///   * nested `per_100g` / `totals` objects default to all-zero
  ///     macros when absent.
  factory MealAnalysisResult.fromJson(Map<String, dynamic> json) {
    final plateBoxJson = json['plate_box'];
    final itemsJson = json['items'] as List<dynamic>? ?? const <dynamic>[];
    final totalsJson = (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {};

    return MealAnalysisResult(
      noFoodDetected: json['no_food_detected'] as bool? ?? false,
      plateBox: plateBoxJson == null
          ? null
          : PlateBox.fromJson((plateBoxJson as Map).cast<String, dynamic>()),
      items: itemsJson
          .cast<Map<String, dynamic>>()
          .map(AnalyzedItem.fromJson)
          .toList(growable: false),
      totals: MacroTotals.fromJson(totalsJson),
    );
  }
}

/// Normalised bounding box around the detected plate, expressed in
/// *image* coordinates (0..1 on both axes). Used by the future screen
/// to draw a translucent rectangle over the captured photo so the user
/// can see what region the model considered.
///
/// All four fields are required — a half-empty `plate_box` object on
/// the wire is treated as "no plate" by [MealAnalysisResult.fromJson],
/// which leaves the entire [PlateBox] `null`.
class PlateBox {
  /// Left edge, normalised (0..1).
  final double x;

  /// Top edge, normalised (0..1).
  final double y;

  /// Width, normalised (0..1).
  final double w;

  /// Height, normalised (0..1).
  final double h;

  const PlateBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory PlateBox.fromJson(Map<String, dynamic> json) {
    return PlateBox(
      x: _asDouble(json['x']),
      y: _asDouble(json['y']),
      w: _asDouble(json['w']),
      h: _asDouble(json['h']),
    );
  }
}

/// One detected item inside a meal — the row the user reviews,
/// optionally edits the grams of, and (on Save) sends to
/// `/tracker/food` as a standalone [FoodLogModel].
///
/// The `id` is a server-generated UUID kept verbatim so a future
/// per-item PATCH path has a stable handle. The data layer doesn't
/// use it; the screen does not need it either.
class AnalyzedItem {
  /// Server-generated UUID for this item.
  final String id;

  /// Free-text name of the item (e.g. `"Chicken breast"`).
  final String name;

  /// Estimated portion size in grams. The future screen lets the user
  /// override this; the override then feeds into
  /// [MacroMacros.scale] to recompute the per-item totals before save.
  final double grams;

  /// Centroid of the item in normalised image coordinates (0..1).
  /// The future screen uses this to drop a small dot on the photo at
  /// the same point the model keyed off of.
  final AnalyzedPoint point;

  /// Model's own confidence in the detection, 0..1. The future screen
  /// renders this as a percentage chip next to the item name; values
  /// below ~0.5 may be hidden or shown in a de-emphasised colour.
  final double confidence;

  /// Macros per 100 g of the item — the canonical "what is this food"
  /// payload that survives portion edits (the future screen multiplies
  /// by `grams / 100` to recompute [totals]).
  final MacroMacros per100g;

  /// Total macros for the estimated [grams] portion. Pre-computed
  /// server-side so the UI can show a sum without doing the math; the
  /// screen recomputes this locally after a portion edit.
  final MacroTotals totals;

  const AnalyzedItem({
    required this.id,
    required this.name,
    required this.grams,
    required this.point,
    required this.confidence,
    required this.per100g,
    required this.totals,
  });

  factory AnalyzedItem.fromJson(Map<String, dynamic> json) {
    final per100gJson = (json['per_100g'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totalsJson = (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pointJson = (json['point'] as Map?)?.cast<String, dynamic>() ?? const {};

    return AnalyzedItem(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      grams: _asDouble(json['grams']),
      point: AnalyzedPoint.fromJson(pointJson),
      confidence: _asDouble(json['confidence']),
      per100g: MacroMacros.fromJson(per100gJson),
      totals: MacroTotals.fromJson(totalsJson),
    );
  }
}

/// Centroid of a detected item in normalised image coordinates
/// (0..1 on both axes). See [AnalyzedItem.point].
class AnalyzedPoint {
  final double x;
  final double y;

  const AnalyzedPoint({required this.x, required this.y});

  factory AnalyzedPoint.fromJson(Map<String, dynamic> json) {
    return AnalyzedPoint(
      x: _asDouble(json['x']),
      y: _asDouble(json['y']),
    );
  }
}

/// Per-100g macro reference for a single food item. The future screen
/// keeps this intact through a portion edit and multiplies by
/// `grams / 100` to recompute the row's totals — the field is
/// deliberately separate from [MacroTotals] so the wire shape stays
/// one-to-one with the backend's response (no in-place mutation of a
/// portion payload).
class MacroMacros {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const MacroMacros({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory MacroMacros.fromJson(Map<String, dynamic> json) {
    return MacroMacros(
      kcal: _asDouble(json['kcal']),
      protein: _asDouble(json['protein']),
      carbs: _asDouble(json['carbs']),
      fat: _asDouble(json['fat']),
    );
  }
}

/// Macro totals for a portion of an item (kcal / protein / carbs /
/// fat in grams). Used both as the per-item `totals` payload on each
/// [AnalyzedItem] and as the roll-up [MealAnalysisResult.totals]
/// across every item.
///
/// The screen-mutation helper [scale] returns a fresh [MacroTotals]
/// with each macro scaled by [factor] (e.g. `factor = newGrams /
/// oldGrams` after a portion edit) — keeping the operation allocation-
/// friendly for the small (typically ≤ 10 item) records this DTO is
/// built for.
class MacroTotals {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const MacroTotals({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory MacroTotals.fromJson(Map<String, dynamic> json) {
    return MacroTotals(
      kcal: _asDouble(json['kcal']),
      protein: _asDouble(json['protein']),
      carbs: _asDouble(json['carbs']),
      fat: _asDouble(json['fat']),
    );
  }

  /// Returns a fresh [MacroTotals] with every macro scaled by
  /// [factor]. Used by the future screen to recompute the row's
  /// totals after a portion edit (`factor = newGrams / 100` against
  /// the item's [AnalyzedItem.per100g]).
  MacroTotals scale(double factor) {
    return MacroTotals(
      kcal: kcal * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
    );
  }
}

/// Coerces a JSON `number` (which may arrive as `int` or `double`, or
/// `null` when the backend omitted it) to `double`. Falls back to 0 —
/// this DTO is for *display*, not for re-sending, so defaulting to 0
/// for missing values is safer than throwing.
double _asDouble(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}
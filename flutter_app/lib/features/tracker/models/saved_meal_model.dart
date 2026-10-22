import 'dart:math';

import 'meal_analysis_result.dart';

/// A retained snapshot: repeating it never changes the original diary entry.
class SavedMealModel {
  final String id;
  final String name;
  final String mealType;
  final DateTime date;
  final List<MealIngredient> ingredients;

  const SavedMealModel({
    required this.id,
    required this.name,
    required this.mealType,
    required this.date,
    required this.ingredients,
  });

  factory SavedMealModel.fromJson(Map<String, dynamic> json) => SavedMealModel(
    id: json['id'] as String,
    name: json['name'] as String,
    mealType: json['meal_type'] as String,
    date: DateTime.parse(json['date'] as String),
    ingredients: (json['ingredients'] as List)
        .map(
          (v) => MealIngredient.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'meal_type': mealType,
    'date': date.toIso8601String(),
    'ingredients': ingredients.map((v) => v.toJson()).toList(),
  };

  MealAnalysisResult toAnalysis() => MealAnalysisResult(
    noFoodDetected: false,
    plateBox: null,
    items: [
      for (var i = 0; i < ingredients.length; i++)
        ingredients[i].toAnalyzed('$i'),
    ],
    totals: MacroTotals(
      kcal: ingredients.fold(0, (s, v) => s + v.calories),
      protein: ingredients.fold(0, (s, v) => s + v.protein),
      carbs: ingredients.fold(0, (s, v) => s + v.carbs),
      fat: ingredients.fold(0, (s, v) => s + v.fat),
    ),
  );
}

class MealIngredient {
  final String name;
  final double grams, calories, protein, carbs, fat;
  const MealIngredient({
    required this.name,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
  factory MealIngredient.fromJson(Map<String, dynamic> json) => MealIngredient(
    name: json['food_name'] as String,
    grams: (json['quantity'] as num).toDouble(),
    calories: (json['calories'] as num).toDouble(),
    protein: (json['protein'] as num).toDouble(),
    carbs: (json['carbs'] as num).toDouble(),
    fat: (json['fat'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'food_name': name,
    'quantity': grams,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
  AnalyzedItem toAnalyzed(String id) => AnalyzedItem(
    id: id,
    name: name,
    grams: grams,
    point: const AnalyzedPoint(x: .5, y: .5),
    confidence: 1,
    per100g: MacroMacros(
      kcal: calories * 100 / grams,
      protein: protein * 100 / grams,
      carbs: carbs * 100 / grams,
      fat: fat * 100 / grams,
    ),
    totals: MacroTotals(
      kcal: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    ),
  );
}

/// UUID v4 without an additional dependency. One ID per save operation.
String newMealId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

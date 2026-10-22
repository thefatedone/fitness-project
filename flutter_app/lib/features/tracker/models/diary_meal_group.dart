import 'food_log_model.dart';

/// One pass, stable first-occurrence order. Separate manual foods never merge.
List<List<FoodLogModel>> groupDiaryMeals(List<FoodLogModel> entries) {
  final groups = <List<FoodLogModel>>[];
  final meals = <String, List<FoodLogModel>>{};
  for (final food in entries) {
    final mealId = food.mealId;
    if (mealId == null) {
      groups.add([food]);
    } else {
      final group = meals[mealId];
      if (group == null) {
        final created = [food];
        meals[mealId] = created;
        groups.add(created);
      } else {
        group.add(food);
      }
    }
  }
  return groups;
}

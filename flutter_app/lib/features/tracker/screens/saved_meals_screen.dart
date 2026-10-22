import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../models/saved_meal_model.dart';
import '../providers/tracker_api.dart';
import 'meal_photo_screen.dart';

class SavedMealsScreen extends StatefulWidget {
  const SavedMealsScreen({super.key});
  @override
  State<SavedMealsScreen> createState() => _SavedMealsScreenState();
}

class _SavedMealsScreenState extends State<SavedMealsScreen> {
  late Future<List<SavedMealModel>> _meals;
  @override
  void initState() {
    super.initState();
    _meals = _load();
  }

  Future<List<SavedMealModel>> _load() async {
    final seen = <String>{};
    return (await TrackerApi().getSavedMeals())
        .where(
          (meal) => seen.add(
            jsonEncode({
              'name': meal.name,
              'ingredients': meal.ingredients.map((v) => v.toJson()).toList(),
            }),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.mealLibrary)),
      body: FutureBuilder<List<SavedMealModel>>(
        future: _meals,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.commonError),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() => _meals = _load()),
                      child: Text(l.mealRetry),
                    ),
                  ],
                ),
              ),
            );
          }
          final meals = snapshot.data ?? [];
          if (meals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.mealLibraryEmpty),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: meals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final meal = meals[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const Icon(Icons.restaurant_outlined),
                  title: Text(meal.name),
                  subtitle: Text(
                    '${l.mealPhotoItems(meal.ingredients.length)} · ${meal.toAnalysis().totals.kcal.round()} ${l.unitKcalShort}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final saved = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => MealPhotoScreen(
                          mealType: meal.mealType,
                          initialMeal: meal,
                        ),
                      ),
                    );
                    if (saved == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

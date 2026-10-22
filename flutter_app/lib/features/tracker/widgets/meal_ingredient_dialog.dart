import 'package:flutter/material.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../models/saved_meal_model.dart';

/// Explicit nutrition edits are portion totals, matching the diary convention.
class MealIngredientDialog extends StatefulWidget {
  final MealIngredient? ingredient;
  const MealIngredientDialog({super.key, this.ingredient});
  @override
  State<MealIngredientDialog> createState() => _MealIngredientDialogState();
}

class _MealIngredientDialogState extends State<MealIngredientDialog> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _fields;
  late double _lastGrams;
  @override
  void initState() {
    super.initState();
    final i = widget.ingredient;
    _lastGrams = i?.grams ?? 100;
    _fields = [
      i?.name ?? '',
      '${i?.grams ?? 100}',
      '${i?.calories ?? 0}',
      '${i?.protein ?? 0}',
      '${i?.carbs ?? 0}',
      '${i?.fat ?? 0}',
    ].map((v) => TextEditingController(text: v)).toList();
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  double _number(int i) =>
      double.parse(_fields[i].text.trim().replaceAll(',', '.'));
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = [
      l.addFoodName,
      l.mealIngredientGrams,
      l.addFoodCalories,
      l.addFoodProtein,
      l.trackerFoodCarbs,
      l.trackerFoodFat,
    ];
    return AlertDialog(
      title: Text(
        widget.ingredient == null ? l.mealAddIngredient : l.mealEditIngredient,
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.mealNutritionForPortion,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _fields.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _fields[i],
                      onChanged: i != 1
                          ? null
                          : (value) {
                              final grams = double.tryParse(
                                value.trim().replaceAll(',', '.'),
                              );
                              if (grams == null ||
                                  !grams.isFinite ||
                                  grams <= 0 ||
                                  grams > 100000) {
                                return;
                              }
                              for (
                                var nutrient = 2;
                                nutrient < _fields.length;
                                nutrient++
                              ) {
                                final current = double.tryParse(
                                  _fields[nutrient].text.replaceAll(',', '.'),
                                );
                                if (current != null && current.isFinite) {
                                  _fields[nutrient].text =
                                      (current * grams / _lastGrams)
                                          .toStringAsFixed(4);
                                }
                              }
                              _lastGrams = grams;
                            },
                      maxLength: i == 0 ? 200 : null,
                      decoration: InputDecoration(labelText: labels[i]),
                      keyboardType: i == 0
                          ? TextInputType.text
                          : const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                      validator: (v) {
                        if (i == 0) {
                          return v == null || v.trim().isEmpty
                              ? l.mealInvalidValue
                              : null;
                        }
                        final n = double.tryParse(
                          (v ?? '').trim().replaceAll(',', '.'),
                        );
                        return n == null ||
                                !n.isFinite ||
                                n > 100000 ||
                                (i == 1 ? n <= 0 : n < 0)
                            ? l.mealInvalidValue
                            : null;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              MealIngredient(
                name: _fields[0].text.trim(),
                grams: _number(1),
                calories: _number(2),
                protein: _number(3),
                carbs: _number(4),
                fat: _number(5),
              ),
            );
          },
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}

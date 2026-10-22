import 'package:flutter/material.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../models/food_log_model.dart';

/// A dish has one visible total; ingredient values are shown only when opened.
class LoggedMealTile extends StatelessWidget {
  final List<FoodLogModel> ingredients;
  final VoidCallback? onRepeat;
  final VoidCallback? onDelete;
  const LoggedMealTile({
    super.key,
    required this.ingredients,
    this.onRepeat,
    this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final calories = ingredients.fold<double>(0, (s, v) => s + v.calories);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(left: 12, bottom: 8),
      title: Text(
        ingredients.first.mealName ?? l.mealDefaultName,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${l.mealPhotoItems(ingredients.length)} · ${calories.round()} ${l.unitKcalShort}',
      ),
      children: [
        for (final food in ingredients)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(food.foodName),
            subtitle: Text(
              '${food.quantity.round()} ${l.addFoodUnitG} · ${food.calories.round()} ${l.unitKcalShort}',
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: onRepeat,
              icon: const Icon(Icons.replay_outlined),
              label: Text(l.mealRepeat),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: Text(l.commonDelete),
            ),
          ],
        ),
      ],
    );
  }
}

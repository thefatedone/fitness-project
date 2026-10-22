import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../models/food_log_model.dart';

/// Explicit membership is essential for old logs which have no dish group ID.
class BulkFoodDeleteDialog extends StatefulWidget {
  const BulkFoodDeleteDialog({
    super.key,
    required this.foods,
    required this.mealLabel,
  });
  final List<FoodLogModel> foods;
  final String mealLabel;

  @override
  State<BulkFoodDeleteDialog> createState() => _BulkFoodDeleteDialogState();
}

class _BulkFoodDeleteDialogState extends State<BulkFoodDeleteDialog> {
  late final Set<String> _selected = widget.foods
      .map((food) => food.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.bulkDeleteTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.mealLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(l10n.bulkDeleteExplanation),
              const SizedBox(height: 12),
              for (final food in widget.foods)
                CheckboxListTile(
                  key: ValueKey(food.id),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(food.foodName),
                  subtitle: Text(
                    '${food.calories.round()} ${l10n.unitKcalShort}',
                  ),
                  value: _selected.contains(food.id),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _selected.add(food.id);
                    } else {
                      _selected.remove(food.id);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          child: Text(l10n.bulkDeleteCount(_selected.length)),
        ),
      ],
    );
  }
}

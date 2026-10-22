import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/features/tracker/models/food_log_model.dart';
import 'package:nutrimind/features/tracker/widgets/bulk_food_delete_dialog.dart';
import 'package:nutrimind/l10n/gen/app_localizations.dart';

void main() {
  FoodLogModel food(String id) => FoodLogModel(
    id: id,
    userId: 'owner',
    date: DateTime(2026, 10, 20),
    mealType: 'lunch',
    foodName: id,
    calories: 100,
    protein: 10,
    carbs: 10,
    fat: 2,
    quantity: 100,
    unit: 'g',
    aiGenerated: true,
    createdAt: DateTime(2026, 10, 20),
  );

  testWidgets(
    'one confirmation deletes all ingredients, with optional exclusions',
    (tester) async {
      List<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<List<String>>(
                    context: context,
                    builder: (_) => BulkFoodDeleteDialog(
                      foods: [food('Рис'), food('Рыба'), food('Оставить')],
                      mealLabel: 'Обед',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить (3)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('Оставить')));
      await tester.pumpAndSettle();
      expect(find.text('Удалить (2)'), findsOneWidget);
      await tester.tap(find.text('Удалить (2)'));
      await tester.pumpAndSettle();
      expect(result, ['Рис', 'Рыба']);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить (3)'));
      await tester.pumpAndSettle();
      expect(result, ['Рис', 'Рыба', 'Оставить']);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (final name in ['Рис', 'Рыба', 'Оставить']) {
        await tester.tap(find.byKey(ValueKey(name)));
        await tester.pumpAndSettle();
      }
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );
}

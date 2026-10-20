import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/features/tracker/models/daily_goal_progress.dart';
import 'package:nutrimind/features/tracker/models/streak_model.dart';
import 'package:nutrimind/features/tracker/widgets/daily_goals_card.dart';
import 'package:nutrimind/features/tracker/widgets/streak_detail_sheet.dart';
import 'package:nutrimind/l10n/gen/app_localizations.dart';
import 'package:nutrimind/utils/accessibility_utils.dart';

void main() {
  test(
    'target range includes boundaries but never rewards excess or missing goals',
    () {
      for (final value in [90.0, 100.0, 110.0]) {
        expect(
          DailyGoalProgress(consumed: value, target: 100).isInRange,
          isTrue,
        );
      }
      expect(
        const DailyGoalProgress(consumed: 89, target: 100).isInRange,
        isFalse,
      );
      final above = const DailyGoalProgress(consumed: 111, target: 100);
      expect(above.isInRange, isFalse);
      expect(above.isAboveRange, isTrue);
      expect(above.progress, 1);
      for (final target in [null, 0.0, -1.0, double.nan, double.infinity]) {
        final goal = DailyGoalProgress(consumed: 100, target: target);
        expect(goal.isConfigured, isFalse);
        expect(goal.isInRange, isFalse);
        expect(goal.progress, 0);
      }
      for (final value in [-1.0, double.nan, double.infinity]) {
        expect(
          DailyGoalProgress(consumed: value, target: 100).isInRange,
          isFalse,
        );
      }
    },
  );

  Widget host(Widget child, {String locale = 'ru', double scale = 1}) =>
      ReduceTransparencyScope(
        notifier: ReduceTransparencyNotifier.instance,
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      );

  const inRange = DailyGoalProgress(consumed: 100, target: 100);
  const below = DailyGoalProgress(consumed: 50, target: 100);
  const over = DailyGoalProgress(consumed: 130, target: 100);
  const missing = DailyGoalProgress(consumed: 0, target: null);

  testWidgets('balance uses all four actual targets and reflects edits', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const DailyGoalsCard(
          calories: inRange,
          protein: inRange,
          carbs: below,
          fat: over,
        ),
      ),
    );
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('Выше диапазона'), findsOneWidget);
    expect(find.text('Все четыре показателя в диапазоне'), findsNothing);
    await tester.pumpWidget(
      host(
        const DailyGoalsCard(
          calories: inRange,
          protein: inRange,
          carbs: inRange,
          fat: inRange,
        ),
      ),
    );
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('Все четыре показателя в диапазоне'), findsOneWidget);
    await tester.pumpWidget(
      host(
        const DailyGoalsCard(
          calories: below,
          protein: inRange,
          carbs: inRange,
          fat: inRange,
        ),
      ),
    );
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('Все четыре показателя в диапазоне'), findsNothing);
  });

  testWidgets('missing targets provide a working profile action', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      host(
        DailyGoalsCard(
          calories: missing,
          protein: inRange,
          carbs: inRange,
          fat: inRange,
          onConfigure: () => opened = true,
        ),
      ),
    );
    expect(find.text('Цель не задана'), findsOneWidget);
    await tester.ensureVisible(find.text('Открыть профиль'));
    await tester.tap(find.text('Открыть профиль'));
    expect(opened, isTrue);
  });

  testWidgets('goals and streak fit narrow screens with large localized text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateUtils.dateOnly(DateTime.now());
    for (final locale in ['ru', 'en', 'ka']) {
      await tester.pumpWidget(
        host(
          const DailyGoalsCard(
            calories: inRange,
            protein: below,
            carbs: over,
            fat: missing,
          ),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'goals / $locale');
      await tester.pumpWidget(
        host(
          StreakDetailSheet(
            streak: StreakModel(
              currentStreak: 5,
              loggedToday: true,
              nextMilestone: 7,
              daysToNextMilestone: 2,
              history: List.generate(
                14,
                (i) => StreakDayModel(
                  date: DateTime(today.year, today.month, today.day - 13 + i),
                  logged: i >= 9,
                ),
              ),
            ),
          ),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'streak / $locale');
    }
  });
}

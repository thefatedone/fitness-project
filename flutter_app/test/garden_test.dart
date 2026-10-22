import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nutrimind/features/tracker/models/garden_model.dart';
import 'package:nutrimind/features/tracker/providers/tracker_provider.dart';
import 'package:nutrimind/features/tracker/screens/garden_screen.dart';
import 'package:nutrimind/features/tracker/widgets/garden_card.dart';
import 'package:nutrimind/features/tracker/widgets/avocado_tree.dart';
import 'package:nutrimind/l10n/gen/app_localizations.dart';
import 'package:nutrimind/utils/accessibility_utils.dart';

GardenModel garden(int days, {bool logged = false, bool pot = false}) =>
    GardenModel(
      today: DateTime(2026, 10, 20),
      totalDays: days,
      loggedToday: logged,
      weekDays: List.generate(
        7,
        (i) => GardenDay(date: DateTime(2026, 10, 19 + i), earned: i < 2),
      ),
      potUnlocked: pot,
    );

void main() {
  test('five stages and subsequent trees have exact boundaries', () {
    for (final entry in {
      0: 0,
      2: 0,
      3: 1,
      6: 1,
      7: 2,
      13: 2,
      14: 3,
      20: 3,
      21: 4,
      22: 0,
      42: 4,
      43: 0,
    }.entries) {
      expect(garden(entry.key).stage, entry.value, reason: '${entry.key} days');
      expect(garden(entry.key).growthDays, inInclusiveRange(0, 21));
      expect(garden(entry.key).stageProgress, inInclusiveRange(0, 1));
    }
    expect(garden(21).grownTrees, 1);
    expect(garden(22).daysToNextStage, 2);
    expect(garden(42).grownTrees, 2);
  });

  Widget host(Widget child, {String locale = 'ru', double scale = 1}) =>
      ReduceTransparencyScope(
        notifier: ReduceTransparencyNotifier.instance,
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: child,
        ),
      );

  testWidgets(
    'card opens garden; missing data never displays invented progress',
    (tester) async {
      var opened = false;
      var retried = false;
      await tester.pumpWidget(
        host(
          Scaffold(
            body: GardenCard(
              garden: garden(7, logged: true),
              loading: false,
              failed: false,
              onOpen: () => opened = true,
              onRetry: () {},
            ),
          ),
        ),
      );
      expect(find.text('Росток'), findsOneWidget);
      expect(find.text('Сегодня шаг получен'), findsOneWidget);
      await tester.tap(find.text('Росток'));
      await tester.pump();
      expect(opened, isTrue);
      await tester.pumpWidget(
        host(
          Scaffold(
            body: GardenCard(
              garden: null,
              loading: false,
              failed: true,
              onOpen: () {},
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      expect(find.byType(AvocadoTree), findsNothing);
      await tester.tap(find.byIcon(Icons.refresh));
      expect(retried, isTrue);
    },
  );

  testWidgets('garden fits narrow screens and large text in every locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tracker = TrackerProvider()..garden = garden(14, pot: true);
    addTearDown(tracker.dispose);
    for (final locale in ['ru', 'en', 'ka']) {
      await tester.pumpWidget(
        host(
          ChangeNotifierProvider.value(
            value: tracker,
            child: GardenScreen(onAddFood: () {}),
          ),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'screen $locale');
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'lower screen $locale');
      await tester.pumpWidget(
        host(
          Scaffold(
            body: SingleChildScrollView(
              child: GardenCard(
                garden: garden(21),
                loading: false,
                failed: false,
                onOpen: () {},
                onRetry: () {},
              ),
            ),
          ),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'card $locale');
    }
  });

  testWidgets(
    'every botanical stage paints without animation in reduced motion',
    (tester) async {
      for (var stage = 0; stage <= 4; stage++) {
        await tester.pumpWidget(
          host(
            Scaffold(
              body: SizedBox(
                width: 300,
                height: 260,
                child: AvocadoTree(stage: stage, decorated: stage >= 3),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      }
    },
  );
  testWidgets('preview changes the illustration without awarding progress', (
    tester,
  ) async {
    final tracker = TrackerProvider()..garden = garden(7, logged: true);
    addTearDown(tracker.dispose);
    await tester.pumpWidget(
      host(
        ChangeNotifierProvider.value(
          value: tracker,
          child: GardenScreen(onAddFood: () {}),
        ),
      ),
    );
    await tester.pump();
    final futureStage = find.byKey(const ValueKey('garden-stage-4'));
    await tester.ensureVisible(futureStage);
    await tester.pumpAndSettle();
    await tester.tap(futureStage);
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр этапа'), findsOneWidget);
    expect(tracker.garden!.totalDays, 7);
    expect(tracker.garden!.stage, 2);
    await tester.ensureVisible(find.text('Моё растение'));
    await tester.tap(find.text('Моё растение'));
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр этапа'), findsNothing);
  });
}

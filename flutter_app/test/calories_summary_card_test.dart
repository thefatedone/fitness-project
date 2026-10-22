import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/core/theme/app_theme.dart';
import 'package:nutrimind/features/tracker/widgets/calories_summary_card.dart';
import 'package:nutrimind/l10n/gen/app_localizations.dart';
import 'package:nutrimind/utils/accessibility_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, path) in [
      ('Comfortaa', 'assets/fonts/Comfortaa-VariableFont.ttf'),
      ('NotoSansGeorgian', 'assets/fonts/NotoSansGeorgian.ttf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });

  Widget host(
    double consumed,
    num? target, {
    String locale = 'ru',
    double width = 370,
    double scale = 1,
    bool dark = true,
  }) => ReduceTransparencyScope(
    notifier: ReduceTransparencyNotifier.instance,
    child: MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                ),
                child: CaloriesSummaryCard(consumed: consumed, target: target),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'remaining, reached and exceeded goals fit the existing card height',
    (tester) async {
      for (final (consumed, expected) in [
        (769.0, 'Осталось 1541 ккал'),
        (2310.0, 'Цель достигнута'),
        (2430.0, 'Выше цели на 120 ккал'),
        (2309.6, 'Цель достигнута'),
      ]) {
        await tester.pumpWidget(host(consumed, 2310));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        expect(
          tester.getSize(find.byType(CaloriesSummaryCard)).height,
          closeTo(134, .1),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('no target means no misleading remaining/reached status', (
    tester,
  ) async {
    for (final target in <num?>[null, 0, -1, double.infinity, double.nan]) {
      await tester.pumpWidget(host(769, target));
      await tester.pumpAndSettle();
      expect(find.text('Цель достигнута'), findsNothing);
      expect(find.textContaining('Осталось'), findsNothing);
      expect(find.textContaining('Выше цели'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'all locales and both themes fit narrow screens with large text',
    (tester) async {
      for (final locale in ['ru', 'en', 'ka']) {
        for (final dark in [true, false]) {
          for (final consumed in [769.0, 2310.0, 2430.0]) {
            await tester.pumpWidget(
              host(
                consumed,
                2310,
                locale: locale,
                width: 288,
                scale: 1.5,
                dark: dark,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$locale / $dark / $consumed',
            );
          }
        }
      }
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nutrimind/features/auth/providers/auth_provider.dart';
import 'package:nutrimind/features/tracker/models/food_log_model.dart';
import 'package:nutrimind/features/tracker/providers/tracker_provider.dart';
import 'package:nutrimind/features/tracker/screens/tracker_home_screen.dart';
import 'package:nutrimind/shared/widgets/app_dock.dart';
import 'package:nutrimind/shared/widgets/nutrimind_brand.dart';
import 'package:nutrimind/widgets/glass/glass_card.dart';
import 'package:nutrimind/l10n/gen/app_localizations.dart';
import 'package:nutrimind/utils/accessibility_utils.dart';

class _LayoutTracker extends TrackerProvider {
  @override
  Future<void> loadDailyData(DateTime date) async {}
  @override
  Future<void> loadWeightHistory() async {}
  @override
  Future<void> loadStreak() async {}
  @override
  Future<void> loadGarden() async {}
}

void main() {
  for (final (size, scale, dark) in [
    (const Size(402, 874), 1.0, true),
    (const Size(360, 780), 1.3, false),
  ]) {
    testWidgets('header and final dish clear navigation at $size / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final tracker = _LayoutTracker();
      final auth = AuthProvider();
      addTearDown(tracker.dispose);
      addTearDown(auth.dispose);
      tracker.foodLogs = [
        FoodLogModel(
          id: 'last',
          userId: 'owner',
          date: DateTime.now(),
          mealType: 'breakfast',
          foodName: 'Last banana',
          calories: 150,
          protein: 5,
          carbs: 60,
          fat: 0,
          quantity: 100,
          unit: 'g',
          aiGenerated: false,
          createdAt: DateTime.now(),
        ),
      ];
      await tester.pumpWidget(
        ReduceTransparencyScope(
          notifier: ReduceTransparencyNotifier.instance,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<TrackerProvider>.value(value: tracker),
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ],
            child: MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: const TrackerHomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NutriMindBrand), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(
        tester.getTopLeft(find.text('Today')).dy,
        greaterThan(tester.getBottomLeft(find.byType(NutriMindBrand)).dy),
      );
      final dock = find.byType(AppDock);
      expect(tester.getSize(dock).height, lessThan(150));
      await tester.scrollUntilVisible(
        find.text('Last banana'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final visibleBrand = find.byType(NutriMindBrand);
      if (visibleBrand.evaluate().isNotEmpty) {
        expect(tester.getBottomLeft(visibleBrand).dy, lessThanOrEqualTo(59));
      }
      final finalCard = find
          .ancestor(
            of: find.text('Last banana'),
            matching: find.byType(GlassCard),
          )
          .first;
      expect(
        tester.getBottomLeft(finalCard).dy,
        lessThanOrEqualTo(tester.getTopLeft(dock).dy - 16),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

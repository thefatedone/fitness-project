import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/features/tracker/widgets/meal_scan_overlay.dart';

void main() {
  testWidgets('sweep animates and meets continuously at the loop boundary', (
    tester,
  ) async {
    final phase = ValueNotifier<double>(0);
    final animation = _TestAnimation(phase);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 320,
              height: 240,
              child: ColoredBox(
                color: Colors.black,
                child: MealScanOverlay(phase: animation),
              ),
            ),
          ),
        ),
      ),
    );
    Future<List<int>> pixels() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List().toList();
    }

    final start = (await tester.runAsync(pixels))!;
    phase.value = .5;
    await tester.pump();
    final middle = (await tester.runAsync(pixels))!;
    expect(middle, isNot(orderedEquals(start)));
    phase.value = 1;
    await tester.pump();
    expect(await tester.runAsync(pixels), orderedEquals(start));
    await tester.pumpWidget(const SizedBox.shrink());
    phase.dispose();
  });

  testWidgets('overlay allows taps through and respects reduced motion', (
    tester,
  ) async {
    var tapped = false;
    Widget view(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Center(
          child: SizedBox(
            width: 320,
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapped = true,
                  child: const ColoredBox(color: Colors.black),
                ),
                const MealScanOverlay(phase: AlwaysStoppedAnimation(.5)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(view(false));
    await tester.tapAt(tester.getCenter(find.byType(MealScanOverlay)));
    expect(tapped, isTrue);
    expect(
      find.descendant(
        of: find.byType(MealScanOverlay),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(view(true));
    expect(
      find.descendant(
        of: find.byType(MealScanOverlay),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

class _TestAnimation extends Animation<double> {
  _TestAnimation(this.notifier);
  final ValueNotifier<double> notifier;
  @override
  double get value => notifier.value;
  @override
  AnimationStatus get status => AnimationStatus.forward;
  @override
  void addListener(VoidCallback listener) => notifier.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      notifier.removeListener(listener);
  @override
  void addStatusListener(AnimationStatusListener listener) {}
  @override
  void removeStatusListener(AnimationStatusListener listener) {}
}

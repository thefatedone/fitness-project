import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/core/performance/frame_metrics.dart';
import 'package:nutrimind/features/tracker/models/diary_meal_group.dart';
import 'package:nutrimind/features/tracker/models/food_log_model.dart';
import 'package:nutrimind/shared/widgets/photo_preview.dart';

FoodLogModel food(String id, [String? meal]) => FoodLogModel(
  id: id,
  userId: 'owner',
  date: DateTime(2026, 10, 21),
  mealType: 'lunch',
  foodName: 'Rice',
  calories: 100,
  protein: 3,
  carbs: 20,
  fat: 1,
  quantity: 100,
  unit: 'g',
  aiGenerated: false,
  createdAt: DateTime(2026, 10, 21),
  mealId: meal,
);

void main() {
  test(
    'groups retain stable order, all ingredients and separate manual foods',
    () {
      final entries = [
        food('1', 'a'),
        food('2'),
        food('3', 'b'),
        food('4', 'a'),
        food('5'),
      ];
      final groups = groupDiaryMeals(entries);
      expect(groups.map((g) => g.map((f) => f.id).toList()).toList(), [
        ['1', '4'],
        ['2'],
        ['3'],
        ['5'],
      ]);
      expect(groupDiaryMeals([]), isEmpty);
    },
  );
  test('large single dish keeps every ingredient exactly once', () {
    final entries = List.generate(1000, (i) => food('$i', 'a'));
    final groups = groupDiaryMeals(entries);
    expect(groups, hasLength(1));
    expect(groups.single, orderedEquals(entries));
  });
  test(
    'frame budget adapts to refresh rate; build and raster are pipelined',
    () {
      final metrics = FrameMetrics();
      metrics.add(buildMicros: 7000, rasterMicros: 7000);
      metrics.add(buildMicros: 10000, rasterMicros: 2000);
      expect(metrics.report(60)['over_budget_frames'], 0);
      expect(metrics.report(120)['over_budget_frames'], 1);
      expect(metrics.report(120)['build_p95_ms'], 10);
      expect(metrics.report(0)['display_hz'], 60);
    },
  );
  test('metrics window remains bounded and clears on lifecycle reset', () {
    final metrics = FrameMetrics(capacity: 2);
    metrics.add(buildMicros: 100000, rasterMicros: 100000);
    metrics.add(buildMicros: 1000, rasterMicros: 2000);
    metrics.add(buildMicros: 3000, rasterMicros: 4000);
    expect(metrics.length, 2);
    expect(metrics.report(60)['over_budget_frames'], 0);
    expect(metrics.report(60)['raster_max_ms'], 4);
    metrics.clear();
    expect(metrics.report(60)['build_p95_ms'], 0);
  });
  testWidgets('large photo decodes a bounded preview without altering source', (
    tester,
  ) async {
    // Generate a source larger than the 2048px decode limit.
    final prepared = await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'nutrimind-preview-',
      );
      final file = File('${directory.path}/camera.png');
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.green, BlendMode.src);
      final picture = recorder.endRecording();
      final source = await picture.toImage(3000, 2000);
      final png = (await source.toByteData(format: ui.ImageByteFormat.png))!;
      await file.writeAsBytes(png.buffer.asUint8List());
      final size = await file.length();
      picture.dispose();
      source.dispose();
      return (directory, file, size);
    });
    final (directory, file, originalSize) = prepared!;
    addTearDown(() => directory.delete(recursive: true));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: PhotoPreview(file: file),
        ),
      ),
    );
    final widget = tester.widget<Image>(find.byType(Image));
    final provider = widget.image as ResizeImage;
    expect(provider.policy, ResizeImagePolicy.fit);
    expect(provider.width, lessThanOrEqualTo(2048));
    final stream = provider.resolve(ImageConfiguration.empty);
    ui.Image? decoded;
    final listener = ImageStreamListener((info, _) {
      decoded = info.image.clone();
    });
    stream.addListener(listener);
    for (var i = 0; i < 100 && decoded == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(2048));
    expect(decoded!.height, lessThanOrEqualTo(2048));
    expect(decoded!.width / decoded!.height, closeTo(1.5, .01));
    expect(await tester.runAsync(() => file.length()), originalSize);
    stream.removeListener(listener);
    decoded!.dispose();
    await tester.pumpWidget(const SizedBox());
    await provider.evict();
  });
}

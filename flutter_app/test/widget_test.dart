// Minimal widget smoke test for the NutriMind app.
//
// The default `flutter create` template ships a counter test that pokes at
// `MyApp` and an `Icons.add` button — neither of which exist any more in
// this app. We just want to confirm that the root widget builds without
// throwing, so we `pumpWidget` it directly.
//
// `NutriMindApp` instantiates `AuthProvider()` whose constructor (via the
// shared `tokenStorage`) reaches for `flutter_secure_storage`'s method
// channel. That channel has no real platform implementation in the test
// binding, so we mock it in `setUp` to return null/empty for every call
// — equivalent to "no token stored yet".
//
// A true end-to-end test would need either an integration test or a fake
// `TokenStorage`, neither of which is in scope for this smoke check.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrimind/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // flutter_secure_storage uses this channel for all read/write/delete
    // calls. Returning null makes every read return null (no token), which
    // is exactly the unauthenticated state we want for the smoke test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/flutter_secure_storage'),
      null,
    );
  });

  testWidgets('NutriMindApp mounts cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const NutriMindApp());

    // Let one frame settle so AuthGate (which renders a centered
    // CircularProgressIndicator while AuthStatus is `unknown`) has a
    // chance to appear — and so any synchronous build errors surface
    // here rather than as a hung test.
    await tester.pump();
  });
}

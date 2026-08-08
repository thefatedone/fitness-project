import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper over a small platform channel that asks the host OS
/// (currently iOS only) whether the user has enabled any accessibility
/// settings that materially change how the app renders.
///
/// Today this is read for exactly one thing: the
/// `UIAccessibility.isReduceTransparencyEnabled` flag (Settings →
/// Accessibility → Display & Text Size → Reduce Transparency). When
/// that is `true`, Apple expects apps to substitute solid surfaces for
/// any translucent / blurred material — otherwise the visual artefacts
/// you get when you draw arbitrary content through a blur become a real
/// legibility problem for users who turned the setting on in the first
/// place.
///
/// The channel name and method names are intentionally tied to the iOS
/// native side (see `ios/Runner/AppDelegate.swift`) and are not yet
/// implemented on Android. [isReduceTransparencyEnabled] catches every
/// failure mode the channel surface can produce — including the
/// `MissingPluginException` raised on Android, in unit tests, and in
/// hot-reload windows where the Dart isolate is up but the Swift
/// registration hasn't reattached — and falls back to `false` so the
/// call site never has to care.
///
/// Live-update design choice: the obvious "right" answer is an
/// `EventChannel` paired with `UIAccessibilityReduceTransparencyStatusDidChange`
/// notifications on iOS. We deliberately don't do that. Reasoning:
///
///   * The realistic flow is "user opens Settings → toggles Reduce
///     Transparency → returns to the app", at which point
///     `AppLifecycleState.resumed` fires and the only consumer
///     (`AppDock`) re-queries.
///   * An EventChannel means a separate `FlutterStreamHandler`, a
///     notification observer that retains the Flutter channel handler,
///     careful teardown so the listener doesn't dangle past a
///     hot-restart, and a queue-overrun policy. That's meaningfully
///     more native + Dart code than the task warrants.
///   * If we ever need fine-grained in-foreground updates (e.g. an
///     in-app control that toggles the same surface), we'll reach for
///     EventChannel then. For now this comment is the design
///     rationale so the choice doesn't look accidental when someone
///     finds `didChangeAppLifecycleState` in the Dock.
class AccessibilityService {
  /// Channel name. Must match the `FlutterMethodChannel(name:)`
  /// registration in `ios/Runner/AppDelegate.swift`.
  static const MethodChannel _channel =
      MethodChannel('com.nutrimind.nutrimind/accessibility');

  /// Whether the host OS confirms the user has enabled an
  /// accessibility setting (currently only "Reduce Transparency" on
  /// iOS) that should cause the app to substitute solid surfaces for
  /// translucent / blurred material.
  ///
  /// Returns `false` whenever the native side is unreachable or has
  /// not implemented the channel — i.e. on Android, in unit tests,
  /// in hot-reload states where the Dart isolate is up but the Swift
  /// side hasn't re-registered, or anywhere else the channel
  /// silently swallows the call.
  ///
  /// The "false = normal" fallback is intentional: every consumer
  /// of this value uses it to decide whether to *opt out* of a
  /// feature (frosted glass). Silently showing the design's intended
  /// visual when we can't positively confirm the user wants the
  /// accessible fallback is the lower-risk default — the inverse
  /// would silently degrade the design for users who never asked
  /// for it.
  static Future<bool> isReduceTransparencyEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isReduceTransparencyEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e, st) {
      // Best-effort UX plumbing, not a user-facing action — a
      // debugPrint leaves a trail in `flutter run` / Xcode console
      // without dragging the user into a crash dialog.
      debugPrint(
        'AccessibilityService.isReduceTransparencyEnabled: '
        'PlatformException (code=${e.code}, message=${e.message})\n$st',
      );
      return false;
    } on MissingPluginException catch (e, st) {
      // The expected "Android / unit test / hot-reload" path. The
      // iOS AppDelegate is the only handler — every other surface
      // raises this. Documented once here so callers can grep for
      // the failure mode when debugging their own channel wiring.
      debugPrint(
        'AccessibilityService.isReduceTransparencyEnabled: '
        'MissingPluginException (no native handler registered). '
        'Treating as enabled=false.\n$st',
      );
      return false;
    } catch (e, st) {
      // Defensive: any other failure mode (encoding errors, etc.)
      // still resolves to a safe default so the caller never sees
      // an exception.
      debugPrint(
        'AccessibilityService.isReduceTransparencyEnabled: '
        'unexpected error $e\n$st',
      );
      return false;
    }
  }
}

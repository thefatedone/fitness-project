import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // ----- NutriMind ↔ iOS accessibility bridge -----
    //
    // Exposes `UIAccessibility.isReduceTransparencyEnabled` to Dart over a
    // small MethodChannel so the home-screen `AppDock` can fall back to a
    // solid background when the user has enabled "Reduce Transparency"
    // (Settings → Accessibility → Display & Text Size → Reduce
    // Transparency). Apple ships its own apps with the same fallback —
    // any translucent/blurred material becomes a legibility problem for
    // users who turned the setting on in the first place, so we must
    // respect it.
    //
    // The implicit-engine plugin registry is the natural place to acquire
    // a `FlutterBinaryMessenger`: it's the same registry third-party
    // plugins use, so any lifecycle quirks (rotation, hot-restart, etc.)
    // are the platform team's problem, not ours, and the messenger
    // remains valid for the lifetime of the engine.
    //
    // Android does not implement this channel — see
    // `lib/core/platform/accessibility_service.dart`, which catches
    // `MissingPluginException` and falls back to `false` so the
    // frosted-glass effect still renders there.
    if let registrar = engineBridge.pluginRegistry
      .registrar(forPlugin: "AccessibilityChannel")
    {
      let channel = FlutterMethodChannel(
        name: "com.nutrimind.nutrimind/accessibility",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "isReduceTransparencyEnabled":
          // Reading the class property on every call (rather than
          // caching) is intentional: `UIAccessibility` is updated
          // synchronously by the system when the user toggles the
          // setting in the background, and the only "staleness"
          // we'd worry about is the user toggling it *without*
          // backgrounding our app — a flow iOS doesn't actually
          // allow in practice.
          result(UIAccessibility.isReduceTransparencyEnabled)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

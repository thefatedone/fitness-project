import 'package:flutter/widgets.dart';

import '../core/platform/accessibility_service.dart';

/// Shared, app-wide source of truth for "is Reduce Transparency enabled
/// right now". Every glass widget in `lib/widgets/glass/` reads its
/// current value through [ReduceTransparencyScope.of] so the
/// frosted-glass → solid fallback lives in one place — not three.
///
/// Implementation: a [ChangeNotifier] singleton with the
/// [WidgetsBindingObserver] lifecycle hook (the same one the Dock
/// used to maintain locally) so the value is re-queried on every
/// `AppLifecycleState.resumed` event. That's the only realistic
/// moment a user could have just toggled Reduce Transparency in
/// iOS Settings while our app was backgrounded.
///
/// The underlying platform-channel call still lives in
/// `lib/core/platform/accessibility_service.dart` — the singleton here
/// is just a stateful wrapper. Kept separate so the platform-channel
/// can be unit-tested in isolation without dragging the widget tree
/// in.
class ReduceTransparencyNotifier extends ChangeNotifier
    with WidgetsBindingObserver {
  /// Initial value `false` matches the Dock's prior behaviour: the
  /// first frame (drawn before the platform-channel round-trip
  /// resolves) is the design's intended frosted-glass look. The
  /// channel's own [AccessibilityService] also defaults to `false`
  /// for every failure mode, so we converge on the same value here.
  bool _reduceTransparency = false;
  bool get reduceTransparency => _reduceTransparency;

  /// Tracks whether we've ever received the first async reply from
  /// the platform channel. Used so widgets can choose to either
  /// (a) wait for the first read or (b) show the design's intended
  /// glass look until told otherwise. We currently take the
  /// latter — same as the Dock did before this refactor.
  bool _hasResolvedOnce = false;
  bool get hasResolvedOnce => _hasResolvedOnce;

  /// Latches `true` after the first [ensureAttached] call so we
  /// don't double-register the lifecycle observer if the scope is
  /// re-mounted (e.g. on hot reload, or if a sub-tree replaces its
  /// [ReduceTransparencyScope]).
  bool _attached = false;

  ReduceTransparencyNotifier._();

  /// The single instance. Created lazily on first [ensureAttached].
  static final ReduceTransparencyNotifier instance =
      ReduceTransparencyNotifier._();

  /// Idempotently registers the lifecycle observer and kicks off
  /// the first async read. Called from [ReduceTransparencyScope]'s
  /// `attach` path (which the framework invokes exactly once per
  /// [Element.activate]) and also safe to call from `main()` if a
  /// caller wants the channel round-trip to start before the first
  /// frame.
  ///
  /// We can't put this in the constructor: the singleton is
  /// created at static-init time, before `WidgetsFlutterBinding`
  /// is guaranteed initialised — touching [WidgetsBinding.instance]
  /// then would assert.
  void ensureAttached() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final next = await AccessibilityService.isReduceTransparencyEnabled();
    if (!hasListeners) return;
    final changed = next != _reduceTransparency || !_hasResolvedOnce;
    if (changed) {
      _reduceTransparency = next;
      _hasResolvedOnce = true;
      notifyListeners();
    }
  }
}

/// Inherited widget exposing the [ReduceTransparencyNotifier] to the
/// subtree. Mount this once near the top of the app (above the
/// `MaterialApp`, so both the navigator and every screen see it)
/// and read the value in any glass widget via
/// [ReduceTransparencyScope.of].
///
/// `main()` is responsible for calling
/// [ReduceTransparencyNotifier.ensureAttached] before `runApp` —
/// the scope can't override `attach` from outside the `widgets`
/// package because that method is `@protected`.
class ReduceTransparencyScope extends InheritedNotifier {
  const ReduceTransparencyScope({
    super.key,
    required ReduceTransparencyNotifier super.notifier,
    required super.child,
  });

  /// Reads the current value. Throws (asserts in debug) if no
  /// [ReduceTransparencyScope] is mounted above [context].
  ///
  /// We intentionally do NOT return a fallback default — every glass
  /// widget's contract is "the caller has wrapped the app in this
  /// scope". An assertion here catches a forgotten wrap at dev time
  /// rather than letting a glass surface silently render with the
  /// wrong surface treatment in release.
  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ReduceTransparencyScope>();
    assert(
      scope != null,
      'ReduceTransparencyScope.of() called with a context that does '
      'not have a ReduceTransparencyScope ancestor. Wrap your app '
      'with ReduceTransparencyScope(child: ...) above MaterialApp.',
    );
    return (scope!.notifier as ReduceTransparencyNotifier)
        .reduceTransparency;
  }

  /// For cases where the calling widget needs to subscribe to changes
  /// (the typical case for `Builder` blocks that want to rebuild
  /// when the setting flips). Identical value to [of]; the API
  /// distinction is purely documentary — both call
  /// `dependOnInheritedWidgetOfExactType` so both subscribe.
  static ReduceTransparencyNotifier watch(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ReduceTransparencyScope>();
    assert(
      scope != null,
      'ReduceTransparencyScope.watch() called with a context that '
      'does not have a ReduceTransparencyScope ancestor.',
    );
    return scope!.notifier as ReduceTransparencyNotifier;
  }
}
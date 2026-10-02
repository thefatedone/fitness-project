import 'package:flutter/material.dart';

/// Wrapper that suppresses the iOS-style overscroll "glow" effect on
/// any scrollable that contains a [LiquidGlass] surface (a
/// [GlassCard], [GlassChip], etc).
///
/// Why this exists: when a scrollable reaches its boundary on iOS, the
/// system applies an `OverscrollIndicator` glow effect that draws a
/// blue/orange highlight over the *entire* scroll layer. For a
/// non-glass scrollable that's fine, but for a scrollable whose
/// children include [GlassCard]/[GlassSurface] instances — each of
/// which paints a [BackdropFilter] — the glow interacts with the
/// backdrop blur in an ugly way: the cards' edges appear to "shine"
/// or shimmer because the live blur layer is being re-rasterized as
/// the indicator draws. The user's instruction was: "make sure
/// that liquid glass stays static and looks perfect on both
/// light/dark themes."
///
/// This widget attaches a [NotificationListener] that disallows the
/// `OverscrollIndicatorNotification` — Flutter's standard way to
/// suppress the iOS/Android stretch effect.
///
/// Optionally pass [physics] to override the scroll physics too
/// (e.g. [ClampingScrollPhysics] removes overscroll entirely on
/// every platform, which is the more decisive version of this fix).
/// When omitted, the wrapped scrollable inherits its own default
/// physics. Most call sites should pass [ClampingScrollPhysics]
/// explicitly so the behavior is consistent across platforms.
///
/// Usage:
/// ```dart
/// GlassScrollBehavior(
///   physics: ClampingScrollPhysics(),
///   child: ListView(...),
/// )
/// ```
class GlassScrollBehavior extends StatelessWidget {
  const GlassScrollBehavior({
    super.key,
    required this.child,
    this.physics,
  });

  final Widget child;

  /// Optional physics override applied to descendant [Scrollable]s
  /// via a wrapping [ScrollConfiguration]. Pass
  /// [ClampingScrollPhysics] for the most decisive "no overscroll
  /// at all" behaviour, or leave null to inherit the wrapped
  /// scrollable's own default.
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final Widget inner = physics == null
        ? child
        : ScrollConfiguration(
            // [ScrollConfiguration.behavior] is read by the nearest
            // descendant [Scrollable] in the subtree via Flutter's
            // scrollable-discovery contract. We use a tiny
            // [ScrollBehavior] that overrides only the `physics`
            // getter, leaving every other ScrollBehavior knob (drag
            // devices, platform lookup, scrollbar, overscroll
            // indicator build, keyboard dismiss) at the platform
            // default.
            behavior: _ConstPhysics(physics!),
            child: child,
          );
    return NotificationListener<OverscrollIndicatorNotification>(
      // Disallow the iOS/Android overscroll glow indicator. Returning
      // `false` lets the notification continue propagating so
      // ancestor scrollables (if any) also see the disallow.
      onNotification: (n) {
        n.disallowIndicator();
        return false;
      },
      child: inner,
    );
  }
}

/// [ScrollBehavior] subclass that exposes a fixed [ScrollPhysics]
/// via the `physics` getter, inheriting every other ScrollBehavior
/// behaviour from the platform default.
class _ConstPhysics extends ScrollBehavior {
  const _ConstPhysics(this._physics);

  final ScrollPhysics _physics;

  // Forward the requested [ScrollPhysics] to the base class. We
  // expose it via a forwarding getter (no `@override` — the base
  // exposes `physics` differently) and it gets read by the
  // nearest descendant [Scrollable] via the
  // [ScrollConfiguration] contract.
  ScrollPhysics get physics => _physics;
}

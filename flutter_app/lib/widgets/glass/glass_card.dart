import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../theme/glass_tokens.dart';
import 'glass_surface.dart';

/// A padded Liquid Glass card with an optional [onTap]. The press
/// animation is spring-driven (via [SpringSimulation]) rather than
/// the easier `Curves.easeOut` — the bouncy spring feel is what
/// makes glass surfaces feel like physical glass rather than
/// tinted rectangles.
///
/// When the user presses, the scale drops to
/// [GlassTokens.pressedScale] (~0.97) with a haptic tick; on release
/// the spring overshoots back to 1.0 with a small bounce. The same
/// shape (no haptic on a no-op card, only on the press event)
/// matches what iOS does on UITableViewCell selection.
///
/// Accessibility:
///
///   * `MediaQuery.disableAnimations` (system "Reduce Motion") is
///     respected — every spring/scale collapses into an instant
///     state change instead of animating.
///   * The Reduce Transparency fallback is delegated to [GlassSurface]
///     (see `accessibility_utils.dart`) so this widget inherits it
///     for free.
///
/// Performance:
///
///   * Wrapped in a [RepaintBoundary] so the spring scale animation
///     doesn't drag the underlying [GlassSurface] (and its blur) into
///     every rebuild — the blur runs in its own layer, the scale
///     runs in its own.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.emphasized = false,
    this.borderRadius,
    this.hapticOnPress = true,
    this.borderColorOverride,
    this.suppressBlur,
  });

  /// Inner content of the card.
  final Widget child;

  /// Optional tap callback. When `null`, the card is rendered
  /// without a press animation — pure display surface.
  final VoidCallback? onTap;

  /// Inner padding. Defaults to 16px on all sides, matching the
  /// existing `Card` usage throughout the app.
  final EdgeInsetsGeometry padding;

  /// Pushes the tint toward brand colour (used by primary
  /// "Continue" / "Save" cards that should feel heavier than
  /// neutral info cards).
  final bool emphasized;

  /// Optional override of the card's corner radius.
  final BorderRadius? borderRadius;

  /// When `false`, the press event is silent — no haptic. Useful
  /// for cards in dense lists where haptic-per-press is noisy.
  final bool hapticOnPress;

  /// Optional border-colour override propagated to [GlassSurface].
  /// Use for confidence-tinted borders (e.g. photo-recognition
  /// result card glows with the brand colour when the AI
  /// reported high confidence).
  final Color? borderColorOverride;

  /// When non-null, propagated to [GlassSurface] as a
  /// "drop the blur right now" hint — typically wired to a
  /// scroll-velocity notifier so a fast-swiping ListView doesn't
  /// drag every glass card through a blur recompute on every
  /// frame. A `true` value forces the solid fallback path even
  /// when Reduce Transparency is off.
  final ValueListenable<bool>? suppressBlur;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _scaleValue = 1.0;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _controller.value = _scaleValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns `true` if the user has system "Reduce Motion"
  /// enabled. Cached per-build via the call-site's [MediaQuery]
  /// lookup — the cost is one build-time property read.
  bool _reduceMotion(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;

  void _onPressStart() {
    if (widget.onTap == null) return;
    if (!_pressed) {
      _pressed = true;
      if (widget.hapticOnPress) HapticFeedback.lightImpact();
      if (_reduceMotion(context)) {
        // Reduce Motion: skip the spring entirely — snap to
        // the pressed scale and let the release spring (if any)
        // collapse too. The card still flips to its pressed state
        // visually; it just doesn't animate.
        setState(() => _scaleValue = GlassTokens.pressedScale);
      } else {
        _runSpring(target: GlassTokens.pressedScale);
      }
    }
  }

  void _onPressEnd() {
    if (widget.onTap == null) return;
    if (_pressed) {
      _pressed = false;
      if (_reduceMotion(context)) {
        setState(() => _scaleValue = 1.0);
      } else {
        _runSpring(target: 1.0);
      }
    }
  }

  /// Drives [scaleValue] toward [target] via a [SpringSimulation]
  /// built from [GlassTokens.pressSpring]. The animation runs as a
  /// raw ticker rather than via `AnimationController.animateWith`
  /// so we can keep the destination value elastic (overshoots
  /// then settles) — what gives glass its tactile feel.
  void _runSpring({required double target}) {
    final simulation = SpringSimulation(
      GlassTokens.pressSpring,
      _scaleValue,
      target,
      0, // initial velocity
    );
    _controller.removeListener(_onTick);
    _controller.addListener(_onTick);
    _controller.animateWith(simulation);
  }

  void _onTick() {
    setState(() {
      _scaleValue = _controller.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: interactive ? (_) => _onPressStart() : null,
        onTapUp: interactive ? (_) => _onPressEnd() : null,
        onTapCancel: interactive ? () => _onPressEnd() : null,
        onTap: widget.onTap,
        child: Transform.scale(
          scale: _scaleValue,
          child: GlassSurface(
            padding: widget.padding,
            emphasized: widget.emphasized,
            borderRadius: widget.borderRadius,
            borderColorOverride: widget.borderColorOverride,
            suppressBlur: widget.suppressBlur,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
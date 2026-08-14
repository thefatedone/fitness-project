import 'package:flutter/material.dart';

import 'glass_chip.dart';

/// "Recalculated"-style Liquid Glass badge that briefly scales up
/// and back whenever the wrapped [label] changes.
///
/// Usage: wrap the badge content in this widget, keyed by the
/// value the user just saw change. When the label changes (new
/// food entry, updated macro count, etc.), this widget triggers
/// a 1.0 → [peakScale] → 1.0 pulse over [duration] using
/// [Curves.easeOutCubic]. The pulse rides on top of a
/// [GlassChip] so the badge itself picks up the Liquid Glass
/// treatment.
///
/// Detection: the widget holds the previous [label] in [State]
/// and, on each `didUpdateWidget`, runs the pulse animation if
/// the label changed (including the initial mount, where
/// `didChangeDependencies` fires the first pulse).
class GlassScalePulseBadge extends StatefulWidget {
  const GlassScalePulseBadge({
    super.key,
    required this.label,
    this.color,
    this.duration = const Duration(milliseconds: 300),
    this.peakScale = 1.08,
  });

  final String label;
  final Color? color;
  final Duration duration;
  final double peakScale;

  @override
  State<GlassScalePulseBadge> createState() => _GlassScalePulseBadgeState();
}

class _GlassScalePulseBadgeState extends State<GlassScalePulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    // Fire the first pulse on mount so a freshly-mounted badge
    // (e.g. the result view just appeared) reads as "something
    // happened here" rather than sitting silently.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firePulse();
    });
  }

  @override
  void didUpdateWidget(covariant GlassScalePulseBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      _firePulse();
    }
  }

  void _firePulse() {
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `TweenSequence` walks through `1.0 → peakScale` for the
    // first half of the controller's window and `peakScale →
    // 1.0` for the second half. `easeOutCubic` on the rise +
    // `easeInCubic` on the fall gives the pulse a subtle
    // "overshoot, settle" feel without bouncing.
    final pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: widget.peakScale)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.peakScale, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 1,
      ),
    ]);
    // Reduce Motion: when the system has animations disabled
    // (Settings → Accessibility → Reduce Motion on iOS), the
    // badge still updates its label (the underlying chip rebuilds
    // with the new text), but the scale pulse collapses to an
    // instant rest at 1.0 — no flash, no overshoot.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _controller.isAnimating) {
      _controller.stop();
    }
    return RepaintBoundary(
      child: ScaleTransition(
        scale: reduceMotion ? const AlwaysStoppedAnimation(1.0) : _controller.drive(pulse),
        child: GlassChip(label: widget.label, color: widget.color),
      ),
    );
  }
}
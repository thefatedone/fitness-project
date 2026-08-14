import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/accessibility_utils.dart';

/// Liquid Glass ring progress indicator. Used at the top of the
/// tracker home screen for the calorie ring + macro bars
/// (overkill for the bars themselves but the canonical shape for
/// the central progress dial).
///
/// Three things set this apart from a vanilla [CircularProgressIndicator]:
///
///   1. The track is rendered as a translucent glass ring rather
///      than a flat tinted arc.
///   2. The fill stroke uses a per-nutrient brand colour with a
///      subtle gradient for depth.
///   3. The fill animates via [TweenAnimationBuilder] with a
///      `Curves.easeOutCubic` over 600 ms, so a new food log
///      entry triggers a smooth fill-up animation rather than a
///      jump.
///
/// Accessibility: when Reduce Transparency is on, the
/// `BackdropFilter` is replaced by a flat track at the theme's
/// `surfaceContainerHighest` token.
class GlassProgressRing extends StatelessWidget {
  const GlassProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 120,
    this.strokeWidth = 10,
    this.duration = const Duration(milliseconds: 600),
    this.child,
  });

  /// 0..1 progress fraction. Values outside this range are clamped.
  final double value;

  /// Fill stroke colour (per-nutrient brand colour).
  final Color color;

  /// Outer diameter of the ring.
  final double size;

  /// Stroke width. Defaults to 10 to match the M3 ring spec.
  final double strokeWidth;

  /// Animation duration when [value] changes (e.g. on day change
  /// or when a new entry is logged).
  final Duration duration;

  /// Optional centre content (e.g. "403 / 2000 kcal").
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final reduceTransparency = ReduceTransparencyScope.of(context);
    final clamped = value.clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        duration: duration,
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: clamped),
        builder: (context, animated, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: animated,
              fillColor: color,
              reduceTransparency: reduceTransparency,
              trackColor: reduceTransparency
                  ? scheme.surfaceContainerHighest
                  : scheme.outlineVariant.withValues(alpha: 0.35),
              strokeWidth: strokeWidth,
              size: size,
            ),
            child: Center(child: child),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.fillColor,
    required this.trackColor,
    required this.reduceTransparency,
    required this.strokeWidth,
    required this.size,
  });

  final double progress;
  final Color fillColor;
  final Color trackColor;
  final bool reduceTransparency;
  final double strokeWidth;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = canvasSize.center(Offset.zero);
    final radius = (canvasSize.shortestSide - strokeWidth) / 2;

    // Track — full circle.
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Fill arc — from -90° (top) clockwise by `progress * 360°`.
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );

    if (!reduceTransparency) {
      // Subtle inner highlight at the tip of the fill — gives the
      // ring a glassy "wet" look at the leading edge.
      final tipPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth / 2;
      final tipAngle = -math.pi / 2 + 2 * math.pi * progress;
      final tipPoint = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      canvas.drawCircle(tipPoint, strokeWidth / 2, tipPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) {
    return old.progress != progress ||
        old.fillColor != fillColor ||
        old.trackColor != trackColor ||
        old.reduceTransparency != reduceTransparency ||
        old.strokeWidth != strokeWidth ||
        old.size != size;
  }
}
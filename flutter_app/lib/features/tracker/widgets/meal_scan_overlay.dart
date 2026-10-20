import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative scanning light. It deliberately makes no detection or progress
/// claims: ingredient locations are only available when analysis completes.
class MealScanOverlay extends StatelessWidget {
  const MealScanOverlay({super.key, required this.phase, this.opacity = 1});

  final Animation<double> phase;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ScanLightPainter(
              phase: phase,
              opacity: opacity,
              accent: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanLightPainter extends CustomPainter {
  _ScanLightPainter({
    required this.phase,
    required this.opacity,
    required this.accent,
  }) : super(repaint: phase);

  final Animation<double> phase;
  final double opacity;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || opacity <= 0) return;
    final bounds = Offset.zero & size;
    // Cosine keeps both position and velocity continuous at the loop seam.
    final travel = (1 - math.cos(phase.value * 2 * math.pi)) / 2;
    final y = size.height * (0.12 + travel * 0.76);
    final band = Rect.fromLTWH(
      0,
      y - size.height * .16,
      size.width,
      size.height * .32,
    );
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0),
            accent.withValues(alpha: .12 * opacity),
            Colors.white.withValues(alpha: .16 * opacity),
            accent.withValues(alpha: 0),
          ],
          stops: const [0, .44, .5, 1],
        ).createShader(band),
    );
    final line = Rect.fromLTWH(size.width * .07, y, size.width * .86, 1);
    canvas.drawRect(
      line,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .65 * opacity),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(line),
    );

    // A quiet viewfinder anchors the effect without obscuring the meal.
    final frame = bounds.deflate(18);
    final length = math.min(22.0, frame.shortestSide * .12);
    if (length > 0) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: .65 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (final corner in [
        (frame.topLeft, 1.0, 1.0),
        (frame.topRight, -1.0, 1.0),
        (frame.bottomLeft, 1.0, -1.0),
        (frame.bottomRight, -1.0, -1.0),
      ]) {
        final origin = corner.$1;
        final path = Path()
          ..moveTo(origin.dx, origin.dy + length * corner.$3)
          ..lineTo(origin.dx, origin.dy + 6 * corner.$3)
          ..quadraticBezierTo(
            origin.dx,
            origin.dy,
            origin.dx + 6 * corner.$2,
            origin.dy,
          )
          ..lineTo(origin.dx + length * corner.$2, origin.dy);
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanLightPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.opacity != opacity ||
      oldDelegate.accent != accent;
}

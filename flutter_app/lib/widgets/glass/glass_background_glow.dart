import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../theme/glass_tokens.dart';
import '../../utils/accessibility_utils.dart';

/// Static (non-scrolling, non-reactive) ambient glow layer that sits
/// behind any screen using Liquid Glass surfaces. Pre-rendered
/// radial gradients — no runtime shader cost, no animated
/// dependencies — that give the [BackdropFilter] on each
/// [GlassCard] something to actually blur. Without this, the
/// glass cards live on a flat near-black background and the
/// blur has nothing to distort, so the cards read as opaque
/// gray rectangles with a weird highlight rather than glass.
///
/// Three pre-rendered shapes:
///   1. Top-left: a large soft accent-green glow at
///      [GlassTokens.glowOpacity]. Anchors the top of the page
///      with a subtle brand-coloured haze.
///   2. Bottom-right: a smaller soft muted-purple glow at
///      `glowOpacity * 0.7`. Adds chromatic variety so the
///      page doesn't read as "all green" — the glass cards
///      distort both shapes when they blur.
///   3. Mid-left: a small focused brand-green glow at
///      `glowOpacity * 0.6`. Sits in the negative space next
///      to the dock so the dock's glass has something to
///      reflect into the bottom of the page.
///
/// Accessibility:
///   * Honours [ReduceTransparencyScope] — when Reduce
///     Transparency is on, the glow layer is replaced with a
///     flat colour wash at the theme's `surface` token. The
///     glass cards on top still get their solid fallback; we
///     just lose the ambient colour that the [BackdropFilter]
///     was supposed to be sampling.
///   * This widget does NOT introduce animations, so
///     `MediaQuery.disableAnimations` is a no-op for it.
class GlassBackgroundGlow extends StatelessWidget {
  const GlassBackgroundGlow({super.key, this.child});

  /// Optional child to render on top of the glow. Screens that
  /// use this widget typically pass their [Scaffold] body so
  /// the body sits on top of the glow.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceTransparency = ReduceTransparencyScope.of(context);

    return Stack(
      // The glow must fill the available space (the parent
      // Scaffold's body box) and be IN THE BACKGROUND. Putting
      // it inside a `Stack` with `Positioned.fill` for the
      // background layer + the child on top means the layers
      // compose correctly without any z-fighting.
      children: [
        Positioned.fill(
          child: reduceTransparency
              // Solid wash — same dark surface as the rest of
              // the page, no glow. The glass cards above will
              // ALSO fall back to solid via ReduceTransparencyScope,
              // so the page reads as the same flat-near-black
              // surface (without the green tint) that shipped
              // before the glow layer existed.
              ? ColoredBox(color: scheme.surface)
              : const _GlowShapes(),
        ),
        ?child,
      ],
    );
  }
}

/// The three radial-gradient glow shapes. Rendered as a single
/// `CustomPaint` so the GPU composites them in one pass — the
/// shapes are static (no per-frame work) and the user can't
/// scroll the glow (it sits behind the scrollable body).
class _GlowShapes extends StatelessWidget {
  const _GlowShapes();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlowPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final opacity = GlassTokens.glowOpacity;

    // Muted complementary colour — a low-saturation lavender
    // that picks up glass cards without competing with the
    // brand green. Defined inline (not from AppColors) so it's
    // not coupled to a brand-token that might shift; this is a
    // decoration-only colour, not a brand colour.
    const mutedPurple = Color(0xFF6366F1);

    // Shape 1 — top-left, large soft accent-green.
    _paintGlow(
      canvas,
      size,
      center: Offset(size.width * 0.10, size.height * 0.12),
      radius: size.shortestSide * 0.55,
      color: AppColors.brand.withValues(alpha: opacity),
    );
    // Shape 2 — bottom-right, smaller soft muted-purple.
    _paintGlow(
      canvas,
      size,
      center: Offset(size.width * 0.95, size.height * 0.92),
      radius: size.shortestSide * 0.40,
      color: mutedPurple.withValues(alpha: opacity * 0.7),
    );
    // Shape 3 — mid-left, small focused brand-green so the
    // dock's glass has something to reflect at the bottom of
    // the page.
    _paintGlow(
      canvas,
      size,
      center: Offset(size.width * 0.05, size.height * 0.65),
      radius: size.shortestSide * 0.30,
      color: AppColors.brand.withValues(alpha: opacity * 0.6),
    );
  }

  /// Paints a single radial-gradient glow. Uses [RadialGradient]
  /// with a soft falloff (peak at 0.0 → 0 at 1.0) so the shape
  /// has no visible edge — the eye reads it as ambient light
  /// rather than a "painted circle".
  void _paintGlow(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => false;
}

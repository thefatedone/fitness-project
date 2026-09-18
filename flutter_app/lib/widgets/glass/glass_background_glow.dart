import 'dart:ui';

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
    // The top band of the screen (status-bar inset + the height
    // of the old opaque AppBar) used to be hidden behind an
    // opaque AppBar; now that `extendBodyBehindAppBar: true` on
    // the consumer Scaffold exposes the glow layer all the way
    // up to y=0, Shape 1's bright core (top-left, bright peak
    // around y = 0.12 × height) would render directly behind
    // the clock and status icons. Mask it out by passing the
    // band height down to the painter, which uses it as a
    // canvas-clip cutoff so nothing draws in the band itself.
    // Shape 2 (bottom-right) and Shape 3 (mid-left) don't reach
    // the top — confirmed by computing their bounding circles
    // — so they need no treatment.
    final topMaskHeight =
        MediaQuery.of(context).padding.top + kToolbarHeight;

    // Pre-soften the glow shapes via a one-time static blur. The
    // shapes are radial gradients, so without this filter they
    // have a (soft) hard edge where the gradient alpha hits
    // zero. A `BackdropFilter` on a `GlassCard` would normally
    // smooth that edge by sampling the blurred result — but in
    // areas where NO glass card sits on top of the glow
    // (e.g. the gap between the date-nav row and the first card
    // on the tracker home screen) the raw gradient reads as a
    // slightly hard-edged colored blob. The blur is fixed (sigma
    // 40) and static — it doesn't react to scroll position or
    // user interaction — so the GPU composites it once and we pay
    // no per-frame cost.
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: CustomPaint(
        painter: _GlowPainter(
          brightness: Theme.of(context).brightness,
          topMaskHeight: topMaskHeight,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.brightness, required this.topMaskHeight});

  /// Captured at build time so `paint` stays a single method
  /// (CustomPaint only repaints when `shouldRepaint` says so).
  final Brightness brightness;

  /// Pixel-Y cutoff below which the painter draws nothing. Set
  /// to `MediaQuery.padding.top + kToolbarHeight` by the parent
  /// so the status-bar / notch band reads as transparent.
  /// Captured at build so a screen rotation / keyboard show /
  /// foldable unfold (which changes the status-bar inset and
  /// therefore the band height) triggers a repaint via
  /// [shouldRepaint].
  final double topMaskHeight;

  @override
  void paint(Canvas canvas, Size size) {
    // Light theme: a softer, smaller glow. The dark-theme green
    // wash reads well against a near-black canvas; on a white
    // canvas the same alpha reads as a dirty patch. Halve the
    // opacity AND shrink the radii so the page background reads
    // as a clean slate with a subtle accent instead of a sea of
    // pastel blobs.
    final isDark = brightness == Brightness.dark;
    final opacityScale = isDark ? 1.0 : 0.45;
    final radiusScale = isDark ? 1.0 : 0.75;

    final baseOpacity = GlassTokens.glowOpacity * opacityScale;

    // Muted complementary colour — a low-saturation lavender
    // that picks up glass cards without competing with the
    // brand green. Defined inline (not from AppColors) so it's
    // not coupled to a brand-token that might shift; this is a
    // decoration-only colour, not a brand colour.
    const mutedPurple = Color(0xFF6366F1);

    // Mask the top band before drawing any shapes. The
    // clip-rect spans the full width × (band height → page
    // bottom), so anything whose bright core lands inside
    // y < topMaskHeight gets clipped out cleanly. The clip is
    // restored right after the shapes finish, so anything
    // outside this method is unaffected.
    //
    // `topMaskHeight` is allowed to be larger than the screen
    // height (e.g. when a parent pushes it past the page — see
    // tests on tall landscape devices): clamping the cutoff at
    // [size.height] lets the painter degrade gracefully to "no
    // shapes drawn" instead of throwing on a negative clip
    // rect.
    final clipTop = topMaskHeight.clamp(0.0, size.height);
    if (clipTop < size.height) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, clipTop, size.width, size.height));
    }

    // Shape 1 — top-left, large soft accent-green.
    // (Was previously bleeding into the status-bar band; now
    // masked out by the clip above.)
    _paintGlow(
      canvas,
      size,
      center: Offset(size.width * 0.10, size.height * 0.12),
      radius: size.shortestSide * 0.55 * radiusScale,
      color: AppColors.brand.withValues(alpha: baseOpacity),
    );
    // Shape 2 — bottom-right, smaller soft muted-purple.
    _paintGlow(
      canvas,
      size,
      center: Offset(size.width * 0.95, size.height * 0.92),
      radius: size.shortestSide * 0.40 * radiusScale,
      color: mutedPurple.withValues(alpha: baseOpacity * 0.7),
    );
    // Shape 3 — mid-left, small focused brand-green so the
    // dock's glass has something to reflect at the bottom of
    // the page.
    _paintGlow(
      canvas,
      size,
      center: Offset(size.width * 0.05, size.height * 0.65),
      radius: size.shortestSide * 0.30 * radiusScale,
      color: AppColors.brand.withValues(alpha: baseOpacity * 0.6),
    );

    if (clipTop < size.height) {
      canvas.restore();
    }
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
  bool shouldRepaint(_GlowPainter oldDelegate) {
    // The mask cutoff depends on the OS status-bar inset
    // (`MediaQuery.padding.top`). When that changes — screen
    // rotation, foldable unfold, keyboard show, dynamic island
    // resize — the parent rebuilds with a fresh `topMaskHeight`
    // and we need to repaint to pick it up. The rest of the
    // painter's inputs are captured at build and don't change
    // (the shapes are static — the previous `shouldRepaint =>
    // false` was correct for everything except the mask).
    return oldDelegate.topMaskHeight != topMaskHeight ||
        oldDelegate.brightness != brightness;
  }
}

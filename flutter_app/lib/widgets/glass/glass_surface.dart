import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/glass_tokens.dart';
import '../../utils/accessibility_utils.dart';

/// Low-level Liquid Glass surface — `BackdropFilter` blur + tint +
/// 1px border + diagonal specular highlight, all sitting on top of
/// whatever's behind the widget.
///
/// Every other glass widget in this folder is built on top of
/// [GlassSurface]; consumers rarely instantiate this directly. The
/// two entry points are:
///
///   * [GlassCard] — padded content surface.
///   * `GlassChip` — pill-shaped tag surface.
///
/// Accessibility fallback (mandatory): when iOS "Reduce
/// Transparency" is on, the `BackdropFilter` is skipped and the
/// surface renders as a fully-opaque tint of the theme's card
/// colour. We never render a half-applied blur in the fallback —
/// either the blur is on or it's off.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.surfaceClass = GlassSurfaceClass.card,
    this.borderRadius,
    this.tintOpacityOverride,
    this.enableSpecular = false,
    this.emphasized = false,
    this.padding = EdgeInsets.zero,
    this.showShadow = true,
    this.borderColorOverride,
    this.suppressBlur,
  });

  /// Content rendered inside the glass surface.
  final Widget child;

  /// Picks the blur band and corner radius from [GlassTokens] when
  /// [borderRadius] is left null.
  final GlassSurfaceClass surfaceClass;

  /// Override the corner radius. Useful for the Dock pill or for
  /// bespoke UI surfaces that don't fit the three presets.
  final BorderRadius? borderRadius;

  /// Override the neutral tint opacity (the wash on top of the
  /// blur). Use sparingly — the [emphasized] flag already covers
  /// the common "primary CTA wants more brand tint" case.
  final double? tintOpacityOverride;

  /// Toggle the upper-third diagonal specular highlight. Disable
  /// for very small chips where the highlight is more visual noise
  /// than atmosphere.
  final bool enableSpecular;

  /// When `true`, the tint picks up an extra dose of brand colour
  /// (used by primary CTAs).
  final bool emphasized;

  /// Inner padding applied to [child].
  final EdgeInsetsGeometry padding;

  /// Disable for surfaces that are already stacked on top of
  /// another opaque element (e.g. inside an opaque modal). When
  /// `false`, only the soft shadow is dropped.
  final bool showShadow;

  /// Override the gradient border colour. When non-null, the
  /// painter uses this single colour (at the standard top/bottom
  /// alpha gradient) instead of the default white/black
  /// brightness-driven choice. Use this for confidence-tinted
  /// borders on photo-recognition result cards (`brand` for high,
  /// neutral for low) — it reads as a "trust" signal at the edge
  /// without changing the surface treatment underneath.
  final Color? borderColorOverride;

  /// When non-null, the surface reads its "should I drop the blur
  /// right now?" hint from this notifier — typically wired to a
  /// scroll-velocity tracker. A `true` value forces the solid
  /// fallback path so a fast-swiping ListView doesn't drag every
  /// glass surface through a blur recompute on every frame.
  final ValueListenable<bool>? suppressBlur;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ??
        BorderRadius.circular(GlassTokens.radiusFor(surfaceClass));
    final sigma = GlassTokens.sigmaFor(surfaceClass);
    final reduceTransparency = ReduceTransparencyScope.of(context) ||
        (suppressBlur?.value ?? false);

    if (reduceTransparency) {
      // Solid fallback — same geometry / padding / radius, but no
      // blur and a flat opaque fill. The child sits directly on
      // top of the tint, so the rounded corners are preserved by
      // the Container itself (not by the BackdropFilter clip
      // ancestor that we're skipping in this branch).
      return _solidFallback(context, radius);
    }

    final tint = GlassTokens.tintColorFor(context, emphasized: emphasized);
    return RepaintBoundary(
      // The blur + custom paint live in their own layer so the
      // parent's scroll-driven repaints (e.g. the food log list)
      // don't drag the surface through a full blur recompute. The
      // boundary pays off most on scrollable surfaces where the
      // blur would otherwise be the hottest path on the GPU.
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: CustomPaint(
            painter: _GlassPainter(
              radius: radius,
              tint: tint,
              brightness: Theme.of(context).brightness,
              enableSpecular: enableSpecular,
              showShadow: showShadow,
              borderColorOverride: borderColorOverride,
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  /// Solid-surface fallback for the Reduce-Transparency case.
  /// The Dock previously inlined this exact recipe; we keep it
  /// here as a one-stop render so the geometry is byte-identical
  /// between modes.
  Widget _solidFallback(BuildContext context, BorderRadius radius) {
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.surfaceContainerHighest;
    final border = scheme.outlineVariant.withValues(alpha: 0.6);
    return RepaintBoundary(
      child: Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: border, width: GlassTokens.borderWidth),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: GlassTokens.shadowBlur,
                  offset: const Offset(0, GlassTokens.shadowOffsetY),
                ),
              ]
            : null,
      ),
      padding: padding,
      child: child,
      ),
    );
  }
}

/// Single `CustomPainter` that does everything the surface needs
/// after the `BackdropFilter` has blurred the canvas:
///
///   1. A neutral tint wash on top of the blur (without this the
///      blur alone looks like dirty glass).
///   2. A 1px border that brightens at the top and fades toward
///      the bottom, mimicking refracted light at the glass edge.
///   3. A diagonal specular highlight in the upper third using
///      `BlendMode.plus` so it brightens whatever's underneath
///      rather than replacing it. This is what makes it look like
///      glass instead of "tinted rectangle".
///   4. A soft drop shadow + a tighter edge shadow for depth.
class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.radius,
    required this.tint,
    required this.brightness,
    required this.enableSpecular,
    required this.showShadow,
    required this.borderColorOverride,
  });

  final BorderRadius radius;
  final Color tint;
  final Brightness brightness;
  final bool enableSpecular;
  final bool showShadow;
  final Color? borderColorOverride;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 1. Tint wash — uniform low-opacity fill across the whole
    //    surface. The previous design extended this as a
    //    full-height gradient which, on a flat near-black
    //    background, read as a visible top-to-bottom band. A
    //    flat fill at the new opacity (4–6% white in dark theme)
    //    is what the eye reads as "frosted glass" — the
    //    surface highlights come from the specular pass below,
    //    not from a tinted gradient.
    final tintPaint = Paint()..color = tint;
    canvas.drawRRect(rrect, tintPaint);

    if (showShadow) {
      // 2. Diffused shadow for depth — drawn around the rect's
      //    edge with a soft blur. We use a Path of the rect,
      //    expanded slightly, so the shadow sits *outside* the
      //    visible glass.
      //
      // Shadow opacity is *theme-aware*: a heavy shadow on light
      // theme makes every glass card look like it's sitting on a
      // dirty cloth — the page reads as a sea of grey halos. Light
      // theme wants a much subtler shadow so the card itself
      // (tinted slightly above the page) reads as the focal
      // element rather than its shadow. Dark theme keeps the
      // original strong shadow — the dark surface needs a clear
      // dark halo to feel like it's floating.
      final softShadowOpacity = brightness == Brightness.dark
          ? 0.12
          : 0.04;
      final edgeShadowOpacity = brightness == Brightness.dark
          ? 0.18
          : 0.06;
      _paintShadow(
        canvas,
        size,
        blur: GlassTokens.shadowBlur,
        offsetY: GlassTokens.shadowOffsetY,
        opacity: softShadowOpacity,
      );
      // 3. Tight dark edge shadow for visual "weight".
      _paintShadow(
        canvas,
        size,
        blur: GlassTokens.edgeShadowBlur,
        offsetY: GlassTokens.edgeShadowOffsetY,
        opacity: edgeShadowOpacity,
      );
    }

    // 4. Gradient border — bright at the top, fading toward the
    //    bottom.
    //
    // Border alpha is *theme-aware*: the previous fixed top/bottom
    // alphas (0.14 / 0.04) read correctly against the dark
    // surface, but on light theme the soft dark border vanishes
    // against the page. Bumping the alphas on light theme makes
    // the card edge read clearly without becoming a hard outline.
    final isDark = brightness == Brightness.dark;
    final borderTop = isDark
        ? GlassTokens.borderTopAlpha
        : GlassTokens.borderTopAlpha + 0.06;
    final borderBottom = isDark
        ? GlassTokens.borderBottomAlpha
        : GlassTokens.borderBottomAlpha + 0.04;
    final baseBorderColor = borderColorOverride ??
        (isDark ? Colors.white : Colors.black);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = GlassTokens.borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseBorderColor.withValues(alpha: borderTop),
          baseBorderColor.withValues(alpha: borderBottom),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rrect, borderPaint);

    // 5. Specular highlight — a soft, low-opacity gleam that lives
    //    ONLY in the top ~22% of the surface. The previous
    //    design drew a diagonal gradient across the full
    //    upper-third (size.height / 3) with a hard stop at
    //    0.6, which combined with the high alpha to read as a
    //    visible band where the highlight ended. The new design
    //    uses a *radial* gradient confined to a small ellipse at
    //    the top centre, with no horizontal-gradient component
    //    and a soft non-linear falloff — so the highlight
    //    dissolves into the tint wash with no visible seam.
    if (enableSpecular) {
      final streakHeight = size.height *
          GlassTokens.specularHeightFraction;
      final fadeStop = GlassTokens.specularInnerFadeStop;
      // Use a horizontal-only radial gradient: peak at the
      // top-centre, falling off to zero at the bottom of the
      // streak. There's no horizontal falloff so the highlight
      // doesn't taper at the sides — that gives a more
      // "horizontal sheen" feel, which matches the way iOS
      // renders the top edge of glass.
      //
      // CRITICAL: `RadialGradient.radius` is a FRACTION of the
      // shortest side of the paint rect, NOT an absolute pixel
      // value. The rect below is `streakHeight` tall, so an
      // absolute radius of `streakHeight * 1.4` would resolve to
      // 1.4 × (rect's shortest side, also `streakHeight`) =
      // `1.4 * streakHeight * streakHeight` in equivalent pixels
      // — dozens of times the rect itself, which is why the
      // gradient never fell off inside the streak and `drawRect`
      // hard-cut it at the bottom (the visible "lighter top,
      // darker bottom with a seam" band). The correct value is
      // a plain fraction: 1.4 means the radial falloff reaches
      // zero at 1.4 × the rect's shortest side, comfortably
      // past the rect's bottom edge so the alpha is already at
      // zero by the time `drawRect` cuts off — no seam.
      final specularPaint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.4,
          colors: [
            Colors.white.withValues(alpha: GlassTokens.specularAlpha),
            Colors.white.withValues(alpha: 0),
          ],
          stops: [0.0, fadeStop],
        ).createShader(
          Rect.fromLTWH(0, 0, size.width, streakHeight),
        );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, streakHeight),
        specularPaint,
      );
    }
  }

  /// Paints an outer shadow for the rounded rect.
  void _paintShadow(
    Canvas canvas,
    Size size, {
    required double blur,
    required double offsetY,
    required double opacity,
  }) {
    final rrect = radius.toRRect(
      Rect.fromLTWH(0, offsetY, size.width, size.height),
    );
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawRRect(rrect, shadowPaint);
  }

  @override
  bool shouldRepaint(_GlassPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.tint != tint ||
        oldDelegate.brightness != brightness ||
        oldDelegate.enableSpecular != enableSpecular ||
        oldDelegate.showShadow != showShadow ||
        oldDelegate.borderColorOverride != borderColorOverride;
  }
}
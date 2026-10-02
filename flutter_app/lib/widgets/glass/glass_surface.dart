import 'dart:ui';

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
///
/// Glass surfaces render their [BackdropFilter] at full strength
/// always. Earlier revisions crossfaded toward a solid fallback
/// during fast scrolling (driven by a `suppressBlur` notifier
/// passed by the caller), but in real use the per-frame
/// re-rasterization of the backdrop layer as the crossfade
/// progressed caused the cards to *blink* during normal scroll —
/// the cure was worse than the disease. The Liquid Glass effect
/// is now static: the [BackdropFilter] runs at the tier's
/// configured sigma at all times, and the iOS overscroll
/// indicator is suppressed (via `GlassScrollBehavior`) so the
/// blur layer doesn't get re-rasterized when the user pulls past
/// the scrollable's boundary. Together: the glass stays put,
/// looks premium, and no longer flickers as the user scrolls.
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
    this.elevation,
    this.heroShadowMultiplier = 1.6,
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

  /// Visual depth tier — drives the blur sigma, specular alpha,
  /// border alpha, and (for `hero`) the deeper shadow multiplier.
  /// When `null` the surface falls back to a tier derived from
  /// [surfaceClass] (chip → `inline`, card → `surface`,
  /// modal → `surface`) so existing call sites stay working
  /// without modification.
  final GlassElevation? elevation;

  /// Shadow multiplier applied to the soft shadow when
  /// [elevation] is [GlassElevation.hero]. 1.6 by default so the
  /// single most important element per screen visibly floats
  /// highest. Other tiers ignore it.
  final double heroShadowMultiplier;

  /// Duration of the crossfade between full glass and solid when
  /// [suppressBlur] flips. ~150 ms matches what a user perceives
  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ??
        BorderRadius.circular(GlassTokens.radiusFor(surfaceClass));
    // Resolve the effective elevation tier — explicit `elevation`
    // param when supplied, otherwise fall back to a tier derived
    // from `surfaceClass` so existing call sites (cards/modal/
    // chip) keep working without modification.
    final effectiveElevation = elevation ??
        () {
          switch (surfaceClass) {
            case GlassSurfaceClass.chip:
              return GlassElevation.inline;
            case GlassSurfaceClass.modal:
            case GlassSurfaceClass.card:
              return GlassElevation.surface;
          }
        }();
    // The system "Reduce Transparency" path is a separate concern
    // from scroll-velocity suppression — it's an a11y hard switch
    // (user disabled glass globally), and we still fall through
    // to the [_solidFallback] below without animating.
    final reduceTransparency = ReduceTransparencyScope.of(context);

    if (reduceTransparency) {
      // a11y path: skip the animation entirely.
      return _solidFallback(context, radius);
    }

    final sigmaBase = GlassTokens.sigmaFor(effectiveElevation);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tint colour comes from the tier-aware helper so the glass
    // surface picks up the right neutral/brand wash for the active
    // theme without us re-implementing the lookup here. Painter
    // doesn't need a BuildContext of its own — tint is pre-resolved
    // here and passed into the painter.
    final tint = GlassTokens.tintColorFor(
      context,
      emphasized: emphasized,
    );

    return RepaintBoundary(
      // The blur + custom paint live in their own layer so the
      // parent's scroll-driven repaints (e.g. the food log list)
      // don't drag the surface through a full blur recompute. The
      // boundary pays off most on scrollable surfaces where the
      // blur would otherwise be the hottest path on the GPU.
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          // Render the [BackdropFilter] at the tier's configured
          // sigma directly — no scroll-driven crossfade. The earlier
          // suppression animation re-rasterized the backdrop layer
          // every frame the crossfade progressed, which made the
          // cards "blink" during normal scroll. Static blur is the
          // cure; together with `GlassScrollBehavior` (which kills
          // the iOS overscroll indicator that would also redraw the
          // blur layer), the glass stays visually static.
          filter: ImageFilter.blur(sigmaX: sigmaBase, sigmaY: sigmaBase),
          child: CustomPaint(
            painter: _GlassPainter(
              radius: radius,
              tint: tint,
              brightness: isDark ? Brightness.dark : Brightness.light,
              enableSpecular: enableSpecular,
              showShadow: showShadow,
              borderColorOverride: borderColorOverride,
              // Default border colour = theme's [outlineVariant]
              // — a low-contrast outline tone that blends with the
              // page rather than reading as a hard white/black
              // line. Caller-provided [widget.borderColorOverride]
              // (e.g. brand-green for confidence borders) still
              // wins via the null-coalescing inside [_GlassPainter].
              borderBase: Theme.of(context).colorScheme.outlineVariant,
              elevation: effectiveElevation,
              heroShadowMultiplier: heroShadowMultiplier,
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

  /// Solid-surface fallback for the system a11y "Reduce
  /// Transparency" path. NOTE: this is *not* the scroll-
  /// suppression fallback — that path now runs through
  /// [_GlassPainter] with `strength == 1.0`, which produces
  /// byte-identical pixels to this method. Keeping this method
  /// here covers the a11y case (user disabled transparency
  /// globally, no animation needed) without needing a special
  /// branch in the crossfade logic.
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
///
/// Earlier revisions crossfaded the surface toward a solid fallback
/// during fast scrolling, but the per-frame re-rasterization of
/// the backdrop layer as the crossfade progressed caused the
/// glass cards to *blink* during normal scroll. The current
/// implementation paints a single static state at all times; the
/// Liquid Glass effect is locked in.
class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.radius,
    required this.tint,
    required this.brightness,
    required this.enableSpecular,
    required this.showShadow,
    required this.borderColorOverride,
    required this.borderBase,
    required this.elevation,
    required this.heroShadowMultiplier,
  });

  final BorderRadius radius;
  final Color tint;
  final Brightness brightness;
  final bool enableSpecular;
  final bool showShadow;
  final Color? borderColorOverride;

  /// Default base colour for the gradient border stroke when
  /// [borderColorOverride] is null. Resolved by the calling
  /// [GlassSurface] from `Theme.of(context).colorScheme.outlineVariant`
  /// so the surface reads as a barely-visible edge in any theme
  /// (rather than a hard white/black line that stands out against
  /// the page).
  final Color borderBase;
  final GlassElevation elevation;
  final double heroShadowMultiplier;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final isDark = brightness == Brightness.dark;

    // 1. Tint wash — uniform fill across the whole surface.
    //    The tint is the neutral/brand wash resolved by
    //    [GlassTokens.tintColorFor]; the surface is opaque-ish
    //    when alpha >= 0.5, so the underlying blur layer reads as
    //    glass rather than transparent film.
    final tintPaint = Paint()..color = tint;
    canvas.drawRRect(rrect, tintPaint);

    if (showShadow) {
      // 2. Diffused shadow for depth — drawn around the rect's
      //    edge with a soft blur. Shadow opacity is *theme-aware*:
      //    a heavy shadow on light theme makes every glass card
      //    look like it's sitting on a dirty cloth, so light theme
      //    wants a subtler shadow. Dark theme keeps the strong
      //    shadow so the dark surface still has a clear dark
      //    halo and reads as floating.
      //
      // The hero tier bumps the soft-shadow opacity by
      // `heroShadowMultiplier` so the single most important
      // element on screen visibly floats highest. Other tiers
      // skip the bump entirely.
      final baseSoft = isDark ? 0.12 : 0.04;
      final baseEdge = isDark ? 0.18 : 0.06;
      final heroBump =
          elevation == GlassElevation.hero ? heroShadowMultiplier : 1.0;
      final softShadowOpacity = baseSoft * heroBump;
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
        opacity: baseEdge,
      );
    }

    // 4. Gradient border — bright at the top, fading toward the
    //    bottom. The base colour is the theme's `outlineVariant`
    //    (low-contrast outline tone), NOT pure white/black. Earlier
    //    revisions used `Colors.white` in dark theme + `Colors.black`
    //    in light theme, which read as a visible white line against
    //    a near-black page (and an equally visible black line
    //    against a near-white page) once the glass surface sat at
    //    full blur. Switching the base to `outlineVariant` keeps
    //    the same bright-top / fading-bottom affordance (which the
    //    glass system reads as "refracted light at the edge") but
    //    blends with the page instead of standing out against it.
    // The caller can still pin a custom colour via
    // [borderColorOverride] (e.g. brand-green for confidence
    // borders on AI photo-recognition cards).
    final borderTop = GlassTokens.borderTopAlphaFor(elevation);
    final borderBottom = GlassTokens.borderBottomAlphaFor(elevation);
    // Default to the [borderBase] passed in by the surface (which
    // resolves to `Theme.of(context).colorScheme.outlineVariant`),
    // so the border blends with the page rather than standing out
    // as a hard white/black line. Callers that want a confidence
    // colour (e.g. brand-green for AI photo-recognition result
    // cards) can still pin one via [borderColorOverride].
    final baseBorderColor = borderColorOverride ?? borderBase;
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

    // 5. Specular highlight — a soft horizontal band that hugs
    //    the top edge of the surface and fades down over the
    //    top ~22% of the card. Tier-aware peak alpha; theme-
    //    aware additive colour: white in dark theme brightens
    //    the streak (light-on-glass), black in light theme
    //    darkens it (additive shadow on the white surface).
    //    `BlendMode.plus` of black on white actually deepens
    //    the surface, which reads as a soft top-edge inset
    //    rather than a hot specular dot.
    if (enableSpecular) {
      final peak = GlassTokens.specularAlphaFor(elevation);
      if (peak > 0.001) {
        final streakHeight = size.height *
            GlassTokens.specularHeightFraction;
        final fadeStop = GlassTokens.specularInnerFadeStop;
        final sheenColor = isDark ? Colors.white : Colors.black;
        final specularPaint = Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              sheenColor.withValues(alpha: peak),
              sheenColor.withValues(alpha: 0),
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
    // Compare every field the painter reads in `paint()`. No more
    // `strength` to check — the surface paints a single static
    // state now, so shouldRepaint only fires when something on
    // screen actually changed (theme switch, elevation change,
    // hover state on a chip, etc.).
    return oldDelegate.radius != radius ||
        oldDelegate.tint != tint ||
        oldDelegate.brightness != brightness ||
        oldDelegate.enableSpecular != enableSpecular ||
        oldDelegate.showShadow != showShadow ||
        oldDelegate.borderColorOverride != borderColorOverride ||
        oldDelegate.elevation != elevation ||
        oldDelegate.heroShadowMultiplier != heroShadowMultiplier;
  }
}

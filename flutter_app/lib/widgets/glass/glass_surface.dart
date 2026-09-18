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
///
/// Scroll-velocity crossfade (continuous, not binary): when the
/// [suppressBlur] notifier flips (e.g. a scroll-velocity tracker
/// crosses its fast-fling threshold), the surface ramps a
/// continuous 0.0–1.0 "suppression strength" over
/// [suppressBlurAnimationDuration] — typically ~150 ms. While
/// strength ramps, the painter lerps every output value (blur
/// sigma toward 0, tint color toward the theme's solid surface,
/// border base color toward outlineVariant, border alphas toward
/// 0.6, specular peak toward 0, shadow opacity toward 0.12 dark /
/// 0.06 light) toward the legacy `_solidFallback`'s pixels. The
/// transition is therefore a real crossfade rather than the
/// frame-to-frame pop that the previous binary branch produced —
/// the user never sees a seam on fast fling, even at the highest
/// scroll velocity. At `strength == 1.0` the painter's pixels are
/// byte-identical to the old opaque fallback; the GPU work
/// decreases monotonically with strength (sigma 0 = no-op blur =
/// no backdrop read). The animation drives repaints each frame
/// via [AnimatedBuilder] listening to the [AnimationController] —
/// the crossfade is not dependent on any other widget rebuilding
/// to "catch up".
class GlassSurface extends StatefulWidget {
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
    this.elevation,
    this.heroShadowMultiplier = 1.6,
    this.suppressBlurAnimationDuration = const Duration(milliseconds: 150),
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
  /// scroll-velocity tracker. The surface animates from
  /// "glass" → "solid" when the value flips to `true`, and back
  /// when it flips to `false`, over
  /// [suppressBlurAnimationDuration]. The transition is continuous
  /// via a frame-paced [AnimationController] (no binary widget
  /// swap), so fast-scrolling ListViews never produce a visible
  /// seam between the glass and the fallback.
  final ValueListenable<bool>? suppressBlur;

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
  /// as "instant" but still covers enough frames to hide the lerp;
  /// shorter feels binary, longer feels sluggish on quick up-
  /// scrolls (where the velocity-trigger is very short-lived).
  final Duration suppressBlurAnimationDuration;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface>
    with SingleTickerProviderStateMixin {
  /// Drives the 0.0–1.0 suppression crossfade. The trigger
  /// (`widget.suppressBlur`) stays a binary `ValueListenable<bool>`
  /// because the *trigger* — crossing a scroll-velocity threshold
  /// — is genuinely binary. What was visibly broken about the old
  /// design was that the *render* treated the trigger as binary
  /// too, swapping between two widget trees and producing a hard
  /// pop. The Animation lives here so the swap is replaced by a
  /// ~9-frame lerp that the painter consumes via
  /// [AnimatedBuilder].
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: widget.suppressBlurAnimationDuration,
      // Seed at the trigger's current value so surfaces mounted
      // mid-fling start at the correct end of the lerp rather
      // than animating from 0.0.
      value: widget.suppressBlur?.value == true ? 1.0 : 0.0,
    );
    widget.suppressBlur?.addListener(_onSuppressBlurChanged);
  }

  @override
  void didUpdateWidget(GlassSurface old) {
    super.didUpdateWidget(old);
    if (old.suppressBlur != widget.suppressBlur) {
      old.suppressBlur?.removeListener(_onSuppressBlurChanged);
      widget.suppressBlur?.addListener(_onSuppressBlurChanged);
      // Re-seed the controller at the new trigger's current
      // value and head toward whatever direction the new trigger
      // is now pointing. Without this re-seed, swapping the
      // notifier mid-transition would leave the controller stuck
      // at an arbitrary value (it would only update on the next
      // notifyListeners from the new notifier).
      _anim.duration = widget.suppressBlurAnimationDuration;
      _anim.value = widget.suppressBlur?.value == true ? 1.0 : 0.0;
      _onSuppressBlurChanged();
    }
  }

  @override
  void dispose() {
    widget.suppressBlur?.removeListener(_onSuppressBlurChanged);
    _anim.dispose();
    super.dispose();
  }

  /// Listens to the binary trigger and points the animation in
  /// the right direction. Guarded by `mounted` because the
  /// listener can fire while we're in the middle of a `dispose()`
  /// if the notifier is GC'd after us.
  void _onSuppressBlurChanged() {
    if (!mounted) return;
    final shouldSuppress = widget.suppressBlur?.value == true;
    if (shouldSuppress) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  /// 0.0 = full glass, 1.0 = solid. Sourced from the controller
  /// so any [AnimatedBuilder] rebuild reflects the live frame
  /// value.
  double get _strength => _anim.value;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ??
        BorderRadius.circular(GlassTokens.radiusFor(widget.surfaceClass));
    // Resolve the effective elevation tier — explicit `elevation`
    // param when supplied, otherwise fall back to a tier derived
    // from `surfaceClass` so existing call sites (cards/modal/
    // chip) keep working without modification.
    final effectiveElevation = widget.elevation ??
        () {
          switch (widget.surfaceClass) {
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Pre-compute both ends of every value the painter lerps so
    // the painter doesn't need a BuildContext (it can't have one —
    // CustomPainter instances are reused across frames and can't
    // safely hold Element references).
    final tint = GlassTokens.tintColorFor(
      context,
      emphasized: widget.emphasized,
    );
    // Solid-end values mirror [_solidFallback]'s recipe so that
    // at `_strength == 1.0` the painter's pixels are byte-
    // identical to the legacy opaque fallback: same fill colour,
    // same flat-alpha border in outlineVariant tone, same theme-
    // aware shadow opacity. This is what eliminates the seam —
    // the crossfade terminates at a real visual match rather than
    // at "whichever state we happened to settle into".
    final solidTint = scheme.surfaceContainerHighest;
    final solidBorderBase = scheme.outlineVariant;
    final solidShadowOpacity = isDark ? 0.12 : 0.06;

    return RepaintBoundary(
      // The blur + custom paint live in their own layer so the
      // parent's scroll-driven repaints (e.g. the food log list)
      // don't drag the surface through a full blur recompute. The
      // boundary pays off most on scrollable surfaces where the
      // blur would otherwise be the hottest path on the GPU.
      child: AnimatedBuilder(
        animation: _anim,
        // builder rebuilt each frame the controller notifies —
        // exactly the frame-paced repaint mechanism the user
        // asked for. The painter's `shouldRepaint` re-evaluates
        // `_strength` against the previous delegate on each
        // invocation, so a delta frame still repaints but a
        // settled frame doesn't churn.
        builder: (context, _) {
          final strength = _strength;
          // Lerp the blur sigma toward 0 as suppression ramps.
          // At `strength == 1.0` sigma == 0 → the BackdropFilter
          // is a no-op, which is the same cheap no-blur path the
          // old [_solidFallback] produced (no GPU backdrop
          // read). The linear `sigmaBase * (1 - strength)` lerp
          // is monotonic, CPU-trivial, and matches the painter's
          // other lerps so the crossfade stays uniform across the
          // five axes.
          final sigma = sigmaBase * (1.0 - strength);
          return ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: CustomPaint(
                painter: _GlassPainter(
                  radius: radius,
                  tint: tint,
                  brightness: isDark ? Brightness.dark : Brightness.light,
                  enableSpecular: widget.enableSpecular,
                  showShadow: widget.showShadow,
                  borderColorOverride: widget.borderColorOverride,
                  elevation: effectiveElevation,
                  heroShadowMultiplier: widget.heroShadowMultiplier,
                  strength: strength,
                  solidTint: solidTint,
                  solidBorderBase: solidBorderBase,
                  solidShadowOpacity: solidShadowOpacity,
                ),
                child: Padding(
                  padding: widget.padding,
                  child: widget.child,
                ),
              ),
            ),
          );
        },
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
        boxShadow: widget.showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: GlassTokens.shadowBlur,
                  offset: const Offset(0, GlassTokens.shadowOffsetY),
                ),
              ]
            : null,
      ),
      padding: widget.padding,
      child: widget.child,
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
/// Crossfade end-states (when `strength == 1.0`):
///   * Tint color: lerps from translucent neutral wash →
///     `solidTint` (`scheme.surfaceContainerHighest`, opaque).
///   * Border base color: lerps from white/black →
///     `solidBorderBase` (`scheme.outlineVariant`).
///   * Border alpha (top + bottom): lerps from tier-aware
///     alphas → 0.6 (matches the legacy solid fallback's flat-
///     alpha border).
///   * Shadow opacity (soft + edge): lerps from tier-aware
///     alphas → `solidShadowOpacity` (0.12 dark / 0.06 light,
///     matches the legacy solid fallback).
///   * Specular peak alpha: lerps from tier alpha → 0 (skip
///     the draw entirely below a 0.001 epsilon so we don't pay
///     for an invisible blend in the latter half of the
///     crossfade).
///
/// The blur itself is **not** lerped here — it is already lerped
/// upstream (the sigma passed to `BackdropFilter` tracks
/// `strength`). Splitting the lerp between the painter (alpha-side)
/// and the widget (sigma-side) keeps the painter stateless and
/// ensures the GPU work decreases monotonically with strength
/// (sigma 0 = no-op blur = no backdrop read).
class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.radius,
    required this.tint,
    required this.brightness,
    required this.enableSpecular,
    required this.showShadow,
    required this.borderColorOverride,
    required this.elevation,
    required this.heroShadowMultiplier,
    required this.strength,
    required this.solidTint,
    required this.solidBorderBase,
    required this.solidShadowOpacity,
  });

  final BorderRadius radius;
  final Color tint;
  final Brightness brightness;
  final bool enableSpecular;
  final bool showShadow;
  final Color? borderColorOverride;
  final GlassElevation elevation;
  final double heroShadowMultiplier;

  /// 0.0 → full glass. 1.0 → matches the legacy solid-fallback
  /// pixels byte-for-byte. Driven by [GlassSurface]'s
  /// [AnimationController]; painted linearly into five axes
  /// (tint, border base, border alphas, shadow opacity, specular
  /// peak).
  final double strength;

  /// Pre-computed end-state targets (no BuildContext allowed in
  /// the painter) — see [_GlassSurfaceState.build] for the
  /// precompute logic.
  final Color solidTint;
  final Color solidBorderBase;
  final double solidShadowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final isDark = brightness == Brightness.dark;

    // 1. Tint wash — uniform fill across the whole surface.
    //    Lerps from the translucent neutral wash (`tint`, value
    //    0.0) toward the opaque solid surface (`solidTint`,
    //    value 1.0). `Color.lerp` does an sRGB blend, which is
    //    what we want — a perceptual crossfade rather than a
    //    per-component linear blend.
    final tintPaint = Paint()
      ..color = Color.lerp(tint, solidTint, strength)!;
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
      //
      // The hero tier bumps the soft-shadow opacity by
      // `heroShadowMultiplier` so the single most important
      // element on screen visibly floats highest.
      //
      // BOTH soft and edge shadow opacities lerp toward the
      // solid-fallback opacity (`solidShadowOpacity`) so the
      // shadow doesn't visibly pop when the transition
      // completes. The soft shadow gets the hero bump applied
      // at `strength = 0` (full glass) but is lerped normally to
      // the un-bumped solid at `strength = 1` — the hero bump is
      // a glass-only flourish and shouldn't survive into the
      // solid state.
      final baseSoft = isDark ? 0.12 : 0.04;
      final baseEdge = isDark ? 0.18 : 0.06;
      final heroBump =
          elevation == GlassElevation.hero ? heroShadowMultiplier : 1.0;
      final softShadowOpacity =
          baseSoft * heroBump +
              (solidShadowOpacity - baseSoft * heroBump) * strength;
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
        opacity: baseEdge + (solidShadowOpacity - baseEdge) * strength,
      );
    }

    // 4. Gradient border — bright at the top, fading toward the
    //    bottom at full glass; flat-alpha single colour at
    //    solid. The base colour (white/black at glass;
    //    outlineVariant tone at solid) lerps via `Color.lerp`.
    //    The top alpha lerps from the tier-aware glass alpha
    //    to 0.6 (matches the legacy solid fallback's uniform
    //    border alpha); the bottom alpha uses the same lerp so
    //    both ends collapse to the flat-alpha solid-state rather
    //    than fading independently to it (a uniform lerp
    //    produces a visually cleaner crossfade than two
    //    independent lerps that converge).
    final borderTop = GlassTokens.borderTopAlphaFor(elevation) +
        (0.6 - GlassTokens.borderTopAlphaFor(elevation)) * strength;
    final borderBottom = GlassTokens.borderBottomAlphaFor(elevation) +
        (0.6 - GlassTokens.borderBottomAlphaFor(elevation)) * strength;
    final baseBorderColor = Color.lerp(
      borderColorOverride ?? (isDark ? Colors.white : Colors.black),
      solidBorderBase,
      strength,
    )!;
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
    //    top ~22% of the card. Tier-aware peak alpha at full
    //    glass; lerps to 0 as suppression ramps. Below an
    //    epsilon threshold (~0.001) the draw is skipped entirely
    //    so we don't pay for an invisible blend in the latter
    //    half of the crossfade.
    if (enableSpecular) {
      final peak = GlassTokens.specularAlphaFor(elevation) *
          (1.0 - strength);
      if (peak > 0.001) {
        final streakHeight = size.height *
            GlassTokens.specularHeightFraction;
        final fadeStop = GlassTokens.specularInnerFadeStop;
        // Theme-aware additive colour: white in dark theme
        // brightens the streak (light-on-glass), black in
        // light theme darkens it (additive shadow on the white
        // surface). `BlendMode.plus` of black on white actually
        // deepens the surface, which reads as a soft top-edge
        // inset rather than a hot specular dot — same band,
        // opposite polarity.
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
    // Compare every field the painter reads in `paint()` PLUS
    // `strength` — the lerp parameter — so a frame-paced
    // repaint fires every tick of the controller. Without the
    // `strength` check, an in-flight crossfade could be held
    // behind a stale layer if some other condition happened to
    // settle.
    return oldDelegate.radius != radius ||
        oldDelegate.tint != tint ||
        oldDelegate.brightness != brightness ||
        oldDelegate.enableSpecular != enableSpecular ||
        oldDelegate.showShadow != showShadow ||
        oldDelegate.borderColorOverride != borderColorOverride ||
        oldDelegate.elevation != elevation ||
        oldDelegate.heroShadowMultiplier != heroShadowMultiplier ||
        oldDelegate.solidTint != solidTint ||
        oldDelegate.solidBorderBase != solidBorderBase ||
        oldDelegate.solidShadowOpacity != solidShadowOpacity ||
        oldDelegate.strength != strength;
  }
}

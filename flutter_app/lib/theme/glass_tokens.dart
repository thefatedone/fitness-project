import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Centralised design tokens for the Liquid Glass system. Every
/// numeric constant that shows up across the glass widgets — blur
/// sigma, tint opacity, border alpha, shadow blur radii, spring
/// physics — lives in this one file so the visual language stays
/// consistent and re-tuning the entire system is a single-file
/// change.
///
/// Per-element sigma bands are picked for legibility, not raw
/// aesthetics:
///
///   * `cardBlurSigma`     18–24 — primary surface area. The blur is
///     what gives the card its character; lower sigma reads as
///     "tinted overlay", higher reads as "frosted".
///   * `modalBlurSigma`    28–32 — full-screen sheets and dialogs.
///     The route barrier is a big rectangular slab; you can push
///     sigma up further before the text behind it becomes a smear.
///   * `chipBlurSigma`     12–14 — small chips / badges / tags. Heavy
///     blur on a small surface makes the contained text fuzzy at
///     normal viewing distance; keep this band tight.
///
/// The tint overlay band is also asymmetric:
///
///   * Dark theme: 6–10% white. Without the white wash, dark-on-dark
///     glass looks like dirty glass rather than iOS-style glass.
///   * Light theme: 3–5% black. The wash is smaller because the
///     base layer (white surface) is already bright; over-tinting
///     collapses the contrast against light page backgrounds.
///
/// Both bands also bleed 5–8% of [AppColors.brand] so the glass
/// feels native to the brand palette instead of generic
/// glassmorphism.

/// Visual depth tier — three levels, from "most present" to
/// "most recessed". Each tier picks its own blur sigma, specular
/// alpha, border alpha, and (for `hero`) a deeper shadow so
/// cards on the same screen read as a clear hierarchy rather
/// than as competing flat rectangles. Lives at top-level (Dart
/// enums cannot be declared inside classes).
enum GlassElevation { hero, surface, inline }

class GlassTokens {
  GlassTokens._();

  // ---- Blur bands ---------------------------------------------------------

  /// Sigma used for cards / panels — the most common surface.
  static const double cardBlurSigma = 20;

  /// Sigma used for full-screen modals and sheets.
  static const double modalBlurSigma = 30;

  /// Sigma used for small elements (chips, badges). Lower because
  /// heavy blur on a small surface fuzzes the contained text.
  static const double chipBlurSigma = 14;

  /// Sigma used for the single hero element per screen (e.g. the
  /// calories ring card). The deepest blur tier — strong enough
  /// to make the surface read as clearly floating above the canvas
  /// without smearing the icon / ring content underneath.
  static const double heroBlurSigma = 25;

  // ---- Tint overlay -------------------------------------------------------

  /// Default tint opacity for dark-theme glass. Uniform
  /// 5% white wash — enough to read as glass on a flat dark
  /// background, not enough to read as a gradient band.
  /// (The previous 8% with brand bleed was reading as a harsh
  /// light→dark gradient on the cards because there was nothing
  /// behind them for the BackdropFilter to actually blur.)
  static const double darkTintOpacity = 0.05;

  /// Default tint opacity for light-theme glass. 4% black
  /// wash — light surfaces don't need much, but at 2.5% the
  /// card disappeared into the page background. 4% is enough to
  /// read as "frosted" without looking dirty.
  static const double lightTintOpacity = 0.04;

  /// Brand accent bleed ratio. Reduced from 0.07 → 0.04 —
  /// the previous value combined with the 8% tint was tinting
  /// the top half of every card visibly green. 4% × 5% = 0.2%
  /// final brand bleed, just enough to feel native without
  /// overpowering the neutral wash.
  static const double brandBleed = 0.04;

  // ---- Background glow ----------------------------------------------------

  /// Default opacity for the ambient brand-glow shapes that sit
  /// behind the glass cards. 0.10 — visible enough to give the
  /// BackdropFilter something to blur, subtle enough that the
  /// page background still reads as "dark" first, "glowing"
  /// second. Paired with the dark theme background, the glow
  /// appears as a barely-there accent that the glass distorts
  /// into the Liquid Glass character.
  static const double glowOpacity = 0.10;

  // ---- Border / lighting --------------------------------------------------

  /// Top-edge border alpha. 0.14 — enough to actually be
  /// visible against a flat background. The previous 0.55 was
  /// combining with the full-height tint gradient to read as a
  /// "card is lighter at the top, darker at the bottom" effect
  /// rather than as a 1px stroke.
  static const double borderTopAlpha = 0.14;

  /// Bottom-edge border alpha. Fades toward zero so the
  /// border doesn't read as a hard outline at the bottom.
  static const double borderBottomAlpha = 0.04;

  /// Border stroke width, in dp.
  static const double borderWidth = 1;

  /// Specular streak height as a fraction of the surface height.
  /// 0.22 — the highlight only lives in the top ~22% of the
  /// card; below that, the surface is the uniform tint wash.
  /// The falloff inside the streak is non-linear (radial), so
  /// there's no visible seam where the streak ends.
  static const double specularHeightFraction = 0.22;

  /// Inner fade inside the specular streak. 0.85 means 85% of
  /// the streak's height is the soft falloff, 15% is the
  /// near-peak. Combined with [specularHeightFraction] the
  /// streak reads as a top-of-card gleam, not a band.
  static const double specularInnerFadeStop = 0.85;

  // Tier-aware specular peak alphas. The previous single 0.06
  // was invisible; the previous 0.18 was the harsh band that read
  // as a gradient artefact. These land in the middle: hero is
  // visibly glossy, surface reads as glass without competing
  // with the page, inline is just a hint.
  static const double _specularHeroAlpha = 0.18;
  static const double _specularSurfaceAlpha = 0.10;
  static const double _specularInlineAlpha = 0.06;

  /// Specular peak alpha for a given elevation tier. Resolves to
  /// `_specularHeroAlpha` / `_specularSurfaceAlpha` /
  /// `_specularInlineAlpha` respectively. Hero gets the strongest
  /// "I'm glass" gleam; inline stays almost imperceptible.
  static double specularAlphaFor(GlassElevation elevation) {
    switch (elevation) {
      case GlassElevation.hero:
        return _specularHeroAlpha;
      case GlassElevation.surface:
        return _specularSurfaceAlpha;
      case GlassElevation.inline:
        return _specularInlineAlpha;
    }
  }

  // Tier-aware top border alphas. The previous single 0.14 was
  // hard to see at any tier; the lift here is small but visible
  // across all three tiers.
  static const double _borderHeroTopAlpha = 0.24;
  static const double _borderSurfaceTopAlpha = 0.20;
  static const double _borderInlineTopAlpha = 0.14;

  /// Top-border alpha for a given elevation tier.
  static double borderTopAlphaFor(GlassElevation elevation) {
    switch (elevation) {
      case GlassElevation.hero:
        return _borderHeroTopAlpha;
      case GlassElevation.surface:
        return _borderSurfaceTopAlpha;
      case GlassElevation.inline:
        return _borderInlineTopAlpha;
    }
  }

  // Tier-aware bottom border alphas — bottom always fades to
  // less than the top so the border doesn't read as a hard outline.
  static const double _borderHeroBottomAlpha = 0.08;
  static const double _borderSurfaceBottomAlpha = 0.06;
  static const double _borderInlineBottomAlpha = 0.04;

  /// Bottom-border alpha for a given elevation tier.
  static double borderBottomAlphaFor(GlassElevation elevation) {
    switch (elevation) {
      case GlassElevation.hero:
        return _borderHeroBottomAlpha;
      case GlassElevation.surface:
        return _borderSurfaceBottomAlpha;
      case GlassElevation.inline:
        return _borderInlineBottomAlpha;
    }
  }

  // Second specular layer — a 1-px-equivalent bright line
  // exactly along the top inner edge of the surface, blended
  // with `BlendMode.plus`. Combined with the soft diffuse
  // specular streak above, this gives the glass a refractive
  // top edge (real glass) instead of just a soft glow.
  // Tier-aware alphas; in dark theme we brighten with white, in
  // light theme we darken with black (BlendMode.plus darkens
  // a white surface — see [_GlassPainter] for the blend logic).
  static const double _edgeLineHeroAlpha = 0.32;
  static const double _edgeLineSurfaceAlpha = 0.20;
  static const double _edgeLineInlineAlpha = 0.10;

  /// Edge-line alpha for a given elevation tier.
  static double edgeLineAlphaFor(GlassElevation elevation) {
    switch (elevation) {
      case GlassElevation.hero:
        return _edgeLineHeroAlpha;
      case GlassElevation.surface:
        return _edgeLineSurfaceAlpha;
      case GlassElevation.inline:
        return _edgeLineInlineAlpha;
    }
  }

  // ---- Shadow -------------------------------------------------------------

  /// Soft, diffused "lift" shadow — the depth cue.
  static const double shadowBlur = 24;
  static const double shadowOffsetY = 8;

  /// Tight, dark edge shadow — the visual "weight" at the very
  /// bottom of the surface.
  static const double edgeShadowBlur = 4;
  static const double edgeShadowOffsetY = 2;

  // ---- Corner radii -------------------------------------------------------

  /// Default corner radius for cards / panels.
  static const double cardRadius = 24;

  /// Corner radius for the floating Dock pill (iOS / macOS dock
  /// is fully pill-shaped, not just rounded).
  static const double dockRadius = 32;

  /// Corner radius for small chips / badges.
  static const double chipRadius = 18;

  // ---- Press physics ------------------------------------------------------

  /// Target scale when a glass button / card is being pressed. iOS
  /// uses ~0.97; we match.
  static const double pressedScale = 0.97;

  /// Spring description for the press animation. Deliberately
  /// under-damped (ratio ~0.65) so the bounce feels alive — the
  /// difference between `Curves.easeOut` and a real spring is the
  /// reason we don't reuse the Dock's existing `AnimatedScale`.
  static const SpringDescription pressSpring = SpringDescription(
    mass: 1,
    stiffness: 360,
    damping: 22,
  );

  /// Spring description for the entrance animation on bottom
  /// sheets and dialogs.
  static const SpringDescription entranceSpring = SpringDescription(
    mass: 1,
    stiffness: 220,
    damping: 24,
  );

  // ---- Derived helpers ----------------------------------------------------

  /// Returns the blur sigma for a given elevation tier
  /// (preferred). Falls back to the surface-class default when
  /// no tier is supplied, so existing callers keep working.
  static double sigmaFor(
    Object tierOrClass, {
      GlassElevation? elevation,
    }) {
    if (elevation != null) {
      switch (elevation) {
        case GlassElevation.hero:
          return heroBlurSigma;
        case GlassElevation.surface:
          return cardBlurSigma;
        case GlassElevation.inline:
          return chipBlurSigma;
      }
    }
    if (tierOrClass is GlassSurfaceClass) {
      switch (tierOrClass) {
        case GlassSurfaceClass.chip:
          return chipBlurSigma;
        case GlassSurfaceClass.modal:
          return modalBlurSigma;
        case GlassSurfaceClass.card:
          return cardBlurSigma;
      }
    }
    return cardBlurSigma;
  }

  /// Returns the tint opacity for a given brightness + optional
  /// accent emphasis. `emphasized=true` (e.g. primary CTAs) bumps
  /// the tint slightly so the brand colour shows through more.
  static double tintOpacityFor(Brightness brightness, {bool emphasized = false}) {
    final base = brightness == Brightness.dark
        ? darkTintOpacity
        : lightTintOpacity;
    return emphasized ? base * 1.5 : base;
  }

  /// Returns the corner radius for a given surface class.
  static double radiusFor(GlassSurfaceClass surfaceClass) {
    switch (surfaceClass) {
      case GlassSurfaceClass.chip:
        return chipRadius;
      case GlassSurfaceClass.modal:
        return cardRadius;
      case GlassSurfaceClass.card:
        return cardRadius;
    }
  }

  /// Computes the final tint colour for a glass surface: a blend
  /// of the neutral overlay ([Colors.white] in dark theme /
  /// [Colors.black] in light theme) plus a small bleed of the
  /// brand accent.
  ///
  /// Both opacities are derived from [tintOpacityFor], the brand
  /// bleed is multiplied by `brandBleed` so it never overwhelms
  /// the neutral wash.
  static Color tintColorFor(
    BuildContext context, {
    bool emphasized = false,
  }) {
    final brightness = Theme.of(context).brightness;
    final overlay = brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    final opacity = tintOpacityFor(brightness, emphasized: emphasized);
    final neutral = overlay.withValues(alpha: opacity);

    // Brand bleed: stack the brand colour at `brandBleed * opacity`
    // over the neutral. The result is a slightly tinted-by-brand
    // overlay rather than a perfectly neutral one.
    final brand = AppColors.brand.withValues(alpha: opacity * brandBleed);
    return Color.alphaBlend(brand, neutral);
  }

  /// Computes the solid (non-glass) fallback fill used when Reduce
  /// Transparency is on. Sits one tonal step above the page
  /// background so the surface still reads as distinct from the
  /// canvas.
  static Color solidFallbackFor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.surfaceContainerHighest;
  }
}

/// Coarse classification for sigma / radius selection. Glass
/// widgets that span widely different sizes (chips vs full-screen
/// modals) ask for the class that best fits their surface area so
/// the tokens stay centralised.
enum GlassSurfaceClass { card, modal, chip }
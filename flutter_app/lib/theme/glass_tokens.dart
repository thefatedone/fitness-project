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

  /// Specular highlight peak alpha. 0.06 — the previous 0.18
  /// combined with the full-height top-to-bottom gradient made
  /// every card show a visible "lighter at the top" band. The
  /// new value is a soft gleam that the eye reads as "glass"
  /// without seeing a transition line. Confined to the top
  /// ~22% of the surface (see [_GlassPainter]).
  static const double specularAlpha = 0.06;

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

  /// Returns the blur sigma for a given surface class.
  static double sigmaFor(GlassSurfaceClass surfaceClass) {
    switch (surfaceClass) {
      case GlassSurfaceClass.chip:
        return chipBlurSigma;
      case GlassSurfaceClass.modal:
        return modalBlurSigma;
      case GlassSurfaceClass.card:
        return cardBlurSigma;
    }
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
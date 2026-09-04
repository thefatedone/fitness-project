import 'package:flutter/material.dart';

/// Exact color tokens for the NutriMind app, lifted from the web
/// app's `globals.css` so the Flutter + web clients stay visually
/// in lock-step. Every value here is a Flutter [Color] literal —
/// no [ColorScheme]-derived values, no opacity tweaks, no
/// `withOpacity` chains; the tokens are the SOURCE OF TRUTH.
///
/// Anything that needs to look "the same on both platforms" lives
/// on [AppColors] directly (the brand family). Anything that
/// depends on the active theme lives on `AppColorsDark` /
/// `AppColorsLight` (the two token sets the web `body[data-theme=…]`
/// selector swaps between).
class AppColors {
  AppColors._();

  /// Primary green — the brand "is" color used for primary CTAs
  /// and active accents. Same value in both themes.
  static const Color brand = Color(0xFF22C55E);

  /// Darker green for pressed states, dark-theme emphasis, and any
  /// surface where the bright `brand` would be too saturated.
  static const Color brandDark = Color(0xFF16A34A);

  /// Lighter green for light-theme emphasis and soft highlights
  /// (e.g. a "verified" pill on a light background).
  static const Color brandLight = Color(0xFF4ADE80);
}

/// Dark-theme tokens. Mirrors the `:root` selector in `globals.css`
/// (the web's default — the Flutter app's `mode` default is also
/// `dark` to match).
class AppColorsDark {
  AppColorsDark._();

  /// Page background. Equivalent to Tailwind's `bg-neutral-950`.
  static const Color background = Color(0xFF0A0A0A);

  /// Primary card / surface fill. Slightly lighter than
  /// `background` so cards stand out by contrast, not by shadow.
  static const Color backgroundSecondary = Color(0xFF111111);

  /// Subtle inset / nested surface (e.g. inside a card).
  static const Color backgroundTertiary = Color(0xFF0D0D0D);

  /// Primary text — off-white, not pure white, to ease eye strain.
  static const Color foreground = Color(0xFFEDEDED);

  /// Secondary text — descriptions, captions, helper copy.
  static const Color foregroundMuted = Color(0xFF6B6B6B);

  /// Placeholder / tertiary text — disabled state, hints.
  static const Color foregroundSubtle = Color(0xFF3F3F3F);

  /// Hairline border. The web defines its border via
  /// `border-neutral-900`; we set the exact same value.
  static const Color border = Color(0xFF1A1A1A);

  /// Hover/active border — slightly lighter than `border`.
  static const Color borderHover = Color(0xFF2A2A2A);

  /// Card background. Same as `backgroundSecondary` — the web
  /// uses the same value for both "card" and "secondary surface".
  static const Color card = Color(0xFF111111);
}

/// Light-theme tokens. Mirrors `body[data-theme="light"]` in
/// `globals.css` — the explicit light override the web applies when
/// the user flips the theme switch.
class AppColorsLight {
  AppColorsLight._();

  /// Page background. Slate-50 in Tailwind terms.
  static const Color background = Color(0xFFF8FAFC);

  /// Primary card / surface fill. Off-white (#FAFBFC) — one
  /// tonal step above the page so cards are visibly distinct
  /// from the canvas. The previous value (pure white) made
  /// glass surfaces disappear into the page background on
  /// light theme.
  static const Color backgroundSecondary = Color(0xFFFAFBFC);

  /// Subtle inset / nested surface (e.g. inside a card).
  static const Color backgroundTertiary = Color(0xFFF1F5F9);

  /// Primary text — slate-900, deep navy.
  static const Color foreground = Color(0xFF0F172A);

  /// Secondary text — slate-500.
  static const Color foregroundMuted = Color(0xFF64748B);

  /// Placeholder / tertiary text — slate-400.
  static const Color foregroundSubtle = Color(0xFF94A3B8);

  /// Hairline border. Slate-200.
  static const Color border = Color(0xFFE2E8F0);

  /// Hover/active border — slate-300.
  static const Color borderHover = Color(0xFFCBD5E1);

  /// Card background. Off-white (#F9FAFB) — distinct from the
  /// page background and from `backgroundSecondary`, so cards
  /// remain visibly layered.
  static const Color card = Color(0xFFF9FAFB);
}

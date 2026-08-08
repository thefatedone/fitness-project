import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 [ThemeData] builders for the two NutriMind themes.
///
/// Why the tokens are applied to a seed-derived [ColorScheme] AND
/// overridden explicitly:
///   * `ColorScheme.fromSeed(...)` does the heavy lifting: every
///     Surface / Container / onColor slot Material would otherwise
///     auto-derive from a single seed gets a sensible baseline that
///     matches the brand family. This is important for widgets we
///     haven't explicitly themed (chips, dialogs, snackbars, …).
///   * The explicit `copyWith` overrides match the web's exact
///     tokens — the seed-derived values would otherwise be slightly
///     different (Material would eagerly lift the seed into a
///     tonal palette, drifting away from the literal hex values).
///     The double-pass is what keeps the Flutter + web clients
///     visually aligned.
///
/// Corner radius is 16 everywhere — the web's card / input / button
/// all share an `rounded-2xl` (0.875 rem); we standardize on 16 px
/// for the same visual feel.
class AppTheme {
  AppTheme._();

  /// Single corner radius used across cards, inputs, and buttons.
  /// Picking one value keeps the visual language consistent — the
  /// web uses Tailwind's `rounded-2xl` (16 px) for the same set of
  /// surfaces.
  static const double _radius = 16;

  // ---- Internal builders -------------------------------------------------

  /// Shared base. Every value that's THEME-AGNOSTIC (the brand
  /// green, the brand-dark / brand-light accents) lives in
  /// [AppColors]. Both light and dark derive their primary green
  /// from this single source so a future brand tweak is a one-line
  /// change.
  static ColorScheme _baseScheme(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    );
  }

  static ThemeData _light() {
    final scheme = _baseScheme(Brightness.light).copyWith(
      // Exact web tokens — don't let Material's tonal palette drift
      // these away from the source of truth.
      primary: AppColors.brand,
      onPrimary: AppColorsLight.background,
      secondary: AppColors.brandDark,
      onSecondary: AppColorsLight.background,
      surface: AppColorsLight.background,
      onSurface: AppColorsLight.foreground,
      onSurfaceVariant: AppColorsLight.foregroundMuted,
      outline: AppColorsLight.border,
      outlineVariant: AppColorsLight.borderHover,
      surfaceContainerHighest: AppColorsLight.backgroundSecondary,
      surfaceContainerHigh: AppColorsLight.backgroundTertiary,
      error: const Color(0xFFDC2626),
    );

    return _buildTheme(
      scheme: scheme,
      brand: AppColors.brand,
      surface: AppColorsLight.background,
      surfaceSecondary: AppColorsLight.backgroundSecondary,
      surfaceTertiary: AppColorsLight.backgroundTertiary,
      card: AppColorsLight.card,
      foreground: AppColorsLight.foreground,
      foregroundMuted: AppColorsLight.foregroundMuted,
      foregroundSubtle: AppColorsLight.foregroundSubtle,
      border: AppColorsLight.border,
      borderHover: AppColorsLight.borderHover,
    );
  }

  static ThemeData _dark() {
    final scheme = _baseScheme(Brightness.dark).copyWith(
      primary: AppColors.brand,
      onPrimary: AppColorsDark.background,
      secondary: AppColors.brandDark,
      onSecondary: AppColorsDark.foreground,
      surface: AppColorsDark.background,
      onSurface: AppColorsDark.foreground,
      onSurfaceVariant: AppColorsDark.foregroundMuted,
      outline: AppColorsDark.border,
      outlineVariant: AppColorsDark.borderHover,
      surfaceContainerHighest: AppColorsDark.backgroundSecondary,
      surfaceContainerHigh: AppColorsDark.backgroundTertiary,
      error: const Color(0xFFF87171),
    );

    return _buildTheme(
      scheme: scheme,
      brand: AppColors.brand,
      surface: AppColorsDark.background,
      surfaceSecondary: AppColorsDark.backgroundSecondary,
      surfaceTertiary: AppColorsDark.backgroundTertiary,
      card: AppColorsDark.card,
      foreground: AppColorsDark.foreground,
      foregroundMuted: AppColorsDark.foregroundMuted,
      foregroundSubtle: AppColorsDark.foregroundSubtle,
      border: AppColorsDark.border,
      borderHover: AppColorsDark.borderHover,
    );
  }

  /// Shared component configuration. Both themes just pass in their
  /// token bundle; the rest (corner radius, padding, type scale,
  /// focus / hover colors) is identical.
  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color brand,
    required Color surface,
    required Color surfaceSecondary,
    required Color surfaceTertiary,
    required Color card,
    required Color foreground,
    required Color foregroundMuted,
    required Color foregroundSubtle,
    required Color border,
    required Color borderHover,
  }) {
    final textTheme = _buildTextTheme(foreground, foregroundMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      // Material 3's default scaffold background can drift from
      // `colorScheme.surface` depending on the version. Pin it
      // explicitly to our token so the AppBar / body / SafeArea
      // background all blend together.
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: foreground),
      // The web's cards have a 1px subtle border + a flat fill rather
      // than a shadow. We match that: elevation: 0 + a 1px border
      // using the theme's `border` token. Same radius (16) as inputs
      // + buttons so the visual language stays consistent.
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: surface,
        // The web sticks the AppBar to the body (no shadow seam)
        // — the same `surface` color hits both.
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surfaceSecondary,
        hintStyle: textTheme.bodyMedium?.copyWith(color: foregroundSubtle),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: _inputBorder(border, _radius),
        enabledBorder: _inputBorder(border, _radius),
        focusedBorder: _inputBorder(brand, _radius),
        errorBorder: _inputBorder(Colors.red.shade400, _radius),
        focusedErrorBorder: _inputBorder(Colors.red.shade400, _radius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: surface,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: BorderSide(color: brand),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSecondary,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        labelStyle: textTheme.bodySmall?.copyWith(
          color: foreground,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: foregroundMuted,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_radius),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: foregroundSubtle,
      ),
      snackBarTheme: SnackBarThemeData(
        // Inherit the surface variant so the snackbar blends with
        // the card / sheet surfaces. The action color is the brand
        // green so the "UNDO" / "ОК" pill on the right of the
        // snackbar is always visible.
        backgroundColor: surfaceSecondary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: foreground,
        ),
        actionTextColor: brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
    );
  }

  /// Builds the input border outline. The same shape factory is used
  /// for `border`, `enabledBorder`, etc. — only the stroke color
  /// changes between the unfocused (`border`) and focused (`brand`)
  /// states. `errorBorder` is provided separately so errored inputs
  /// look visually distinct, not just "focused in red".
  static OutlineInputBorder _inputBorder(Color color, double radius) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: 1),
    );
  }

  /// Explicit text-scale overrides so the app's type ramp is
  /// consistent regardless of which Material 3 version we're locked
  /// to. The web uses `Noto Sans` for its body text; we keep Flutter's
  /// default system font for now (no new font package) — the
  /// authority on `fontFamily` is left unchanged, only the size /
  /// weight / colour scaffolding is set here.
  static TextTheme _buildTextTheme(Color foreground, Color foregroundMuted) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: foreground,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: foreground,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: foreground,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: foreground,
        height: 1.25,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: foreground,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: foreground,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: foregroundMuted,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: foreground,
        letterSpacing: 0.2,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: foregroundMuted,
        letterSpacing: 0.2,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: foregroundMuted,
        letterSpacing: 0.2,
      ),
    );
  }

  // ---- Public API --------------------------------------------------------

  /// Material 3 light theme — matches the web's
  /// `body[data-theme="light"]` block exactly.
  static ThemeData get light => _light();

  /// Material 3 dark theme — matches the web's `:root` block
  /// exactly. This is also the default until the user explicitly
  /// switches via [ThemeProvider].
  static ThemeData get dark => _dark();
}

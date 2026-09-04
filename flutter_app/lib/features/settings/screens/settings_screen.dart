import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/api_environment_card.dart';
import '../../../widgets/glass/glass_card.dart';
import '../../../widgets/glass/glass_background_glow.dart';
import '../../../widgets/glass/glass_surface.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/screens/change_password_screen.dart';
import '../../profile/screens/delete_account_screen.dart';

/// App-level settings hub: theme switcher, account-management
/// actions (change password, delete account), a small "О приложении"
/// section, and (in debug builds only — see the "API-окружение"
/// block below) an in-app API-environment switcher that lets the
/// developer point at iOS Simulator / Android Emulator / a real
/// device on the LAN without editing `core/config/app_config.dart`
/// and rebuilding.
///
/// Profile DATA stays on the profile screen — this view is
/// deliberately about preferences + account, not editable user
/// fields.
///
/// Inherits colors / typography / card / input theming from the
/// active [ThemeProvider] via `Theme.of(context)`. No raw colors are
/// hardcoded anywhere in this file — M3 theme components configured
/// in `app_theme.dart` drive every visual.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Hardcoded for now — a real version-reading solution
  // (package_info_plus) can be plugged in later without changing the
  // UI shape. The spec explicitly says "don't add that dependency
  // now unless it's trivial".
  static const String _appVersion = '1.0.0';

  Future<void> _openChangePassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _openDeleteAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
    );
  }

  Future<void> _logout() async {
    // No confirmation dialog — logout is non-destructive (reversible
    // by simply logging back in) and the button is right next to
    // "Удалить аккаунт" (which DOES have its own three-gate
    // confirmation flow) so the visual distinction between the two
    // actions is clear.
    await context.read<AuthProvider>().logout();
  }

  void _setThemeMode(AppThemeMode mode) {
    // Fire-and-forget — the provider persists async but the in-memory
    // change (and the resulting notifyListeners) is synchronous, so
    // the UI rebuilds immediately with the new theme even if the
    // SharedPreferences write hasn't landed yet.
    context.read<ThemeProvider>().setMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // `currentMode` and `currentLocale` are read locally via
    // `Selector`s inside their respective sections, NOT
    // screen-wide via `context.watch<…>`. A screen-wide watch
    // would rebuild every `GlassCard` in the whole ListView
    // (with their own `BackdropFilter`s) on every theme /
    // locale change, which on a phone is enough blur
    // recompute to feel like a hitch. Selector keeps each
    // listening scope tight to the widget subtree that
    // actually depends on the value.

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settingsTitle)),
      body: SafeArea(
        child: GlassBackgroundGlow(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
            // ---------------------------------------------------------------
            // Section 1 — Внешний вид
            // ---------------------------------------------------------------
            _SectionLabel(AppLocalizations.of(context).settingsSectionAppearance.toUpperCase()),
            const SizedBox(height: 8),
            // Selector narrows the `ThemeProvider` watching
            // scope to JUST the theme card — only this subtree
            // rebuilds when the theme mode changes. Every other
            // section on the screen (Language, Account, About,
            // API Environment) keeps its previous build, so
            // their `BackdropFilter`s don't get needlessly
            // recomputed on a theme switch.
            Selector<ThemeProvider, AppThemeMode>(
              selector: (_, p) => p.mode,
              builder: (context, currentMode, child) {
                return GlassCard(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          l10n.settingsSectionTheme,
                          style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      // Theme switcher — custom segmented control
                      // built on a `GlassSurface` track with a sliding
                      // pill indicator behind the active segment.
                      // Material 3's `SegmentedButton` works but its
                      // built-in highlight is a flat colour; the
                      // sliding-indicator approach matches the Dock's
                      // pressed-state physics and reads as part of
                      // the Liquid Glass language.
                      SizedBox(
                        width: double.infinity,
                        child: _ThemeModeSwitcher(
                          currentMode: currentMode,
                          onChanged: _setThemeMode,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 4),
                        child: Text(
                          _themeDescription(context, currentMode),
                          style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ---------------------------------------------------------------
            // Section 1b — Язык
            // ---------------------------------------------------------------
            // Sits between the theme section and the account section
            // because both are "appearance / preference" rather than
            // account-management. The section label itself is
            // locale-aware (see [_LanguageSectionLabel] below) so
            // it tracks the user's selected language live, without
            // any restart. The three segment labels ("English",
            // "ქართული", "Русский") are intentionally the native
            // names of the languages — a non-localizable constant
            // per the spec.
            const SizedBox(height: 24),
            // The language section's `_LanguageSectionLabel` is
            // a self-contained `StatefulWidget` that reads
            // `LocaleProvider` internally — its rebuild is
            // already scoped. The picker below ALSO listens
            // tightly via a `Selector` for symmetry with the
            // theme section.
            const _LanguageSectionLabel(),
            const SizedBox(height: 8),
            Selector<LocaleProvider, AppLocale>(
              selector: (_, p) => p.locale,
              builder: (context, currentLocale, child) {
                return GlassCard(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AppLocale>(
                      segments: [
                        // Native names per the spec — these are
                        // the languages' self-names, so they live
                        // as constant native-language literals rather
                        // than going through `AppLocalizations.of(…)`.
                        // The translator never sees them translated;
                        // they are always displayed in each language's
                        // own script (English / ქართული / Русский),
                        // matching the international convention for
                        // language-picker labels.
                        //
                        // Each label is wrapped in a `FittedBox` with
                        // `BoxFit.scaleDown` so the M3 SegmentedButton
                        // — which is a fixed-height widget — doesn't
                        // wrap the label to a second line on narrow
                        // phones (e.g. "ქართული" at 14pt doesn't
                        // fit in a ~110dp segment on a 360dp screen
                        // without shrinking slightly).
                        ButtonSegment(
                          value: AppLocale.en,
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('English', maxLines: 1),
                          ),
                        ),
                        ButtonSegment(
                          value: AppLocale.ka,
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(l10n.languageGeorgian, maxLines: 1),
                          ),
                        ),
                        ButtonSegment(
                          value: AppLocale.ru,
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(l10n.languageRussian, maxLines: 1),
                          ),
                        ),
                      ],
                      selected: {currentLocale},
                      onSelectionChanged: (selection) {
                        // SegmentedButton fires with an empty set
                        // when the user taps the already-selected
                        // segment (no-op per Flutter contract);
                        // guard so we don't write the same value
                        // back and trigger an unnecessary
                        // notifyListeners.
                        if (selection.isEmpty) return;
                        context
                            .read<LocaleProvider>()
                            .setLocale(selection.first);
                      },
                    ),
                  ),
                );
              },
            ),

            // ---------------------------------------------------------------
            // Section 2 — Аккаунт
            // ---------------------------------------------------------------
            const SizedBox(height: 24),
            _SectionLabel(AppLocalizations.of(context).settingsSectionAccount.toUpperCase()),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _SettingsListTile(
                    icon: Icons.lock_outline,
                    title: l10n.settingsChangePassword,
                    onTap: _openChangePassword,
                  ),
                  const _Divider(),
                  _SettingsListTile(
                    icon: Icons.delete_forever,
                    title: l10n.settingsDeleteAccount,
                    iconColor: theme.colorScheme.error,
                    titleColor: theme.colorScheme.error,
                    onTap: _openDeleteAccount,
                  ),
                ],
              ),
            ),

            // ---------------------------------------------------------------
            // Section 3 — О приложении
            // ---------------------------------------------------------------
            const SizedBox(height: 24),
            _SectionLabel(AppLocalizations.of(context).settingsSectionAbout.toUpperCase()),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(l10n.settingsVersion),
                trailing: Text(
                  _appVersion,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // ---------------------------------------------------------------
            // Section 4 — API-окружение (ТОЛЬКО ДЛЯ РАЗРАБОТКИ)
            // ---------------------------------------------------------------
            //
            // Entirely behind `kDebugMode` so this card never appears
            // in a release build. The actual UI (presets, custom URL,
            // reset button, post-change SnackBar) lives in
            // `lib/shared/widgets/api_environment_card.dart` so the
            // same control is also reachable from the Login screen
            // (where it's opened via a modal bottom sheet) without
            // duplicating ~200 lines of widget code.
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              _SectionLabel(AppLocalizations.of(context).settingsSectionApiEnvironmentDebug),
              const SizedBox(height: 8),
              const ApiEnvironmentCard(),
            ],

            // ---------------------------------------------------------------
            // Section 5 — Выйти
            // ---------------------------------------------------------------
            // Visually separated from the sections above with a larger
            // gap so the destructive action reads as its own group
            // (the web-settings convention). The action is non-
            // destructive (reversible by logging back in) so no
            // confirmation dialog — unlike the "Удалить аккаунт" entry
            // above which has its own multi-gate confirmation.
            const SizedBox(height: 32),
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(16),
              child: _SettingsListTile(
                icon: Icons.logout,
                title: l10n.settingsLogout,
                iconColor: theme.colorScheme.error,
                titleColor: theme.colorScheme.error,
                onTap: _logout,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Short human-readable description of the currently-active theme
  /// mode. Shown below the `SegmentedButton` so the user has a hint
  /// about what "system" actually means. Takes the localizations
  /// delegate so it can render the description text in the active
  /// language — the descriptions aren't mere string lookups (they
  /// differ per theme mode), so a static `String` getter won't do.
  static String _themeDescription(BuildContext context, AppThemeMode mode) {
    final l10n = AppLocalizations.of(context);
    switch (mode) {
      case AppThemeMode.light:
        return l10n.themeDescriptionLight;
      case AppThemeMode.dark:
        return l10n.themeDescriptionDark;
      case AppThemeMode.system:
        return l10n.themeDescriptionSystem;
    }
  }
}

/// Locale-aware variant of [_SectionLabel] for the Language section.
///
/// The body of this app is still Russian-only (the existing screens
/// have hardcoded Russian strings; a full i18n refactor is out of
/// scope per the "do not modify unrelated functionality" guard).
/// The Language section's label is the *only* string that tracks
/// the user's locale live — derived from
/// [Localizations.localeOf] so it changes the moment the user taps
/// a new segment on the [SegmentedButton] below, with no restart.
///
/// We use each language's native word for "language" (ЯЗЫК /
/// LANGUAGE / ენა) rather than translating a Russian source —
/// that's the convention every language switcher in the wild
/// follows, and it sidesteps the question of which language's
/// word should be the canonical one.
class _LanguageSectionLabel extends StatelessWidget {
  const _LanguageSectionLabel();

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final label = switch (code) {
      'ru' => 'ЯЗЫК',
      'ka' => 'ენა',
      _ => 'LANGUAGE',
    };
    return _SectionLabel(label);
  }
}

/// Small uppercase label above each section's card. Matches the
/// `textTheme.labelSmall` style — small, letterspaced, muted — for
/// the same "kicker" feel common settings screens use.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Thin divider used between two `_SettingsListTile`s inside the same
/// card. Inset slightly so the divider line doesn't visually touch
/// the card's border.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

/// A themed ListTile used by the account / logout cards. Wraps
/// [ListTile] so the same padding / radius / icon treatment matches
/// the rest of the app's settings-list convention.
class _SettingsListTile extends StatelessWidget {
  const _SettingsListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: titleColor ?? theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 4,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme switcher (segmented control with sliding indicator on GlassSurface)
// ---------------------------------------------------------------------------

/// Three-segment theme switcher (light / dark / system). Renders on
/// a [GlassSurface] track and animates a sliding-pill indicator
/// behind the active segment as the user taps between modes.
///
/// The visual model mirrors iOS's theme picker: a soft highlight
/// rides behind whichever segment is currently selected, sliding
/// to the new segment on tap. The pill's colour uses the theme's
/// primary so the active mode reads as the same accent as the rest
/// of the app's CTAs.
class _ThemeModeSwitcher extends StatefulWidget {
  const _ThemeModeSwitcher({
    required this.currentMode,
    required this.onChanged,
  });

  final AppThemeMode currentMode;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  State<_ThemeModeSwitcher> createState() => _ThemeModeSwitcherState();
}

class _ThemeModeSwitcherState extends State<_ThemeModeSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Index of the segment that the indicator is currently
  /// animating TO. We capture both the start and target so the
  /// pill slides smoothly between them rather than snapping.
  int _fromIndex = 0;
  int _toIndex = 0;

  /// Width of one segment, computed via [LayoutBuilder] in
  /// [build]. Stored as a field so the animation listener can
  /// keep tracking the target.
  double _segmentWidth = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _toIndex = _segmentIndex(widget.currentMode);
    _fromIndex = _toIndex;
  }

  @override
  void didUpdateWidget(covariant _ThemeModeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMode != widget.currentMode) {
      _fromIndex = _toIndex;
      _toIndex = _segmentIndex(widget.currentMode);
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Three-segment lookup — order matches the visible segments
  /// (light / dark / system).
  int _segmentIndex(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 0;
      case AppThemeMode.dark:
        return 1;
      case AppThemeMode.system:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / 3;
        // Cache the segment width so the animation listener
        // can read it without rebuilding the whole tree.
        if (_segmentWidth != segmentWidth) {
          _segmentWidth = segmentWidth;
        }

        return GlassSurface(
          // Built ONCE (the LayoutBuilder only re-runs this
          // outer builder when the parent constraints change,
          // e.g. on a window resize). The `BackdropFilter` in
          // here blurs the page background once per layout pass,
          // not per animation frame. The animated parts (the
          // sliding pill + the per-segment highlight colour
          // tracking the pill) live inside the inner
          // `AnimatedBuilder`, which is what re-runs on every
          // animation tick.
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.all(4),
          // Slight surface tint to differentiate the track
          // from the parent (otherwise the segmented control
          // looks like it's floating without a container).
          emphasized: true,
          child: SizedBox(
            height: 44,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_ctrl.value);
                // The pill's left edge animates from `_fromIndex`'s
                // segment to `_toIndex`'s segment.
                final pillLeft =
                    (_fromIndex + (_toIndex - _fromIndex) * t) *
                        segmentWidth;
                return Stack(
                  children: [
                    // Sliding pill indicator — sits BEHIND the
                    // segment buttons via the Stack order. The
                    // colour matches the theme's primary so the
                    // active mode reads as the same accent the
                    // user sees on every CTA.
                    Positioned(
                      left: pillLeft + 2,
                      top: 2,
                      bottom: 2,
                      width: segmentWidth - 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _segment(
                          theme,
                          l10n.themeLight,
                          Icons.light_mode_outlined,
                          AppThemeMode.light,
                          pillLeft,
                          segmentWidth,
                        ),
                        _segment(
                          theme,
                          l10n.themeDark,
                          Icons.dark_mode_outlined,
                          AppThemeMode.dark,
                          pillLeft,
                          segmentWidth,
                        ),
                        _segment(
                          theme,
                          l10n.themeSystem,
                          Icons.brightness_auto_outlined,
                          AppThemeMode.system,
                          pillLeft,
                          segmentWidth,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _segment(
    ThemeData theme,
    String label,
    IconData icon,
    AppThemeMode value,
    double pillLeft,
    double segmentWidth,
  ) {
    // Highlight the segment if the indicator is currently
    // sitting on top of it (or settling onto it). We use the
    // animation value so the colour tracks the sliding pill,
    // not the discrete index — the leading edge of the pill
    // catches the destination segment before the trailing
    // edge leaves the source.
    final t = Curves.easeOutCubic.transform(_ctrl.value);
    final pillCenter = (_fromIndex + (_toIndex - _fromIndex) * t) *
            segmentWidth +
        segmentWidth / 2;
    final myCenter = _segmentIndex(value) * segmentWidth +
        segmentWidth / 2;
    final dist = (pillCenter - myCenter).abs();
    final active = dist < segmentWidth / 2;
    return Expanded(
      child: DecoratedBox(
        // Soft border on UNSELECTED segments so they read as
        // distinct tappable regions, not empty space. The active
        // segment doesn't draw a border — the sliding-pill
        // indicator behind it is already a strong visual cue, and
        // a second border on top would muddy the active state.
        // Uses the same top→bottom alpha fade as the global
        // [GlassTokens] border so the segments feel like a
        // continuation of the surrounding glass surface.
        decoration: active
            ? const BoxDecoration()
            : BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: InkResponse(
            onTap: () {
              // Selection tick (not confirmation haptic) — the
              // theme switcher is a state selector, and `selectionClick`
              // is the iOS-picker tick that signals "this option
              // became active". `lightImpact` would over-cue the action.
              HapticFeedback.selectionClick();
              widget.onChanged(value);
            },
            radius: 14,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: theme.textTheme.labelMedium!.copyWith(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                // The segment's width is fixed at
                // `constraints.maxWidth / 3` (one third of the
                // track), which on narrow phones leaves very
                // little room for the label — especially for the
                // longer Georgian translations like
                // "სისტემმური" (System). Without this FittedBox
                // the text would wrap to a second line and break
                // the segment's fixed 44px height. `scaleDown`
                // shrinks the text to fit, never enlarges it.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(label, maxLines: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

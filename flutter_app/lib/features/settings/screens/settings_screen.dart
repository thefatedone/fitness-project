import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/api_environment_card.dart';
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
    final themeProvider = context.watch<ThemeProvider>();
    final currentMode = themeProvider.mode;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ---------------------------------------------------------------
            // Section 1 — Внешний вид
            // ---------------------------------------------------------------
            const _SectionLabel('ВНЕШНИЙ ВИД'),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Тема оформления',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    // SegmentedButton<AppThemeMode> is the right M3
                    // pattern for a small live switch like this:
                    //   * 3 options fit a single row
                    //   * the selected segment is visually obvious
                    //   * Material 3 wraps the highlight in a colored
                    //     pill so the active mode is unmissable
                    // Three `RadioListTile` rows would take a lot more
                    // vertical space and read as a list, not a switch.
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AppThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: AppThemeMode.light,
                            label: Text('Светлая'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: AppThemeMode.dark,
                            label: Text('Тёмная'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                          ButtonSegment(
                            value: AppThemeMode.system,
                            label: Text('Системная'),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                        ],
                        selected: {currentMode},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) return;
                          _setThemeMode(selection.first);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 4),
                      child: Text(
                        _themeDescription(currentMode),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---------------------------------------------------------------
            // Section 2 — Аккаунт
            // ---------------------------------------------------------------
            const SizedBox(height: 24),
            const _SectionLabel('АККАУНТ'),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outline),
              ),
              child: Column(
                children: [
                  _SettingsListTile(
                    icon: Icons.lock_outline,
                    title: 'Сменить пароль',
                    onTap: _openChangePassword,
                  ),
                  const _Divider(),
                  _SettingsListTile(
                    icon: Icons.delete_forever,
                    title: 'Удалить аккаунт',
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
            const _SectionLabel('О ПРИЛОЖЕНИИ'),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outline),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: const Text('Версия'),
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
              const _SectionLabel('API-ОКРУЖЕНИЕ (ТОЛЬКО ДЛЯ РАЗРАБОТКИ)'),
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
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outline),
              ),
              child: _SettingsListTile(
                icon: Icons.logout,
                title: 'Выйти из аккаунта',
                iconColor: theme.colorScheme.error,
                titleColor: theme.colorScheme.error,
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Short human-readable description of the currently-active theme
  /// mode. Shown below the `SegmentedButton` so the user has a hint
  /// about what "системная" actually means.
  static String _themeDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Всегда светлая тема оформления.';
      case AppThemeMode.dark:
        return 'Всегда тёмная тема оформления.';
      case AppThemeMode.system:
        return 'Тема оформления следует за настройкой системы.';
    }
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/api_environment_provider.dart';
import '../../l10n/gen/app_localizations.dart';

/// Debug-only card that shows the *currently effective* API base URL
/// and lets the developer switch the `Dio` client between presets
/// (iOS Simulator, Android Emulator) or a custom URL without
/// editing `core/config/app_config.dart` and rebuilding.
///
/// Why a shared, public widget: the same UI is reachable from
/// **two** debug-only entry points — the Settings screen (after
/// authentication) and the Login screen (before authentication, so
/// a fresh install on a real device with an incorrect default URL
/// can still be configured before the user can ever log in).
/// Keeping one implementation of the card (rather than duplicating
/// the form + presets + reset button in each screen) means both
/// entry points always behave identically when the network shape
/// or the presets themselves change.
///
/// The widget reads [ApiEnvironmentProvider] via `context.watch`
/// (so the "Current URL" line stays live — tapping a preset
/// updates the display in the same frame `setOverride` notifies)
/// and writes via `context.read` for the same reason.
///
/// Debug-only by convention: this class does NOT internally check
/// `kDebugMode`. Callers MUST wrap the rendered widget in
/// `if (kDebugMode) ...[ ... ]`. The two existing call sites
/// (Settings, Login) both do; a third caller that forgets would
/// leak a developer-facing control into a release build. The
/// `useAsModalBottomSheet` helper and the raw constructor are
/// equally guarded by this convention — no defensive assert
/// inside the widget itself, because defensive asserts in widgets
/// are worse than the leak: they'd crash a release build rather
/// than merely render a tab the user can ignore.
class ApiEnvironmentCard extends StatefulWidget {
  const ApiEnvironmentCard({super.key});

  /// Opens the card inside a draggable modal bottom sheet. The
  /// intended entry point for screens that don't already have a
  /// "card inside a scrollable list" parent (e.g. the Login
  /// screen) — a modal is the lightest-weight way to expose the
  /// same UI without rebuilding the host screen's layout.
  ///
  /// Keyboard handling: `viewInsets.bottom` is added to the sheet's
  /// bottom padding so the URL `TextFormField` stays visible when
  /// the keyboard pops up. Without this the bottom of the form
  /// would be obscured and the user couldn't see the validation
  /// error if they typed something invalid.
  ///
  /// SnackBar scoping — this is the subtle bit. The card's
  /// `_apply` method calls `ScaffoldMessenger.of(context)` to
  /// schedule its confirmation SnackBar. When the card is rendered
  /// *inline* inside a Scaffold (the Settings screen), that lookup
  /// walks up to the MaterialApp's ScaffoldMessenger and the
  /// SnackBar renders at the bottom of the SettingsScreen — fine.
  ///
  /// When the card is rendered *inside this modal bottom sheet*,
  /// though, the lookup walks up through the modal route →
  /// Overlay → Navigator → MaterialApp, where it finds the
  /// ScaffoldMessenger that the underlying screen (LoginScreen)
  /// registered itself with. That Scaffold is now visually covered
  /// by the modal sheet itself, so any SnackBar attached to it
  /// fires "successfully" but is invisible — the user taps
  /// "Apply", nothing happens on screen, and they think the
  /// change didn't land.
  ///
  /// The fix is to wrap the builder's content in
  /// `ScaffoldMessenger(child: Scaffold(...))`:
  ///
  ///   * `ScaffoldMessenger` introduces a new
  ///     `_ScaffoldMessengerScope` InheritedWidget, so any
  ///     `ScaffoldMessenger.of(context)` call from below resolves
  ///     to *this* state instead of the MaterialApp's.
  ///   * `Scaffold(backgroundColor: Colors.transparent, ...)` is
  ///     the host the SnackBars attach to — `transparent` so the
  ///     modal sheet's own rounded-rectangle background shows
  ///     through unchanged.
  ///   * `resizeToAvoidBottomInset: false` prevents double-counting
  ///     the keyboard inset: the Scaffold doesn't try to resize
  ///     its body, and we already handle the inset manually via
  ///     `MediaQuery.of(ctx).viewInsets.bottom` below.
  ///
  /// Inline usage (Settings) is unaffected: nothing in this
  /// helper runs when the card is constructed directly. The
  /// Settings-screen Scaffold still owns its own ScaffoldMessenger
  /// and the SnackBar renders at the bottom of the SettingsScreen
  /// exactly as before.
  static Future<void> showAsModalBottomSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: const ApiEnvironmentCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<ApiEnvironmentCard> createState() => _ApiEnvironmentCardState();
}

class _ApiEnvironmentCardState extends State<ApiEnvironmentCard> {
  // Preset URLs. These deliberately do NOT include the `/api/v1`
  // suffix — `AppConfig.apiBaseUrl` auto-appends it when missing
  // (see that file for the rationale).
  static const String _iOSSimulatorUrl = 'http://localhost:8000';
  static const String _androidEmulatorUrl = 'http://10.0.2.2:8000';

  final _formKey = GlobalKey<FormState>();
  final _customUrlCtrl = TextEditingController();

  @override
  void dispose() {
    _customUrlCtrl.dispose();
    super.dispose();
  }

  /// Shared apply path: pulls the [ApiEnvironmentProvider], records
  /// the URL *before* the change, calls `setOverride`, then shows a
  /// confirming SnackBar IF the effective URL actually changed.
  ///
  /// [url] semantics — `null` means "clear override / reset to
  /// default". A non-null value is what was typed (or a preset).
  /// For the custom-URL path, [_applyCustom] pre-validates via the
  /// form key first; for the preset + reset paths, validation is a
  /// no-op.
  ///
  /// ScaffoldMessenger scoping: `ScaffoldMessenger.of(context)` is
  /// resolved against whatever ScaffoldMessenger is the nearest
  /// ancestor of [context] at call time. When the card is rendered
  /// inline (Settings), that's the MaterialApp's scope and the
  /// SnackBar renders at the bottom of the SettingsScreen. When
  /// the card is rendered inside [showAsModalBottomSheet], the
  /// helper has wrapped the sheet's content in a sheet-local
  /// ScaffoldMessenger, so [context] resolves to *that* scope and
  /// the SnackBar renders at the bottom of the modal sheet — i.e.
  /// visibly, on top of the sheet's background.
  Future<void> _apply(String? url) async {
    final l10n = AppLocalizations.of(context);
    final provider = context.read<ApiEnvironmentProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final before = provider.effectiveUrl;

    await provider.setOverride(url);

    if (!mounted) return;
    final after = provider.effectiveUrl;
    if (after == before) {
      // setOverride rejected the input (no http(s) prefix, etc.) —
      // the form validator already showed a field-level error in
      // the custom-URL path, and the preset buttons are known-good,
      // so this branch is defensive: bail silently rather than
      // showing a misleading "URL установлен" toast.
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          // 5 s instead of the default ~4 s: this SnackBar carries
          // a two-line message (URL confirmation + "pull to
          // refresh" caveat), which is meaningfully longer than
          // the app's other one-liners and gives the user time to
          // read both lines.
          duration: const Duration(seconds: 5),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.apiEnvCardBaseUrlApplied(after),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.apiEnvCardBaseUrlAppliedBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _applyCustom() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    await _apply(_customUrlCtrl.text);
  }

  Future<void> _reset() async {
    _customUrlCtrl.clear();
    await _apply(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Watching instead of reading so the "Current URL" line stays
    // live — every `setOverride` triggers a `notifyListeners`, which
    // rebuilds this whole card, which re-reads `effectiveUrl`.
    final provider = context.watch<ApiEnvironmentProvider>();
    final effectiveUrl = provider.effectiveUrl;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Effective URL — read-only informational row. The URL
            // itself is shown in a slightly tighter font with
            // break-anywhere so a long real-device URL doesn't
            // overflow the card on small screens.
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                l10n.apiEnvCardCurrentUrl,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: SelectableText(
                effectiveUrl,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                l10n.apiEnvCardPresets,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Preset chips — `Wrap` rather than `Row` so the
            // chips can flow to a second row on narrow screens
            // instead of clipping off the side.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.laptop_mac, size: 18),
                  label: Text(l10n.apiEnvCardPresetIos),
                  onPressed: () => _apply(_iOSSimulatorUrl),
                ),
                ActionChip(
                  avatar: const Icon(Icons.android, size: 18),
                  label: Text(l10n.apiEnvCardPresetAndroid),
                  onPressed: () => _apply(_androidEmulatorUrl),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                l10n.apiEnvCardCustomUrl,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _customUrlCtrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    // `enableSuggestions: false` keeps iOS from
                    // auto-prefixing "http" suggestions under the
                    // field — those UI affordances would compete
                    // with the field's own validation error for
                    // the same real estate.
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: l10n.apiEnvCardBaseUrlField,
                      hintText: 'http://192.168.1.23:8000',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    // Validator mirrors the validation in
                    // `ApiEnvironmentProvider.setOverride` — the
                    // client-side check here gives the user a
                    // visible error message under the field, while
                    // the provider check is the safety net for any
                    // call site that doesn't pre-validate.
                    validator: (v) {
                      final raw = (v ?? '').trim();
                      if (raw.isEmpty) return l10n.apiEnvCardBaseUrlRequired;
                      if (!raw.startsWith('http://') &&
                          !raw.startsWith('https://')) {
                        return l10n.apiEnvCardBaseUrlInvalid;
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _applyCustom(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _applyCustom,
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(l10n.apiEnvCardApply),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: Text(l10n.apiEnvCardReset),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

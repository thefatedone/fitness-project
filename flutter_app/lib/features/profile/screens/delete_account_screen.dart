import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/providers/auth_api.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/account_api.dart';

/// Two-stage, three-gate account-deletion confirmation.
///
/// Destructive and irreversible — the user has to (1) check an
/// "I understand" acknowledgement, (2) type their current password,
/// and (3) confirm a final native AlertDialog before the network
/// request fires. This is intentional friction: deletion must never
/// be one accidental tap away.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();

  /// Stage-1 / gate-1: the acknowledgement checkbox. Until the user
  /// has read the warning and ticked this, the destructive button stays
  /// disabled.
  bool _acknowledged = false;

  /// Network-call state. Local one-shot state — a Provider is
  /// overkill for a single screen / single action.
  bool _isDeleting = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deleteAccountTitle),
        // Subtle visual cue: light red tint so the AppBar reads as a
        // "danger zone" without screaming. Keeps the rest of the
        // appbar chrome (icons, text) legible.
        backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stage 1 — warning + acknowledgement.
                    _WarningCard(theme: theme),
                    const SizedBox(height: 24),
                    FormField<bool>(
                      initialValue: _acknowledged,
                      validator: (v) =>
                          v == true ? null : l10n.deleteAccountAcknowledgeRequired,
                      builder: (state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            value: _acknowledged,
                            onChanged: (v) => setState(
                              () => _acknowledged = v ?? false,
                            ),
                            // The error message is rendered in the
                            // wrapping FormField so it can be
                            // discoverable by the form's validate()
                            // call below (this is also the third
                            // gate — without this acknowledgement,
                            // the destructive button stays disabled).
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.deleteAccountAcknowledge),
                          ),
                          if (state.hasError)
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 16, top: 4),
                              child: Text(
                                state.errorText!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      // The password field is always visible (rather
                      // than gated by the checkbox) so the layout
                      // doesn't jump when the user checks the box —
                      // just disabled until they tick the
                      // acknowledgement. Spec leaves the choice open
                      // and this is the simpler implementation.
                      enabled: _acknowledged,
                      decoration: InputDecoration(
                        labelText: l10n.deleteAccountCurrentPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        helperText: _acknowledged
                            ? l10n.deleteAccountHelperAfterAck
                            : l10n.deleteAccountHelperBeforeAck,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l10n.deleteAccountCurrentPasswordRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _acknowledged && !_isDeleting
                          ? _onConfirmPressed
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.deleteAccountConfirmButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- submit --------------------------------------------------------------

  /// Stage-2 confirmation: native AlertDialog that asks the user one
  /// more time, with the destructive option red-styled. This is the
  /// "last warning" the spec called for. If they confirm, we call
  /// the API; if they cancel, nothing happens.
  Future<void> _onConfirmPressed() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountDialogTitle),
        content: Text(l10n.deleteAccountDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(l10n.commonYesDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    await _doDelete();
  }

  Future<void> _doDelete() async {
    setState(() => _isDeleting = true);

    final api = AccountApi();
    try {
      final msg = await api.deleteAccount(password: _passwordCtrl.text);
      if (!mounted) return;

      // (1) Show the success SnackBar BEFORE we tear down the route,
      // so the user sees the confirmation in the same context where
      // they took the action. Short delay so it has a chance to
      // render before the route unmounts.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      // (2) Wipe the stored token + flip auth state to
      // unauthenticated. `AuthProvider.logout()` already does both
      // (it calls `tokenStorage.deleteToken()` and resets the
      // internal `currentUser` + `status`). Once status flips,
      // `AuthGate`'s exhaustive switch swaps to `LoginScreen`.
      final auth = context.read<AuthProvider>();
      await auth.logout();
      if (!mounted) return;

      // (3) This screen was reached via `Navigator.push()` from
      // deep within the profile section. `logout()` alone resets
      // the auth state but doesn't pop this route off the stack —
      // the user would land on a now-meaningless "delete account"
      // screen with an unauthenticated state. We pop everything
      // down to the base route so AuthGate's post-logout rebuild
      // becomes visible. Same fix as `onboarding_wizard_screen.dart`.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      // Wrong-password is the most likely case here (and the only
      // error path the backend has for this route); surface the
      // message verbatim. User stays on the screen so they can
      // re-enter a different password.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.commonErrorWithRetry),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

// ============================================================================
// Warning card
// ============================================================================

/// Big "this is destructive" banner. Same visual language as the
/// amber allergy card in profile_screen.dart, but the icon and
/// accent swap to the theme's `error` color so the seriousness
/// reads as "danger" rather than "heads-up".
class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        // Slightly stronger than the amber allergy card: a thin
        // error-tinted border on top of the errorContainer fill, so
        // it's clearly the highest-severity surface in the app.
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.6),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.dangerous_outlined,
            color: theme.colorScheme.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deleteAccountWarningTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.deleteAccountWarningBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

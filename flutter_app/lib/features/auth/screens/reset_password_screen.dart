import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../widgets/glass/glass_button.dart';
import '../../../widgets/glass/glass_card.dart';

import '../../auth/providers/auth_api.dart';
import '../providers/password_reset_provider.dart';

/// Step 3 of the password-reset flow.
///
/// User types a new password + confirmation. The backend re-verifies
/// the code (independent of the verify step) and validates the new
/// password's strength using the same rules as registration and
/// `PUT /users/me/password`. On success, the user is back at the
/// login screen and can sign in.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final reset = context.read<PasswordResetProvider>();
    final ok = await reset.resetPassword(_newCtrl.text);
    if (!mounted) return;

    if (ok) {
      // Order matters: the SnackBar needs an alive ScaffoldMessenger,
      // so we show the message FIRST, then clear the provider's
      // email/code (so a future reset attempt starts fresh), then
      // pop the whole flow back to LoginScreen. The
      // popUntil((r) => r.isFirst) mirrors the same fix used in
      // onboarding_wizard_screen.dart and delete_account_screen.dart
      // — this screen is deep in a pushed stack above LoginScreen
      // and the user lands on LoginScreen after the pop.
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.authResetSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      reset.reset(); // clears email / code / errorMessage
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      // Failure paths here:
      //  * the code expired between step 2 and step 3 → the
      //    backend's 400 surfaces the generic "invalid or
      //    expired code" message; the user can back-button to
      //    step 2 and re-trigger the resend from there.
      //  * the password was weak in some way the client validator
      //    missed → the backend's strength copy is in the message.
      // Either way, show the message verbatim and stay on this
      // screen so the user can retry without losing their typed
      // values.
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(reset.errorMessage ?? l10n.commonErrorShort),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reset = context.watch<PasswordResetProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authResetTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                borderRadius: BorderRadius.circular(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.authResetInstructions(reset.email),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _newCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.authResetNewPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          helperText: l10n.authPasswordHelper,
                        ),
                        // Same shared helper as registration /
                        // change-password — single source of truth for
                        // the rules on both client and server.
                        validator: (v) => validatePassword(v ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _onSubmit(),
                        decoration: InputDecoration(
                          labelText: l10n.authResetConfirmPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final trimmed = v ?? '';
                          if (trimmed.isEmpty) {
                            return l10n.authResetConfirmRequired;
                          }
                          if (trimmed != _newCtrl.text) {
                            return l10n.authResetMismatch;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      GlassButton(
                        label: reset.isLoading ? '' : l10n.authResetSave,
                        onPressed: reset.isLoading ? null : _onSubmit,
                        expand: true,
                        variant: GlassButtonVariant.primary,
                      ),
                      if (reset.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            ),
                          ),
                        ),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../widgets/glass/glass_button.dart';
import '../../../widgets/glass/glass_card.dart';

import '../providers/password_reset_provider.dart';
import 'enter_reset_code_screen.dart';

/// Step 1 of the password-reset flow.
///
/// Collects the email the user wants a reset code for, kicks off
/// [PasswordResetProvider.requestCode], and on success pushes
/// [EnterResetCodeScreen] on top. We deliberately do NOT pop this
/// screen — leaving it on the stack means the system back-button
/// from step 2 returns here naturally if the user wants to change
/// the email address they entered.
///
/// The screen does NOT distinguish "email exists" vs "email doesn't
/// exist" — the backend intentionally returns the same generic
/// success copy for both. That's a security feature (email-
/// enumeration prevention), not a bug, so the UI mirrors that
/// behaviour: the user always sees a "we sent a code" SnackBar /
/// forward-navigation, regardless of whether the email is real.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  // Same email regex used in the rest of the app's auth flows. Keeping
  // the pattern here means a typo (e.g. trailing space) gets caught
  // before the round-trip to the backend.
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final reset = context.read<PasswordResetProvider>();
    final ok = await reset.requestCode(_emailCtrl.text.trim());
    if (!mounted) return;

    if (ok) {
      // Move to step 2. We do NOT pop this screen — leaving it on
      // the stack means the system back-button from step 2 returns
      // here (so the user can correct a typo in the email) and the
      // back-from-login-side will pop the whole flow naturally.
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EnterResetCodeScreen()),
      );
    } else {
      // The only realistic failure here is a transport-level error
      // (the backend never returns 4xx for this route — it's generic
      // by design). The provider's `errorMessage` carries the
      // human-readable copy; surface it in a SnackBar.
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
    // watch() so the submit button reflects the in-flight state and
    // shows a spinner without us having to setState() in the action.
    final reset = context.watch<PasswordResetProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authForgotTitle)),
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
                        l10n.authForgotInstructions,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _onSubmit(),
                        decoration: InputDecoration(
                          labelText: l10n.authEmailLabel,
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final trimmed = (v ?? '').trim();
                          if (trimmed.isEmpty) return l10n.authEmailRequired;
                          if (!_emailRegex.hasMatch(trimmed)) {
                            return l10n.authEmailInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      GlassButton(
                        label: reset.isLoading ? '' : l10n.authForgotSendCode,
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

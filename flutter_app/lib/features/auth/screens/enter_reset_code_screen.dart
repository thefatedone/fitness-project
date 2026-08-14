import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../widgets/glass/glass_button.dart';
import '../../../widgets/glass/glass_card.dart';

import '../providers/password_reset_provider.dart';
import 'reset_password_screen.dart';

/// Step 2 of the password-reset flow.
///
/// User pastes / types the 6-digit code that the backend emailed.
/// We pre-fill the destination email from [PasswordResetProvider.email]
/// so the user can confirm they're checking the right inbox, and
/// push [ResetPasswordScreen] on a successful verify.
///
/// The code input uses `letterSpacing: 8` + a larger font so the
/// six digits are easy to read and hard to typo — standard OTP
/// conventions. Numeric-keyboard only and a `length == 6` validator
/// keep the field tight.
class EnterResetCodeScreen extends StatefulWidget {
  const EnterResetCodeScreen({super.key});

  @override
  State<EnterResetCodeScreen> createState() => _EnterResetCodeScreenState();
}

class _EnterResetCodeScreenState extends State<EnterResetCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final reset = context.read<PasswordResetProvider>();
    final ok = await reset.verifyCode(_codeCtrl.text.trim());
    if (!mounted) return;

    if (ok) {
      // Step 3 — the new-password screen. We do NOT pop this screen;
      // the back-button on step 3 will pop back here, the back-button
      // here will pop back to step 1 (the email screen), and the
      // back-button on step 1 will pop back to login — that's the
      // intended "trail of crumbs" the user follows through the flow.
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      );
    } else {
      // Generic bad-code copy comes straight from the backend via
      // `ApiException.message`.
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

  /// "Отправить код повторно" → pop back to step 1 so the user
  /// can re-trigger the email send from there. We deliberately do
  /// NOT call `reset.requestCode(...)` from here — the resend
  /// logic is owned by [ForgotPasswordScreen], and going back
  /// there means the user re-uses the same email field with the
  /// same validators, which is the simpler UX.
  void _onResend() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reset = context.watch<PasswordResetProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authCodeTitle)),
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
                        l10n.authCodeInstructions(reset.email),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        // No leading-zero ambiguity, no autocorrect, no
                        // spaces in the middle — the user is typing six
                        // discrete digits. Limiting to 6 chars via
                        // `maxLength` also keeps the UI from showing
                        // partial 7+ digit overflows.
                        maxLength: 6,
                        autocorrect: false,
                        enableSuggestions: false,
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.done,
                        // Numeric-only input. `FilteringTextInputFormatter`
                        // strips anything that isn't a digit at the
                        // keystroke level — way more user-friendly than
                        // catching non-digits in the validator.
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onFieldSubmitted: (_) => _onSubmit(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 8,
                          // Monospaced so the 8px letter-spacing actually
                          // produces evenly-spaced digits (proportional
                          // digits would visually crowd together).
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.authCodeField,
                          counterText: '', // hide the 0/6 counter
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (v) {
                          final code = (v ?? '').trim();
                          if (code.length != 6) {
                            return l10n.authCodeRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      GlassButton(
                        label: reset.isLoading ? '' : l10n.authCodeConfirm,
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
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: reset.isLoading ? null : _onResend,
                        child: Text(l10n.authCodeResend),
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

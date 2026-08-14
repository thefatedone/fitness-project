import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/providers/auth_api.dart';
import '../providers/password_api.dart';

/// Change-password flow.
///
/// Single responsibility: collect current + new + confirm passwords,
/// validate them client-side (mirroring the backend's rules via the
/// shared [validatePassword] helper), POST to the backend via
/// [PasswordApi], and report success / failure to the user with a
/// SnackBar.
///
/// One-shot state lives in this widget (`_isSubmitting`) — this is a
/// self-contained action, not a cross-screen concern, so a full
/// `ChangeNotifier` provider is overkill.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  /// `true` while the network call is in flight. Drives the submit
  /// button's spinner + disabled state.
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ---- submit ----------------------------------------------------------------

  Future<void> _onSubmit() async {
    // (1) Run the standard form-level validate so each field's
    // individual error shows up under it.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    final api = PasswordApi();
    try {
      final msg = await api.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;

      // (2) Success path. We chose to show the SnackBar on THIS
      // screen first, give the user ~1.5s to read it, then pop back.
      // The alternative (pop immediately, let the SnackBar show on the
      // parent profile screen) felt more jarring — the user's action
      // was on this screen, so the confirmation lives here too.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // (3) Failure path. If the error is specifically "wrong current
      // password" (the 400 case), clear that field so the user can
      // re-enter a different value without manually deleting what they
      // already typed. Other errors (e.g. 422 from a backend-side
      // strength-rule mismatch the client somehow missed) leave the
      // current-password field intact.
      // Note: the substring check matches the backend's
      // deleteAccountWrongPasswordMatch string (Russian) as well as
      // any future localised copy of the same condition. We sniff for
      // a generic "current password" prefix so this stays robust
      // across languages — the worst case is the user has to
      // manually clear the field themselves, which is fine.
      final isWrongCurrent = e.message.toLowerCase().contains('current password')
          || e.message.toLowerCase().contains('текущий пароль');
      if (isWrongCurrent) {
        _currentCtrl.clear();
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      // Defensive — anything non-ApiException that escapes the API layer
      // shouldn't crash the screen. Mirrors the same pattern in
      // `register_screen.dart`'s _onSubmit.
      if (!mounted) return;
      setState(() => _isSubmitting = false);
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

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.changePasswordTitle),
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
                    TextFormField(
                      controller: _currentCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.changePasswordCurrent,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l10n.changePasswordCurrentRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.changePasswordNew,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        // Mirrors the helper text used in
                        // `register_screen.dart` so the user sees the
                        // same wording whether they're signing up or
                        // changing their password.
                        helperText: l10n.authPasswordHelper,
                      ),
                      // Reuses the same `validatePassword` helper that
                      // the registration flow uses; backend rules
                      // match (the only source of truth is
                      // `validate_password_strength` on the FastAPI
                      // side, mirrored in this same helper for the
                      // mobile client).
                      validator: (v) => validatePassword(v ?? ''),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onSubmit(),
                      decoration: InputDecoration(
                        labelText: l10n.changePasswordConfirm,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                      // Cross-field: confirm must match the live text
                      // of the new-password field. Reading _newCtrl.text
                      // at validate time works because the wizard calls
                      // validate() on submit, after the user has stopped
                      // typing in the new-password field.
                      validator: (v) {
                        final trimmed = v ?? '';
                        if (trimmed.isEmpty) return l10n.authResetConfirmRequired;
                        if (trimmed != _newCtrl.text) {
                          return l10n.authResetMismatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _onSubmit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.changePasswordSave),
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
}

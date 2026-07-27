import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_api.dart';
import '../providers/auth_provider.dart';
import '../providers/email_verification_api.dart';

/// Show the two-stage email-verification bottom sheet.
///
/// Single entry point — call `showVerifyEmailSheet(context)` from
/// anywhere that has a [BuildContext] (the home-screen banner button,
/// or any future "verify your email" prompt). The sheet itself owns
/// the multi-stage UI via the private [_VerifyEmailSheetContent]
/// stateful widget below.
///
/// Two stages:
///   1. Send the code. The sheet reads the current user's email from
///      [AuthProvider] and shows it ("we'll send a code to {email}"),
///      then a primary button that calls `EmailVerificationApi.sendCode`.
///      On success it transitions to stage 2 — no navigation, the
///      sheet just rebuilds itself.
///   2. Enter the code. Same OTP-style 6-digit field the password-reset
///      flow uses (monospace, 8 px letter-spacing, digitsOnly formatter).
///      On verify success the sheet:
///        * patches the cached [UserModel] via
///          `currentUser.copyWith(isEmailVerified: true)` and pushes it
///          through `AuthProvider.updateCurrentUser` so the banner
///          on the home screen disappears on the next frame;
///        * shows the success SnackBar;
///        * pops the bottom sheet (`Navigator.of(context).pop()`).
///      On failure the SnackBar carries the backend's error copy and
///      the sheet stays on stage 2 so the user can retry the same
///      code or trigger a fresh send via the inline "Отправить код
///      повторно" button.
Future<void> showVerifyEmailSheet(BuildContext context) async {
  // showModalBottomSheet returns `Future<T?>` where T is the sheet's
  // route-arg type. We use `void` as the route-arg type since the
  // sheet doesn't return anything to the caller, which gives us
  // `Future<void?>`. Awaiting the call here so the `async` body
  // always has at least one `await` — keeps the analyzer happy with
  // a `Future<void>` return type (we discard the trailing `null`
  // from the call's return value, which doesn't matter to callers).
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _VerifyEmailSheetContent(),
  );
}

class _VerifyEmailSheetContent extends StatefulWidget {
  const _VerifyEmailSheetContent();

  @override
  State<_VerifyEmailSheetContent> createState() =>
      _VerifyEmailSheetContentState();
}

class _VerifyEmailSheetContentState extends State<_VerifyEmailSheetContent> {
  /// Two-stage state machine — see the docstring on
  /// `showVerifyEmailSheet`. The order matches the order the user
  /// experiences the flow: send code first, enter the code second.
  /// Resetting to stage 0 (e.g. after the user taps
  /// "Отправить код повторно" on stage 1) just keeps them on stage 1
  /// with a fresh send — the spec explicitly says the user stays on
  /// the code-entry stage after a re-send.
  bool _stageSend = true;

  bool _isSending = false;
  bool _isVerifying = false;

  final _api = EmailVerificationApi();
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  String get _email {
    // Safe — AuthGate's exhaustive switch only routes to this screen
    // once the user is authenticated, so currentUser is non-null
    // here. The fallback is a "weird but not crash" guard against
    // a logout race that closes the sheet via `Navigator.pop` from
    // a different listener.
    return context.read<AuthProvider>().currentUser?.email ?? '';
  }

  Future<void> _sendCode() async {
    setState(() => _isSending = true);
    try {
      final msg = await _api.sendCode();
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _stageSend = false; // advance to code-entry stage
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isVerifying = true);
    try {
      final msg = await _api.verifyCode(_codeCtrl.text.trim());
      if (!mounted) return;

      // Patch the cached UserModel with `isEmailVerified: true` and
      // push it back through the provider so the home-screen banner
      // disappears on the next rebuild. We know exactly what changed
      // (one boolean) so we don't need a full /users/me refetch.
      final auth = context.read<AuthProvider>();
      final current = auth.currentUser;
      if (current != null) {
        auth.updateCurrentUser(
          current.copyWith(isEmailVerified: true),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// "Отправить код повторно" — re-trigger the send and stay on
  /// stage 1 (the code-entry stage) so the user can type the fresh
  /// code right in. The spec explicitly says: stay on the code-entry
  /// stage, don't visually go back to stage 0 first.
  Future<void> _resend() async {
    setState(() => _isVerifying = true);
    try {
      final msg = await _api.sendCode();
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _codeCtrl.clear();
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Подтверждение email',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (_stageSend) ...[
              // Stage 1: explain + send.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Мы отправим код подтверждения на $_email',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSending ? null : _sendCode,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Отправить код'),
              ),
            ] else ...[
              // Stage 2: enter the code. Same OTP-style field as
              // enter_reset_code_screen.dart so the two code-entry
              // surfaces feel like siblings.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Введи код из письма',
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
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autocorrect: false,
                      enableSuggestions: false,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onFieldSubmitted: (_) => _verify(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Код',
                        counterText: '',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (v) {
                        final code = (v ?? '').trim();
                        if (code.length != 6) {
                          return 'Код состоит из 6 цифр';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isVerifying ? null : _verify,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Подтвердить'),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isVerifying ? null : _resend,
                        child: const Text('Отправить код повторно'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

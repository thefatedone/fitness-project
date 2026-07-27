import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'onboarding_wizard_screen.dart';

/// Email-only login screen.
///
/// Single responsibility: collect an email + password, run client-side
/// validation, hand them off to [AuthProvider.login], and surface any
/// failure from the provider as a SnackBar. Navigation after a successful
/// login is intentionally absent — the [AuthGate] in `main.dart` reacts to
/// `AuthProvider.status` and swaps to `HomeScreen` automatically. Keeping
/// navigation out of the screen avoids two sources of truth for routing.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Drives the whole Form. Kept as a field so the "Войти" button can
  /// `currentState!.validate()` without re-walking the tree.
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    // Don't trigger the auth call if the form has any invalid field.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    // Failure path — show a SnackBar with whatever the provider captured.
    // Success path is intentionally empty: AuthGate listens to status and
    // navigates for us.
    if (!ok && auth.errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch → rebuild when isLoading flips, so the button swaps to a
    // spinner without any imperative setState in this widget.
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand mark + greeting.
                    Text(
                      'NutriMind',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'С возвращением',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Введи email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onSubmit(),
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Введи пароль';
                        }
                        return null;
                      },
                    ),

                    // Forgot-password link. Placed directly under the
                    // password field (right-aligned, low-emphasis
                    // text button) so the user who's about to give up
                    // because they can't remember the password sees
                    // the alternative path right next to the input
                    // they're stuck on. A11y label clarifies intent.
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          minimumSize: const Size(0, 32),
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Забыл пароль?'),
                      ),
                    ),

                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: auth.isLoading ? null : _onSubmit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Войти'),
                    ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => Navigator.of(context).push(
                                // New users land in the 4-step onboarding
                                // wizard (auth credentials + full
                                // profile), not the old single-screen
                                // RegisterScreen. The old widget stays
                                // in the codebase for now in case a
                                // future deep link references it.
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const OnboardingWizardScreen(),
                                ),
                              ),
                      child: const Text('Нет аккаунта? Зарегистрироваться'),
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

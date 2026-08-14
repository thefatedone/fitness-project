import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/api_environment_card.dart';
import '../../../widgets/glass/glass_button.dart';
import '../../../widgets/glass/glass_card.dart';
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
  void initState() {
    super.initState();
    // Show the "Сессия истекла" SnackBar ONCE if we got here because
    // the apiClient 401 hook forced a logout. The flag is a one-shot
    // signal — we read it, fire the SnackBar, then clear it back
    // to false so a normal fresh-launch on LoginScreen (no expired
    // session) doesn't trigger the banner.
    //
    // `addPostFrameCallback` is required because ScaffoldMessenger
    // doesn't have a usable State<Element> until the first frame
    // has been laid out — calling showSnackBar in initState
    // directly throws. The post-frame callback fires after the
    // first build, when the messenger is fully wired.
    final auth = context.read<AuthProvider>();
    if (auth.sessionExpiredNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).authSessionExpired),
              behavior: SnackBarBehavior.floating,
            ),
          );
      });
      // Clear the flag immediately so a back-and-forth (push login →
      // push something else → pop back to login) doesn't re-show the
      // banner. The provider is a singleton, so the flag survives
      // across the navigation round-trip until the user dismisses
      // login for good.
      auth.clearSessionExpiredNotice();
    }
  }

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

  Future<void> _openApiEnvironment() async {
    // Resolves to when the user dismisses the sheet. The actual
    // setting (URL change, persist, SnackBar) happens inside the
    // card itself — we only show / hide it.
    await ApiEnvironmentCard.showAsModalBottomSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    // watch → rebuild when isLoading flips, so the button swaps to a
    // spinner without any imperative setState in this widget.
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                    // Brand mark + greeting.
                    Text(
                      l10n.authLoginTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.authLoginSubtitle,
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
                      decoration: InputDecoration(
                        labelText: l10n.authEmailLabel,
                        prefixIcon: const Icon(Icons.alternate_email),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l10n.authEmailRequired;
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
                      decoration: InputDecoration(
                        labelText: l10n.authPasswordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l10n.authPasswordRequired;
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
                        child: Text(l10n.authForgotPassword),
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Primary CTA — GlassButton so the "Войти" pill
                    // picks up the same Liquid Glass treatment as
                    // the rest of the app's CTAs (spring press,
                    // brand-tinted emphasized glass).
                    GlassButton(
                      label: auth.isLoading ? '' : l10n.authLoginButton,
                      onPressed: auth.isLoading ? null : _onSubmit,
                      expand: true,
                      variant: GlassButtonVariant.primary,
                    ),
                    if (auth.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                            ),
                          ),
                        ),
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
                      child: Text(l10n.authNoAccountRegister),
                    ),

                    // --------------------------------------------------------
                    // Debug-only entry point for the API-environment
                    // switcher. Solves the chicken-and-egg problem:
                    // before any auth can happen, `apiClient.dio` needs
                    // the right base URL — but the original switcher
                    // lived only on the Settings screen, which itself
                    // is only reachable AFTER authentication.
                    //
                    // Placement rationale: at the very bottom of the
                    // Column, with a meaningful top gap (40 px) so
                    // the link reads as a *separate* category from the
                    // auth controls above. Lower-emphasis text + muted
                    // foreground signal "out of band" — the same visual
                    // language the "Забыл пароль?" link uses so we
                    // don't introduce a new pattern.
                    //
                    // Modal: tapping the link opens the same
                    // `ApiEnvironmentCard` as Settings — no duplicated
                    // UI. Pressing back, the drag handle, or tapping
                    // outside dismisses.
                    //
                    // The link is intentionally NOT gated on
                    // `auth.isLoading` — flipping the API URL while a
                    // login is in flight is harmless (the in-flight
                    // request keeps its captured URL, and the next
                    // request goes to the new host), and gating it
                    // would just be visual noise.
                    //
                    // Entire block is `if (kDebugMode)` so a release
                    // build doesn't ship this control.
                    if (kDebugMode) ...[
                      const SizedBox(height: 40),
                      TextButton.icon(
                        onPressed: _openApiEnvironment,
                        icon: const Icon(Icons.settings_ethernet, size: 18),
                        label: Text(l10n.authServerDebugLink),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              theme.colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
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

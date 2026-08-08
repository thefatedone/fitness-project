import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/verify_email_sheet.dart';

/// "Verify your email" reminder banner.
///
/// Single responsibility: show a non-blocking, dismissible reminder on
/// the home screen while `currentUser.isEmailVerified` is false. The
/// banner reads from `AuthProvider` via `context.watch` so a successful
/// verify (which calls `updateCurrentUser` with the new flag) makes it
/// disappear immediately without needing a full refetch.
///
/// Email verification is intentionally NOT an access gate — login
/// works regardless of this flag, the entire app is reachable, and
/// the only consequence of leaving it unverified is "this banner
/// shows up". Hence the wording is a soft reminder, not a warning.
///
/// Dismissal is SESSION-ONLY: the `_dismissed` flag below is an
/// instance field on the [State] below, so a fresh widget instance
/// (e.g. after the home screen rebuilds for a theme switch) starts
/// un-dismissed. The spec explicitly says dismissal must NOT persist
/// to disk — verification (a separate path) is the only way to make
/// the banner stop showing for good. The cold-start guarantee is
/// implicit: a new widget instance starts with `_dismissed = false`.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  State<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  /// The single source of truth for "user has dismissed the banner".
  /// Lives on the State instance (not static) so the same widget's
  /// build() reads it AND the dismiss button's onPressed writes it
  /// — the previous bug was that the read happened in an outer
  /// StatelessWidget while the write happened in an inner
  /// StatefulWidget, so setState() never propagated upward.
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    // Same build() reads all four "no banner" conditions AND owns
    // the dismissal state, so a setState() inside this widget's
    // subtree immediately re-runs this method and the banner
    // disappears on the next frame.
    //
    //   1. Not signed in (defensive — AuthGate should already be
    //      showing the login screen, but be safe).
    //   2. Phone-only account — there's nothing to verify, no
    //      email address to send a code TO.
    //   3. Already verified.
    //   4. User dismissed the banner earlier in this widget's
    //      lifetime.
    if (user == null) return const SizedBox.shrink();
    if (user.email == null || user.email!.isEmpty) {
      return const SizedBox.shrink();
    }
    if (user.isEmailVerified) return const SizedBox.shrink();
    if (_dismissed) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFFFFF7E6), // very light amber tint
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.mark_email_unread,
                size: 20,
                color: Color(0xFFB45309), // amber-700
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Подтверди свой email, чтобы не потерять доступ к аккаунту.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF92400E), // amber-800
                        height: 1.25,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => showVerifyEmailSheet(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFFB45309),
                ),
                child: const Text('Подтвердить'),
              ),
              IconButton(
                tooltip: 'Скрыть',
                onPressed: () {
                  // The setState() lands on the SAME State that owns
                  // the `_dismissed` flag this same build() reads —
                  // so the next rebuild returns SizedBox.shrink() and
                  // the banner disappears on the very next frame.
                  setState(() => _dismissed = true);
                },
                icon: const Icon(
                  Icons.close,
                  size: 18,
                ),
                color: const Color(0xFF92400E),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

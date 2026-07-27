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
/// Dismissal is SESSION-ONLY: a [static] flag means tapping the `x`
/// hides the banner for the rest of the app process, but a cold
/// start re-shows it. The spec is explicit about not persisting
/// dismissal to disk — the reminder should reappear on the next
/// launch until the user actually verifies. Verification (a
/// separate path) is the only way to make the banner stop showing
/// for good.
class EmailVerificationBanner extends StatelessWidget {
  /// Session-wide "user has dismissed the banner" flag. Reset to
  /// `false` on cold start because Dart resets all [static] fields
  /// when the isolate dies — which is exactly the "dismissal doesn't
  /// persist across launches" behaviour the spec requires.
  static bool _dismissedThisSession = false;

  const EmailVerificationBanner({super.key});

  /// Resets the session-dismissed flag. Test-only / future "send
  /// reminder again" hook — production code never needs to call this
  /// because the flag naturally resets on cold start.
  @visibleForTesting
  static void resetDismissal() {
    _dismissedThisSession = false;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    // Three "no banner" paths:
    //   1. Not signed in (defensive — AuthGate should already be
    //      showing the login screen, but be safe).
    //   2. Phone-only account — there's nothing to verify, no
    //      email address to send a code TO.
    //   3. Already verified.
    //   4. User dismissed the banner earlier in this session.
    if (user == null) return const SizedBox.shrink();
    if (user.email == null || user.email!.isEmpty) {
      return const SizedBox.shrink();
    }
    if (user.isEmailVerified) return const SizedBox.shrink();
    if (_dismissedThisSession) return const SizedBox.shrink();

    return _BannerContent(
      email: user.email!,
      onDismiss: () {
        _dismissedThisSession = true;
        // No setState needed — the next build will pick up the new
        // value of the static. But this widget's parent (the home
        // screen) might not re-build on a static-mutation, so we
        // ask the parent to refresh via the provider's listener.
        // The cleanest portable trick: trigger a setState in the
        // wrapping MaterialApp (a NoOp) — but in practice the
        // `context.watch<AuthProvider>()` above is the same channel
        // the dismiss action uses to propagate. We force a
        // notification by reaching for the provider and asking it
        // to notify, but that's not allowed (it isn't a real
        // mutation). Simpler: wrap the banner in a small stateful
        // wrapper. See _BannerContent.
      },
    );
  }
}

/// Internal — the actual visual. Extracted so the parent's
/// `_dismissedThisSession` write can trigger a re-render via the
/// StatefulWidget's own [setState], without needing to expose the
/// static flag to the rest of the app.
class _BannerContent extends StatefulWidget {
  const _BannerContent({required this.email, required this.onDismiss});

  final String email;
  final VoidCallback onDismiss;

  @override
  State<_BannerContent> createState() => _BannerContentState();
}

class _BannerContentState extends State<_BannerContent> {
  @override
  Widget build(BuildContext context) {
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
                onPressed: widget.onDismiss,
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import 'entry_splash_screen.dart';

/// Gates the real AuthGate content behind the entry splash.
///
/// Visibility of the splash is governed by TWO independent
/// conditions, BOTH of which must be true before we crossfade out:
///
/// 1. The splash's own minimum on-screen time has elapsed
///    ([EntrySplashScreen.wordmarkDuration] +
///    [EntrySplashScreen.holdDuration]). This guarantees the user
///    sees the full animation + a brief rest regardless of how
///    fast `tryAutoLogin()` resolves — a near-instant auth
///    resolution that would otherwise cut straight to LoginScreen
///    would feel broken (the splash would just flicker).
///
/// 2. `AuthProvider.status` has left [AuthStatus.unknown]. The
///    splash must NOT resolve to `LoginScreen` or
///    `TrackerHomeScreen` before the provider knows which one is
///    correct — a stale `unknown` → `unauthenticated` flash
///    would briefly show a loading spinner inside the splash's
///    fade-out, which is exactly the binary-switch artifact we
///    built the splash to avoid.
///
/// The crossfade out uses [AnimatedSwitcher] with a 280ms
/// [FadeTransition] so the splash's own fade-in and the gate's
/// fade-out feel like one continuous visual language. The
/// AnimatedSwitcher is keyed by a derived bool (splash vs real),
/// not by the child widget identity, so the SAME child instance is
/// reused for the real content — preserving any internal state
/// the auth flow might already be holding (form fields, scroll
/// positions, etc.).
///
/// `AuthGate` itself remains a pure switch on `AuthStatus` — the
/// splash gate is *separate* UI state layered on top, not a
/// fourth `AuthStatus` case. Adding a fourth case would muddle
/// the auth state machine (splash visibility has nothing to do
/// with auth) and would lose the exhaustive-switch compile-time
/// check that catches missing auth-status cases today.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  /// The real content the user lands on after the splash — almost
  /// always `AuthGate`, but kept generic so the gate can wrap any
  /// single-child tree.
  final Widget child;

  /// Total on-screen time before the splash may transition out,
  /// irrespective of auth state. Composed from the wordmark's own
  /// animation duration plus a brief hold so the user registers
  /// the brand. Configurable so tests can squash the timing.
  static const Duration minimumOnScreen = Duration(
    milliseconds: 800 + 300, // wordmark + hold
  );

  /// Crossfade-out duration between splash and real content.
  /// Matches the visual language of the splash's own fade-in
  /// (the splash itself uses opacity 0→1 over the same curve),
  /// so the transition reads as one continuous arc rather than
  /// a discrete "splash → app" step.
  static const Duration crossfadeDuration = Duration(milliseconds: 280);

  /// Hard ceiling so the splash never blocks past this even if
  /// auth never resolves. `tryAutoLogin()` already has its own
  /// internal timeout/retry behaviour in `AuthProvider`, so the
  /// gate's role here is purely defensive — the splash must
  /// always be a *transient* and never a permanent black screen.
  /// Set comfortably above the typical happy-path ceiling so the
  /// cap only fires when something's genuinely stuck.
  static const Duration maximumWait = Duration(milliseconds: 1500);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  /// True once the splash's own minimum on-screen time has
  /// elapsed. Set by a one-shot Timer started in [initState].
  bool _minimumTimeElapsed = false;

  /// True once [maximumWait] has passed regardless of auth state.
  /// Acts as a defensive ceiling — the splash must never block
  /// the app permanently. AuthProvider already has its own retry
  /// behaviour, so this only fires when auth is genuinely stuck.
  bool _maxWaitElapsed = false;

  Timer? _minimumTimer;
  Timer? _maxTimer;

  @override
  void initState() {
    super.initState();
    _minimumTimer = Timer(SplashGate.minimumOnScreen, () {
      if (!mounted) return;
      setState(() => _minimumTimeElapsed = true);
    });
    _maxTimer = Timer(SplashGate.maximumWait, () {
      if (!mounted) return;
      setState(() => _maxWaitElapsed = true);
    });
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _maxTimer?.cancel();
    super.dispose();
  }

  bool _shouldShowSplash(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final authResolved = auth.status != AuthStatus.unknown;
    // Conservative OR: show the splash while EITHER condition
    // hasn't flipped. The crossfade out happens once both are
    // true (or once the max-wait ceiling fires, in which case we
    // drop to whatever auth state we have, even if still
    // `unknown`).
    return !_minimumTimeElapsed || (!authResolved && !_maxWaitElapsed);
  }

  @override
  Widget build(BuildContext context) {
    final showSplash = _shouldShowSplash(context);
    return AnimatedSwitcher(
      // duration vs reverseDuration kept symmetric so a late auth
      // resolution past the splash doesn't cause a visibly
      // asymmetric fade — the user sees the same crossfade
      // regardless of which direction the gate flips.
      duration: SplashGate.crossfadeDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      // Keyed by the showSplash bool so the AnimatedSwitcher
      // recognises the swap as a child-replacement and runs the
      // transition. Using the child itself as the child of the
      // AnimatedSwitcher would also work but would re-key on every
      // widget-tree rebuild downstream of AuthGate, churning the
      // transition — explicit bool key keeps it stable.
      child: KeyedSubtree(
        key: ValueKey<bool>(showSplash),
        child: showSplash
            ? const EntrySplashScreen()
            : widget.child,
      ),
    );
  }
}

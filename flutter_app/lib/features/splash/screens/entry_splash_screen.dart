import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass/glass_background_glow.dart';

/// Animated entry splash — the "NutriMind" wordmark that plays for
/// ~1.1s when the app cold-starts, before the real content
/// (login or tracker home) takes over.
///
/// Visual language: reuses [GlassBackgroundGlow] so the background
/// matches the rest of the app — same brand-green glow, same
/// top-band mask — rather than rendering a flat-coloured splash
/// screen that would read as bolted-on. The wordmark itself uses
/// the same `Comfortaa` typography the rest of the app uses via
/// [AppTheme] (registered in `pubspec.yaml`), and the same
/// hero-sized scale (headlineLarge) so it visually matches the
/// landing page's brand voice.
///
/// Animation: single [AnimationController] drives three coordinated
/// effects on the wordmark — fade-in (opacity 0→1), rise
/// (translateY 14→0), and a slight scale-up (0.94→1.0). All three
/// run through one [CurvedAnimation] (`Curves.easeOutQuint`) so
/// they move in lockstep rather than as three uncoordinated
/// tweens. A brand-green underline accent fades in slightly behind
/// the wordmark via a delayed [CurvedAnimation] sharing the same
/// controller — a quiet trailing accent rather than a big
/// flourish, matching the glass system's restraint.
///
/// Accessibility:
///   * When system "Reduce Motion" is on (`MediaQuery.disableAnimations`)
///     the wordmark renders at full opacity instantly with no rise
///     or scale; only the underline accent still fades. The 300ms
///     minimum hold + the crossfade transition out still apply
///     because they're separate from the wordmark's motion, not
///     from its visual presence.
///   * GlassBackgroundGlow's reduce-transparency fallback handles
///     the system "Reduce Transparency" accessibility setting on
///     its own — this widget doesn't need to know about it.
class EntrySplashScreen extends StatefulWidget {
  const EntrySplashScreen({super.key});

  /// Wordmark fade-in + rise + scale duration. Within the 700–900ms
  /// band the spec calls for; we pick 800ms to leave headroom for
  /// the 300ms hold and the ~280ms crossfade out before we exceed
  /// the 1.5s end-to-end cap (1100 + 280 = 1380ms total visibility).
  static const Duration wordmarkDuration = Duration(milliseconds: 800);

  /// Static rest duration after the wordmark finishes animating
  /// in, before the splash gate transitions out. Gives the user
  /// a moment to register the brand rather than slamming straight
  /// into the next screen.
  static const Duration holdDuration = Duration(milliseconds: 300);

  @override
  State<EntrySplashScreen> createState() => _EntrySplashScreenState();
}

class _EntrySplashScreenState extends State<EntrySplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  /// Delayed curve for the brand-green underline accent that
  /// fades in slightly behind the wordmark — quiet trailing
  /// detail, not a flourish. The 100ms delay runs *inside* the
  /// controller's total duration (which extends beyond the
  /// wordmark's own duration to accommodate the accent's full
  /// fade-in).
  late final Animation<double> _accentCurve;

  /// True when system "Reduce Motion" is on. Read once on the
  /// first build via the inherited MediaQuery; the framework's
  /// setting can change at runtime (Settings.app), but we don't
  /// need to react mid-splash — the splash is a 1.1s transient.
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    // Total controller duration covers both the wordmark animation
    // AND the trailing accent's fade-in window, so the accent
    // curve's 100ms delay + its own fade fits inside the controller.
    _controller = AnimationController(
      vsync: this,
      duration: EntrySplashScreen.wordmarkDuration +
          const Duration(milliseconds: 250),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuint,
    );
    // Accent starts 100ms after the wordmark and fades in over the
    // remainder. `interval(0.4, 1.0)` on an 800ms + 250ms controller
    // (1050ms total) means it begins at 420ms and ends at 1050ms —
    // i.e. starts a touch before the wordmark finishes (clean
    // visual handoff) and trails into the hold.
    _accentCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    if (!_reduceMotion) {
      _controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MediaQuery.of(context).disableAnimations;
    if (next != _reduceMotion) {
      setState(() => _reduceMotion = next);
      if (next && _controller.status != AnimationStatus.completed) {
        // Jump straight to the finished state — no animation, but
        // still serves the final visual so the splash gate can
        // transition out cleanly when its minimum time elapses.
        _controller.value = 1.0;
      } else if (!next && _controller.status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Reuse the app's hero text style. headlineLarge is the
    // largest standard M3 type, fontSize 32 in our theme, and the
    // landing page already uses it for the brand wordmark — keeps
    // the splash and the landing page visually consistent.
    final base = theme.textTheme.headlineLarge ?? const TextStyle();
    final wordmarkStyle = base.copyWith(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
      letterSpacing: -0.5,
    );

    return Scaffold(
      // Body fills the screen — no SafeArea dance; the splash is
      // meant to bleed behind the status bar / home indicator
      // exactly like the rest of the app's glass surfaces do.
      body: Stack(
        children: [
          // Background glow — identical to the rest of the app's
          // hero surfaces, so the splash reads as part of the same
          // visual language rather than a tacked-on loading screen.
          const Positioned.fill(child: GlassBackgroundGlow()),
          // Wordmark — centred, animated via the same controller /
          // curve that drives opacity, rise, and scale together so
          // they land in lockstep.
          Center(
            child: AnimatedBuilder(
              animation: _curve,
              builder: (context, _) {
                // _reduceMotion → wordmark renders at full state
                // immediately, no rise/scale. The AnimatedBuilder
                // still wraps the subtree so the value reads
                // through _curve and the underline accent's
                // _accentCurve stay coherent.
                final t = _reduceMotion ? 1.0 : _curve.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 14),
                        child: Transform.scale(
                          // 0.94 → 1.0 — small enough to read as a
                          // single continuous "settle", large
                          // enough to feel like the wordmark is
                          // arriving rather than just appearing.
                          scale: 0.94 + 0.06 * t,
                          child: Text(
                            'NutriMind',
                            style: wordmarkStyle,
                          ),
                        ),
                      ),
                    ),
                    // Thin brand-green underline accent — fades
                    // in delayed relative to the wordmark via
                    // _accentCurve. Height 2 dp + ~36 dp width so
                    // it reads as a quiet trailing detail under
                    // the wordmark, not a divider.
                    AnimatedBuilder(
                      animation: _accentCurve,
                      builder: (context, _) {
                        return Opacity(
                          opacity: _accentCurve.value,
                          child: Container(
                            margin: const EdgeInsets.only(top: 10),
                            height: 2,
                            width: 36,
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

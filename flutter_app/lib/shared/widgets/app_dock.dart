import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/platform/accessibility_service.dart';

/// A single dock entry — what icon to show, what it does on tap,
/// and whether the entry is the "primary" action (rendered larger
/// and in a filled circle using the brand colour, matching how iOS /
/// macOS docks elevate the most-used app).
///
/// `onTap` is nullable so the entry can be rendered visibly-disabled
/// (e.g. the camera FAB when viewing a past day — the date in
/// `trackerHome.selectedDate` is yesterday or older, so we don't
/// want to allow the user to log entries for a date that the
/// rest of the UI wouldn't render against). Disabled entries render
/// at reduced opacity and ignore taps.
class DockItem {
  const DockItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String tooltip;

  /// `null` means the entry is rendered but disabled.
  final VoidCallback? onTap;

  /// Marks this as the primary action — drawn larger, filled with
  /// the brand colour, and sitting slightly higher than its
  /// neighbours. The Dock is allowed to have at most one `emphasized`
  /// entry; rendering the "add food" plus-icon as the primary
  /// matches the existing FAB pattern that lives on the home
  /// screen today and keeps the dock from looking like a flat row of
  /// five equal-weight icons.
  final bool emphasized;
}

/// macOS / iOS-style floating "Dock" — a frosted-glass pill that sits
/// at the bottom of the screen, holding a row of tappable icons.
///
/// The widget is positioned by the parent (typically via a `Positioned`
/// inside a `Stack`) so the same Dock can float over a scrolling
/// body without needing to know about that scrolling body. The Dock
/// itself is just the visual + interaction — the parent decides where
/// it sits, when it appears, and what it overlaps.
///
/// Why a Stack / Positioned parent rather than `bottomNavigationBar`:
/// `Scaffold.bottomNavigationBar` reserves a permanent strip of the
/// Scaffold's body area for itself (it never overlaps the content).
/// The Dock is intended to OVERLAP the scrolling body — content
/// scrolls under it — which requires the Dock to be a child of a
/// Stack rather than a Scaffold slot. The body ListView picks up the
/// extra bottom padding so its last item still clears the Dock.
///
/// Accessibility fallback: when the iOS "Reduce Transparency" setting
/// is enabled (Settings → Accessibility → Display & Text Size →
/// Reduce Transparency), the frosted-glass blur is replaced by a
/// fully-opaque solid surface — the same fallback Apple's own apps
/// apply. The setting is queried over a small platform channel and
/// re-checked whenever the app returns to the foreground (the only
/// realistic moment a user could have just toggled it). See
/// `lib/core/platform/accessibility_service.dart` for the design
/// rationale on why this is a one-shot query at resume-time rather
/// than an EventChannel.
class AppDock extends StatefulWidget {
  const AppDock({super.key, required this.items});

  final List<DockItem> items;

  @override
  State<AppDock> createState() => _AppDockState();
}

class _AppDockState extends State<AppDock> with WidgetsBindingObserver {
  /// Per-item "is the user currently pressing" map. We track a bool
  /// per item key so the AnimatedScale can drive a press-state per
  /// item independently — when the user holds down on item 2 and
  /// then item 4, each one's scale returns to 1.0 on its own
  /// tap-up.
  final Map<int, bool> _pressed = {};

  /// Mirror of `UIAccessibility.isReduceTransparencyEnabled`.
  ///
  /// `true` means the user has explicitly asked the system to skip
  /// translucent / blurred material in favour of solid surfaces —
  /// Apple's convention applies to *our* pill too, so we render a
  /// solid background instead of the `BackdropFilter` blur.
  ///
  /// Defaults to `false` so the first frame (drawn before the
  /// platform-channel round-trip resolves) is the
  /// accessible-default frosted-glass look. On Android / tests / any
  /// env where the platform channel isn't wired, [AccessibilityService]
  /// falls back to `false` and we render the regular look there too.
  bool _reduceTransparency = false;

  @override
  void initState() {
    super.initState();
    // The lifecycle observer is what lets us re-check the
    // accessibility setting when the user comes back from Settings
    // (their only realistic way to toggle Reduce Transparency while
    // our app is running). Without this, toggling, backgrounding,
    // and foregrounding the app would leave the Dock showing the
    // old look until something else triggered a full rebuild.
    WidgetsBinding.instance.addObserver(this);
    _refreshReduceTransparency();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `resumed` fires when the app returns to the foreground after
    // being backgrounded — exactly when a user could have just
    // toggled Reduce Transparency in Settings. `paused`/`inactive`
    // are intentionally ignored: we only need to re-check on
    // resume.
    if (state == AppLifecycleState.resumed) {
      _refreshReduceTransparency();
    }
  }

  /// Pulls the current accessibility value and, if it changed since
  /// we last saw it, schedules a rebuild. The `mounted` guard plus
  /// the equality check together prevent duplicate rebuild frames on
  /// hot-reload and on quick pause→resume→resume flutter sequences,
  /// which would otherwise drag every dock item through its press
  /// animation rebuild cycle for no visual change.
  Future<void> _refreshReduceTransparency() async {
    final next = await AccessibilityService.isReduceTransparencyEnabled();
    if (!mounted) return;
    if (next != _reduceTransparency) {
      setState(() => _reduceTransparency = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    // Default safe-area-aware bottom margin: the home indicator
    // (iOS) / gesture bar (Android) sits at
    // `mediaQuery.padding.bottom` — a value of 0 on devices that
    // don't have one. Adding 16 px gives the Dock visual breathing
    // room above the indicator without overlapping it.
    final bottomMargin = mediaQuery.padding.bottom + 16;

    // Two colour recipes, picked per accessibility setting.
    //
    //   * `opaqueCardColor` — the theme's own card surface, fully
    //     opaque. Used when Reduce Transparency is on, so the pill
    //     is unambiguously solid.
    //   * `frostedCardColor` — the same token with ~78% alpha, so
    //     the BackdropFilter blur underneath reads as a tinted
    //     glass. With alpha, the *blur* (not the Container) is what
    //     gives the pill its character.
    //
    // Both modes share the same hairline border + soft drop
    // shadow — those are presentational, not transparency-driven,
    // and removing them would over-correct the accessible fallback
    // into looking like a different widget entirely.
    final opaqueCardColor = theme.colorScheme.surfaceContainerHighest;
    final frostedCardColor = opaqueCardColor.withValues(alpha: 0.78);
    final borderColor =
        theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
    final shadowColor = Colors.black.withValues(alpha: 0.12);

    // The pill geometry is identical in both modes — only the
    // surface treatment changes. Building the same `Container` and
    // `Row` in both branches (rather than two parallel widget
    // trees) keeps the press-animation, disabled-opacity, and
    // emphasized-entry behaviour in one place and guarantees they
    // stay in sync across modes.
    final pill = Container(
      decoration: BoxDecoration(
        color: _reduceTransparency ? opaqueCardColor : frostedCardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < widget.items.length; i++)
            _DockIcon(
              item: widget.items[i],
              isPressed: _pressed[i] ?? false,
              onPressedChanged: (down) {
                setState(() => _pressed[i] = down);
              },
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomMargin),
      child: Center(
        child: ConstrainedBox(
          // Keeps the Dock from ever stretching edge-to-edge on
          // tablets. The hard cap at 480 is roughly the
          // "tier-of-dockable-icons" limit that iPadOS uses too —
          // beyond that the dock starts looking sparse.
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            // Outer horizontal padding so the dock floats with
            // breathing room from the screen edges even on phones.
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              // Material is here so the children can have ink-wells
              // for the press animation; the Material is invisible
              // (no `color` or `elevation`) so the BackdropFilter
              // below shows through.
              type: MaterialType.transparency,
              child: _wrapInGlassOrSolid(pill, _reduceTransparency),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps [child] in the appropriate surface treatment for the
  /// current accessibility setting.
  ///
  /// With Reduce Transparency ON, the underlying Container is
  /// already fully opaque, so wrapping in a `BackdropFilter` would
  /// be a no-op *and* wasteful of GPU — we serve the child directly.
  ///
  /// With the setting OFF, we round the corners of the blurred
  /// region (the rounded corners come *through* the blur, not from
  /// the underlying Container) and apply the 20-sigma blur, exactly
  /// as iOS / macOS docks do.
  Widget _wrapInGlassOrSolid(Widget child, bool reduceTransparency) {
    if (reduceTransparency) {
      return child;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: child,
      ),
    );
  }
}

/// A single icon button inside the Dock. Wraps the press-state +
/// tap animation in a self-contained widget so the parent rebuilds
/// only on user interaction.
class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.item,
    required this.isPressed,
    required this.onPressedChanged,
  });

  final DockItem item;
  final bool isPressed;
  final ValueChanged<bool> onPressedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = item.onTap != null;

    final iconColor = item.emphasized
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final background = item.emphasized
        ? theme.colorScheme.primary
        : Colors.transparent;

    // 0.38 keeps the icon comfortably visible while clearly reading
    // "taps won't do anything" — matching the disabled-icon opacity
    // Flutter uses for buttons off the M3 spec. Animated so switching
    // days (today → past, "camera/add" fade, etc.) animates rather
    // than hard-toggles.
    const double disabledOpacity = 0.38;
    const double enabledOpacity = 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: AnimatedOpacity(
        opacity: enabled ? enabledOpacity : disabledOpacity,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: isPressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Tooltip(
            message: item.tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: enabled ? (_) => onPressedChanged(true) : null,
              onTapUp: enabled ? (_) => onPressedChanged(false) : null,
              onTapCancel: enabled ? () => onPressedChanged(false) : null,
              onTap: enabled ? item.onTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                width: item.emphasized ? 52 : 44,
                height: item.emphasized ? 52 : 44,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  // Subtle "lift" on the emphasized entry so it visually
                  // anchors the dock even when the dock is at rest.
                  boxShadow: item.emphasized
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    item.icon,
                    size: item.emphasized ? 26 : 22,
                    color: iconColor,
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

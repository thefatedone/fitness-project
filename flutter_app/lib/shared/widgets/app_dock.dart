import 'package:flutter/material.dart';

import '../../theme/glass_tokens.dart';
import '../../utils/accessibility_utils.dart';
import '../../widgets/glass/glass_surface.dart';

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
/// Visual treatment is delegated to [GlassSurface] (with the
/// `dockRadius` corner), so every other glass surface in the app
/// draws from the same set of blur/tint/border tokens. The Reduce
/// Transparency accessibility fallback is now provided uniformly
/// across all glass widgets via [ReduceTransparencyScope] — the Dock
/// no longer carries its own platform-channel hookup.
class AppDock extends StatefulWidget {
  const AppDock({super.key, required this.items});

  final List<DockItem> items;

  @override
  State<AppDock> createState() => _AppDockState();
}

class _AppDockState extends State<AppDock> {
  /// Per-item "is the user currently pressing" map. We track a bool
  /// per item key so the AnimatedScale can drive a press-state per
  /// item independently — when the user holds down on item 2 and
  /// then item 4, each one's scale returns to 1.0 on its own
  /// tap-up.
  final Map<int, bool> _pressed = {};

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    // Default safe-area-aware bottom margin: the home indicator
    // (iOS) / gesture bar (Android) sits at
    // `mediaQuery.padding.bottom` — a value of 0 on devices that
    // don't have one. Adding 16 px gives the Dock visual breathing
    // room above the indicator without overlapping it.
    final bottomMargin = mediaQuery.padding.bottom + 16;

    final pill = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              // (no `color` or `elevation`) so the GlassSurface
              // below shows through.
              type: MaterialType.transparency,
              child: GlassSurface(
                borderRadius: BorderRadius.circular(GlassTokens.dockRadius),
                child: pill,
              ),
            ),
          ),
        ),
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
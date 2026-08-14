import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/glass_tokens.dart';
import '../../utils/accessibility_utils.dart';
import 'glass_surface.dart';

/// Liquid Glass chip — pill-shaped tag surface used for diet
/// preferences ("Vegetarian", "Vegan", …), allergy markers
/// ("Nuts", "Dairy", …), and any small inline tag the user can
/// remove with an × handle.
///
/// Sized for small surfaces — sigma stays in [GlassTokens.chipBlurSigma]
/// so the contained text stays crisp at normal viewing distance.
/// Specular highlight is disabled because on a chip-sized surface
/// it's more visual noise than atmosphere.
///
/// The optional [onRemove] handle renders the × icon and accepts
/// taps. When [onRemove] is `null`, the chip is locked (display-only)
/// — typically a saved form state where the user can't add or
/// remove tags but can still see which ones were already there.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.onRemove,
    this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final VoidCallback? onRemove;

  /// Brand / accent colour for the chip's foreground and × handle.
  /// Defaults to the theme's `colorScheme.primary` when omitted.
  final Color? color;

  /// Quick-pick "is this option the user's current choice" flag.
  /// When `true`, the chip picks up a stronger brand tint so the
  /// selected option reads as visually distinct from the
  /// unselected options around it.
  final bool selected;

  /// Optional tap handler — used by the water tracker for quick-
  /// pick chips. When non-null, the chip behaves like a button;
  /// when `null` and `onRemove` is also null, the chip is a
  /// static display surface.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tintColor = color ?? theme.colorScheme.primary;
    final reduceTransparency = ReduceTransparencyScope.of(context);

    final removeHandle = onRemove == null
        ? const SizedBox.shrink()
        : InkResponse(
            onTap: onRemove,
            radius: 14,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: tintColor),
            ),
          );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: tintColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onRemove != null) removeHandle,
      ],
    );

    if (reduceTransparency) {
      // Solid fallback path — same padding/radius as the glass
      // path below so the two branches stay visually identical
      // when Reduce Transparency is on. The selected-state tint
      // is denser so the active chip reads as visually heavier
      // than its unselected siblings.
      final tintAlpha = selected ? 0.30 : 0.10;
      final tint = tintColor.withValues(alpha: tintAlpha);
      final border = tintColor.withValues(alpha: selected ? 0.65 : 0.30);
      final chipContent = onTap == null
          ? content
          : InkResponse(
              onTap: onTap,
              radius: 14,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: content,
              ),
            );
      return Container(
        decoration: BoxDecoration(
          color: tint,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(GlassTokens.chipRadius),
        ),
        padding: EdgeInsets.only(
          left: 12,
          right: onRemove == null ? 12 : 4,
          top: 4,
          bottom: 4,
        ),
        child: chipContent,
      );
    }

    final VoidCallback? tap = onTap;
    final chipContent = tap == null
        ? content
        : InkResponse(
            // `selectionClick` (rather than `lightImpact`) matches
            // the iOS picker's segment-change tick and signals
            // "this is a state selection", not "this is a button
            // confirmation" — the glass chip is used for both
            // quick-pick selections (water volumes) and removable
            // tags, and selection-click reads correctly in both.
            onTap: () {
              HapticFeedback.selectionClick();
              tap();
            },
            radius: 14,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: content,
            ),
          );
    return GlassSurface(
      surfaceClass: GlassSurfaceClass.chip,
      enableSpecular: false,
      emphasized: selected,
      padding: EdgeInsets.only(
        left: 12,
        right: onRemove == null ? 12 : 4,
        top: 4,
        bottom: 4,
      ),
      child: chipContent,
    );
  }
}
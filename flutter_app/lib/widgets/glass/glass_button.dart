import 'package:flutter/material.dart';

import 'glass_card.dart';

/// Liquid Glass button. Two variants:
///
///   * `primary` — stronger brand-tinted glass under a "Continue"
///     / "Save" CTA. Sits visually above the page so the user
///     reads it as the dominant action.
///   * `secondary` — neutral glass. Used for dismiss / "Cancel"
///     actions where the brand-tinted primary already exists in
///     the same context.
///
/// Both variants share the same spring-based press animation as
/// [GlassCard] so the whole glass language feels consistent. A
/// light haptic on press is included; pass `hapticOnPress: false`
/// to silence it for buttons inside frequently-tapped lists.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = variant == GlassButtonVariant.primary;
    final isEnabled = onPressed != null;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isEnabled
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return GlassCard(
      onTap: onPressed,
      hapticOnPress: true,
      emphasized: isPrimary,
      padding: EdgeInsets.zero,
      child: content,
    );
  }
}

enum GlassButtonVariant { primary, secondary }
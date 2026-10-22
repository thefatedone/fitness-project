import 'package:flutter/material.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../theme/glass_tokens.dart';
import '../../../widgets/glass/glass_card.dart';
import '../../../widgets/glass/glass_progress_ring.dart';

/// Calorie ring and compact goal status. No status is shown without a valid
/// profile target; normal text fits within the existing ring-sized card.
class CaloriesSummaryCard extends StatelessWidget {
  const CaloriesSummaryCard({
    super.key,
    required this.consumed,
    required this.target,
  });

  final double consumed;
  final num? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasTarget = target != null && target!.isFinite && target! > 0;
    final ratio = hasTarget
        ? (consumed / target!.toDouble()).clamp(0.0, 1.0)
        : 0.0;
    final consumedRounded = consumed.round();
    final l10n = AppLocalizations.of(context);
    final delta = hasTarget ? target!.round() - consumedRounded : 0;
    final status = delta > 0
        ? l10n.caloriesRemaining(delta.toString())
        : delta < 0
        ? l10n.caloriesAbove((-delta).toString())
        : l10n.caloriesReached;

    // Glass treatment: the calorie summary is the dominant card on
    // the home screen, so wrapping it in a GlassCard gives it the
    // Liquid Glass look the rest of the screen now shares with the
    // Dock. The calorie count is rendered inside a
    // [GlassProgressRing] so the user reads both the absolute
    // number (centre) and the % of goal (ring fill) at a glance.
    //
    // Visual polish over the prior version:
    //   * The kcal value uses [onSurface] at `w700` so it reads as
    //     the primary number (not as a muted label).
    //   * The "X%" caption uses [onSurfaceVariant] at `w600` —
    //     visible but secondary.
    //   * The label "Calories today" is [onSurfaceVariant] as a
    //     muted caption; the kcal number is [onSurface] so the
    //     contrast hierarchy reads correctly on both themes.
    //   * The ring's tip-highlight is themed ([onSurface]) so the
    //     leading edge reads on both light and dark themes (the
    //     previous hard-coded white was invisible on light).
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      borderRadius: BorderRadius.circular(20),
      elevation: GlassElevation.hero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GlassProgressRing(
            value: ratio,
            color: scheme.primary,
            size: 96,
            strokeWidth: 10,
            tipHighlightColor: scheme.onSurface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$consumedRounded',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasTarget)
                  Text(
                    '${(ratio * 100).round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasTarget
                      ? AppLocalizations.of(context).trackerCaloriesToday
                      : AppLocalizations.of(context).trackerCaloriesEaten,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasTarget
                      ? AppLocalizations.of(
                          context,
                        ).trackerCaloriesKcalOf(target!.round().toString())
                      : AppLocalizations.of(context).trackerCaloriesKcalOnly,
                  // The kcal number is the primary text on the card —
                  // full contrast, not muted. The previous version
                  // used [onSurfaceVariant] which read as a label
                  // rather than a number; this version uses
                  // [onSurface] at `w700` so it reads as the hero
                  // value on both light and dark themes.
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasTarget) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (delta < 0 ? scheme.onSurfaceVariant : scheme.primary)
                              .withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: delta < 0
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

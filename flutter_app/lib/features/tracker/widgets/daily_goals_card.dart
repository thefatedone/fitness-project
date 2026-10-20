import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../widgets/glass/glass_card.dart';
import '../models/daily_goal_progress.dart';

/// Daily feedback stays separate from the diary streak: editing or exceeding a
/// nutrition target must not erase the user's habit of keeping a diary.
class DailyGoalsCard extends StatelessWidget {
  const DailyGoalsCard({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.onConfigure,
  });

  final DailyGoalProgress calories;
  final DailyGoalProgress protein;
  final DailyGoalProgress carbs;
  final DailyGoalProgress fat;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final goals = [calories, protein, carbs, fat];
    final configured = goals.where((goal) => goal.isConfigured).length;
    final completed = goals.where((goal) => goal.isInRange).length;
    final balanced = completed == 4;
    final labels = [
      l10n.balanceCalories,
      l10n.balanceProtein,
      l10n.trackerFoodCarbs,
      l10n.trackerFoodFat,
    ];
    final colors = [
      theme.colorScheme.primary,
      const Color(0xFF3B82F6),
      const Color(0xFFF97316),
      const Color(0xFFA855F7),
    ];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  balanced ? Icons.verified_outlined : Icons.track_changes,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.balanceTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      balanced ? l10n.balanceAchieved : l10n.balanceSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$completed / 4',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: balanced
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final singleColumn =
                  constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21;
              return Wrap(
                spacing: 16,
                runSpacing: 18,
                children: List.generate(
                  4,
                  (i) => SizedBox(
                    width: singleColumn
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 16) / 2,
                    child: _GoalTile(
                      label: labels[i],
                      goal: goals[i],
                      color: colors[i],
                      unit: i == 0 ? l10n.balanceKcal : l10n.balanceGrams,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
          ),
          const SizedBox(height: 12),
          Text(
            configured < 4 ? l10n.balanceSetTargets : l10n.balanceTolerance,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (configured < 4 && onConfigure != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onConfigure,
                child: Text(l10n.balanceConfigure),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.label,
    required this.goal,
    required this.color,
    required this.unit,
  });
  final String label;
  final DailyGoalProgress goal;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final status = !goal.isConfigured
        ? l10n.balanceNoTarget
        : goal.isInRange
        ? l10n.balanceInRange
        : goal.isAboveRange
        ? l10n.balanceAbove
        : l10n.balanceInProgress;
    final value = goal.hasValidIntake ? goal.consumed.round().toString() : '—';
    final target = goal.isConfigured ? goal.target!.round().toString() : '—';
    final quiet = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: quiet),
              ),
            ),
            if (goal.isInRange)
              Icon(Icons.check_circle_rounded, size: 16, color: color),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '$value / $target $unit',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: goal.progress),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              color: goal.isAboveRange ? quiet : color,
              backgroundColor: color.withValues(alpha: .10),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          status,
          style: theme.textTheme.labelSmall?.copyWith(
            color: goal.isInRange && theme.brightness == Brightness.light
                ? Color.lerp(color, Colors.black, .32)
                : goal.isInRange
                ? color
                : quiet,
          ),
        ),
      ],
    );
  }
}

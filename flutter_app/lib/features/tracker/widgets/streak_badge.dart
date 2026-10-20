import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../models/streak_model.dart';

class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.streak, required this.onTap});
  final StreakModel streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = streak.loggedToday
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label:
          '${AppLocalizations.of(context).streakTitle}: '
          '${streak.currentStreak} ${AppLocalizations.of(context).streakHeroLabel(streak.currentStreak)}',
      child: Tooltip(
        message: AppLocalizations.of(context).streakTitle,
        child: Material(
          color: color.withValues(alpha: streak.loggedToday ? .10 : .04),
          shape: StadiumBorder(
            side: BorderSide(color: color.withValues(alpha: .18)),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 19,
                      color: color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${streak.currentStreak}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

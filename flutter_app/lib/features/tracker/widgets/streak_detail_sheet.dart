import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../models/streak_model.dart';

/// The server remains authoritative for diary activity and streak milestones.
class StreakDetailSheet extends StatelessWidget {
  const StreakDetailSheet({super.key, required this.streak});
  final StreakModel streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.brightness == Brightness.light
        ? Color.lerp(theme.colorScheme.primary, Colors.black, .32)!
        : theme.colorScheme.primary;
    final quiet = theme.colorScheme.onSurfaceVariant;
    final status = streak.loggedToday
        ? l10n.streakStatusDone
        : streak.currentStreak == 0
        ? l10n.streakStatusStart
        : l10n.streakStatusPending;
    final next = streak.nextMilestone;
    final daysLeft = streak.daysToNextMilestone;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.streakTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.streakGentleSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: quiet,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primary.withValues(alpha: .12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${streak.currentStreak}',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2,
                              color: primary,
                            ),
                          ),
                          Text(
                            l10n.streakHeroLabel(streak.currentStreak),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: quiet,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withValues(alpha: .09),
                      ),
                      child: Icon(
                        Icons.local_fire_department_outlined,
                        size: 36,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      streak.loggedToday
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      color: primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.streakRecentDays,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _HistoryCalendar(history: streak.history),
          const SizedBox(height: 24),
          Text(
            l10n.streakMilestonesTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final milestone in [3, 7, 14, 30, 60, 100, 365])
                _MilestoneChip(
                  days: milestone,
                  reached: streak.currentStreak >= milestone,
                  next: next == milestone,
                ),
            ],
          ),
          if (next != null && next > 0 && daysLeft != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (streak.currentStreak / next).clamp(0.0, 1.0),
                minHeight: 5,
                color: primary,
                backgroundColor: primary.withValues(alpha: .10),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.streakMilestoneProgress(
                streak.currentStreak,
                next,
                daysLeft,
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: quiet),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.onSurface.withValues(alpha: .035),
            ),
            child: Text(
              l10n.streakBalanceIndependence,
              style: theme.textTheme.bodySmall?.copyWith(
                color: quiet,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              l10n.streakSectionRules,
              style: theme.textTheme.bodyMedium,
            ),
            children: [
              for (final rule in [
                (l10n.streakRule1Title, l10n.streakRule1Body),
                (l10n.streakRule2Title, l10n.streakRule2Body),
                (l10n.streakRule3Title, l10n.streakRule3Body),
                (l10n.streakRule4Title, l10n.streakRule4Body),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(rule.$1, style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        rule.$2,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: quiet,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar({required this.history});
  final List<StreakDayModel> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = MaterialLocalizations.of(context);
    final recent = history.length > 14
        ? history.sublist(history.length - 14)
        : history;
    if (recent.isEmpty) {
      return Text(
        AppLocalizations.of(context).streakStatusStart,
        style: theme.textTheme.bodySmall,
      );
    }
    return Column(
      children: [
        for (var row = 0; row < (recent.length / 7).ceil(); row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: row * 7 + col >= recent.length
                      ? const SizedBox.shrink()
                      : _CalendarDay(
                          day: recent[row * 7 + col],
                          local: local,
                          theme: theme,
                        ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.local,
    required this.theme,
  });
  final StreakDayModel day;
  final MaterialLocalizations local;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.isSameDay(day.date, DateTime.now());
    final primary = theme.brightness == Brightness.light
        ? Color.lerp(theme.colorScheme.primary, Colors.black, .32)!
        : theme.colorScheme.primary;
    final quiet = theme.colorScheme.onSurfaceVariant;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label:
          '${local.formatMediumDate(day.date)}, '
          '${day.logged ? l10n.streakDayLogged : l10n.streakDayEmpty}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: [
              Text(
                local.narrowWeekdays[day.date.weekday % 7],
                style: theme.textTheme.labelSmall?.copyWith(color: quiet),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(minHeight: 32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: day.logged
                      ? primary.withValues(alpha: .12)
                      : theme.colorScheme.onSurface.withValues(alpha: .035),
                  borderRadius: BorderRadius.circular(10),
                  border: today ? Border.all(color: primary, width: 1.5) : null,
                ),
                child: Text(
                  '${day.date.day}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: day.logged || today ? primary : quiet,
                    fontWeight: day.logged || today
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                day.logged ? Icons.check_rounded : Icons.remove_rounded,
                size: 12,
                color: day.logged ? primary : quiet.withValues(alpha: .5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({
    required this.days,
    required this.reached,
    required this.next,
  });
  final int days;
  final bool reached;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = reached || next
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label:
          '$days ${AppLocalizations.of(context).streakHeroLabel(days)}, '
          '${reached ? AppLocalizations.of(context).streakMilestoneReached : AppLocalizations.of(context).streakMilestoneAhead}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: reached ? color.withValues(alpha: .10) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: next ? .45 : .15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reached) ...[
                Icon(Icons.check_rounded, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                '$days',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: reached || next
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

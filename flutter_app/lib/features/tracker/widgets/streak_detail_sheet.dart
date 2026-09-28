import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/streak_model.dart';

/// Bottom-sheet body for the streak detail. Hosted via
/// `showGlassBottomSheet(...)` from `widgets/glass/glass_bottom_sheet.dart`,
/// which gives it the Liquid Glass backdrop-blur + drag handle + spring
/// slide-in — this widget contributes only the content.
///
/// Layout, top to bottom:
///
///   1. Hero — current streak + fire emoji + today's status (logged
///      today / not yet / grace). Anchors the sheet in the same number
///      the badge showed, so the user doesn't re-discover it.
///
///   2. "How to keep this going" — the actionable rules section.
///      This is the part the user actually came for when they tapped
///      the badge: what does it take to bump the streak by one each
///      day, what happens if they forget, and what's excluded.
///      Renders as a numbered list of short, plain sentences so the
///      copy is skimmable and the rules feel mechanical rather than
///      preachy.
///
///   3. Progress — slim 14-day strip + milestone bar, demoted below
///      the rules so the diagnostic context sits behind the
///      actionable guidance. The strip still answers "where am I
///      in the window?", the milestone still answers "what's the
///      next reward?", but neither one is the reason the user
///      opened the sheet.
///
/// No confetti, no achievement-unlocked moment, no notifications —
/// the spec explicitly bounds scope to the sheet.
class StreakDetailSheet extends StatelessWidget {
  const StreakDetailSheet({super.key, required this.streak});

  final StreakModel streak;

  /// Vertical padding inside the sheet body. The drag handle is
  /// rendered by `showGlassBottomSheet` itself; we leave a comfortable
  /// top gap below it so the hero number has breathing room.
  static const EdgeInsets _sheetPadding = EdgeInsets.fromLTRB(24, 12, 24, 24);

  @override
  Widget build(BuildContext context) {
    // Wrap in a scroll view so on small phone screens (or with
    // larger system text scales) the rules + progress together
    // don't overflow the available sheet height. The scroll view
    // sits inside the sheet — the drag handle on `showGlassBottomSheet`
    // still works for dismissing.
    return SingleChildScrollView(
      padding: _sheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(streak: streak),
          const SizedBox(height: 24),
          const _SectionLabel('How to keep this going'),
          const SizedBox(height: 8),
          const _RulesList(),
          const SizedBox(height: 20),
          const _SectionLabel('Progress'),
          const SizedBox(height: 12),
          _HistoryStrip(history: streak.history),
          const SizedBox(height: 16),
          _MilestoneProgress(streak: streak),
        ],
      ),
    );
  }
}

/// "🔥 N" + today's status. The hero answers "what is my streak
/// right now?" — restating the badge's number so the sheet doesn't
/// have to be opened twice to see it.
class _Hero extends StatelessWidget {
  const _Hero({required this.streak});

  final StreakModel streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String statusText;
    if (streak.currentStreak == 0) {
      statusText = 'Start a new streak by logging today.';
    } else if (streak.loggedToday) {
      statusText = "You're set for today — see you tomorrow.";
    } else {
      // Streak alive but today not yet logged — the grace-period
      // state. Call out that today still counts toward the streak,
      // so the user doesn't feel they've already lost it.
      statusText = "Today isn't logged yet — it's still alive.";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '🔥 ${streak.currentStreak}',
          // Match the calorie-ring number style (titleLarge + w700)
          // so the two "hero" reads across the app feel like a
          // coherent pair.
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.brand,
            fontSize: 32,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'day streak',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        // Today's status — sits under the number so the user can
        // tell at a glance whether they need to do something today.
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Tiny uppercase section heading — used to introduce the rules
/// block and the progress block separately. Same muted-onSurface
/// register the rest of the app uses for in-card labels.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// The actionable content. Numbered list of short rules — each
/// covers one specific behaviour the user has to know to keep
/// the streak alive. Wording stays mechanical and short on
/// purpose: the user came here to confirm the rules, not to read
/// a motivational essay.
class _RulesList extends StatelessWidget {
  const _RulesList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const rules = <_Rule>[
      _Rule(
        number: '1',
        title: 'Log at least one meal or drink each day.',
        body:
            'A food log, a water log — either counts. As long as the day '
            'has one of them, the day is logged.',
      ),
      _Rule(
        number: '2',
        title: 'Each day is your local calendar day.',
        body:
            'The streak counts in your timezone, not the server\'s. A '
            'log at 23:55 keeps the day green.',
      ),
      _Rule(
        number: '3',
        title: "If you forget a day, it's grace — not gone.",
        body:
            'Until midnight, today still counts even if you haven\'t '
            'logged yet. After one full missed day, the streak resets.',
      ),
      _Rule(
        number: '4',
        title: 'Weight logs and app opens don\'t count.',
        body:
            'Only food and water entries count toward the streak. '
            'Weighing in or opening the app doesn\'t bump it.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rules.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _RuleTile(rule: rules[i], theme: theme),
        ],
      ],
    );
  }
}

/// One rule — a numbered prefix + title (bold) + body (muted). The
/// numbered prefix gives the list a scannable mechanical feel that
/// fits the "rules" framing; bullets felt too promotional.
class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.theme});
  final _Rule rule;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The number lives in its own circle so it visually anchors
        // to a known x-position regardless of the title's length.
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.brand.withValues(alpha: 0.15),
          ),
          child: Text(
            rule.number,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rule.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rule.body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Data class for the rules table — kept as a value object so the
/// list literal above reads as documentation rather than nested
/// positional arguments.
class _Rule {
  const _Rule({required this.number, required this.title, required this.body});
  final String number;
  final String title;
  final String body;
}

/// 14-cell horizontal strip — kept as a quick diagnostic. The
/// action-focused rules above the strip are the reason the user
/// tapped; this answers "where am I in the window?" at a glance.
class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({required this.history});
  final List<StreakDayModel> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < history.length; i++)
          _DayCell(
            day: history[i],
            isToday: isSameDay(history[i].date, today),
            mutedColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            todayRingColor: theme.colorScheme.primary,
          ),
      ],
    );
  }
}

/// One circular cell in the 14-day strip. Filled brand circle when
/// logged, outlined muted circle when not. Today's cell has an
/// outer ring regardless of logged state so the user can locate
/// it.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.mutedColor,
    required this.todayRingColor,
  });

  final StreakDayModel day;
  final bool isToday;
  final Color mutedColor;
  final Color todayRingColor;

  static const double _diameter = 16;
  static const double _todayRingPadding = 4;

  @override
  Widget build(BuildContext context) {
    final fill = day.logged ? AppColors.brand : null;
    final border = day.logged ? null : mutedColor;
    final inner = Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
    );
    if (!isToday) return inner;
    return Container(
      padding: const EdgeInsets.all(_todayRingPadding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: todayRingColor, width: 1.5),
      ),
      child: inner,
    );
  }
}

/// Milestone progress. When there's a next milestone: a slim
/// progress bar styled like the macro rows + the "X / Y days"
/// caption. When there isn't (>= 365 days): a "🏆 N day streak"
/// line.
class _MilestoneProgress extends StatelessWidget {
  const _MilestoneProgress({required this.streak});

  final StreakModel streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = streak.nextMilestone;
    final daysToGo = streak.daysToNextMilestone;

    if (next == null || daysToGo == null) {
      return Center(
        child: Text(
          '🏆 ${streak.currentStreak} day streak',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.brand,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final ratio = streak.currentStreak / next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          daysToGo == 1
              ? '${streak.currentStreak} / $next day · 1 more day'
              : '${streak.currentStreak} / $next days · $daysToGo more days',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

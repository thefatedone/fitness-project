import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../widgets/glass/glass_scroll_view.dart';
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
    final l10n = AppLocalizations.of(context);
    // Wrap in a scroll view so on small phone screens (or with
    // larger system text scales) the rules + progress together
    // don't overflow the available sheet height. The scroll view
    // sits inside the sheet — the drag handle on `showGlassBottomSheet`
    // still works for dismissing.
    return GlassScrollBehavior(
      // The sheet itself uses a [BackdropFilter] in
      // [_GlassSheetBody]; if the inner scrollable bounces past
      // its boundary on iOS, the overscroll indicator gets drawn
      // over the backdrop blur, which looks like the glass is
      // "shining". [ClampingScrollPhysics] + the indicator disallow
      // keep the glass visually static through scroll. See
      // `widgets/glass/glass_scroll_view.dart` for the rationale.
      physics: const ClampingScrollPhysics(),
      child: SingleChildScrollView(
      padding: _sheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(streak: streak, l10n: l10n),
          const SizedBox(height: 24),
          _SectionLabel(l10n.streakSectionRules),
          const SizedBox(height: 8),
          _RulesList(l10n: l10n),
          const SizedBox(height: 20),
          _SectionLabel(l10n.streakSectionProgress),
          const SizedBox(height: 12),
          _HistoryStrip(history: streak.history),
          const SizedBox(height: 16),
          _MilestoneProgress(streak: streak, l10n: l10n),
        ],
      ),
      ),
    );
  }
}

/// "🔥 N" + today's status. The hero answers "what is my streak
/// right now?" — restating the badge's number so the sheet doesn't
/// have to be opened twice to see it.
class _Hero extends StatelessWidget {
  const _Hero({required this.streak, required this.l10n});

  final StreakModel streak;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String statusText;
    if (streak.currentStreak == 0) {
      statusText = l10n.streakStatusStart;
    } else if (streak.loggedToday) {
      statusText = l10n.streakStatusDone;
    } else {
      // Streak alive but today not yet logged — the grace-period
      // state. Call out that today still counts toward the streak,
      // so the user doesn't feel they've already lost it.
      statusText = l10n.streakStatusPending;
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
          l10n.streakHeroLabel(streak.currentStreak),
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
///
/// The list is built inside [build] (not `const`) because the
/// titles and bodies come from [AppLocalizations], which needs a
/// [BuildContext]. The numeric prefix (1..4) stays a plain digit
/// string — it isn't localized.
class _RulesList extends StatelessWidget {
  const _RulesList({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = <_Rule>[
      _Rule(
        number: '1',
        title: l10n.streakRule1Title,
        body: l10n.streakRule1Body,
      ),
      _Rule(
        number: '2',
        title: l10n.streakRule2Title,
        body: l10n.streakRule2Body,
      ),
      _Rule(
        number: '3',
        title: l10n.streakRule3Title,
        body: l10n.streakRule3Body,
      ),
      _Rule(
        number: '4',
        title: l10n.streakRule4Title,
        body: l10n.streakRule4Body,
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
/// trophy line.
class _MilestoneProgress extends StatelessWidget {
  const _MilestoneProgress({required this.streak, required this.l10n});

  final StreakModel streak;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = streak.nextMilestone;
    final daysToGo = streak.daysToNextMilestone;

    if (next == null || daysToGo == null) {
      return Center(
        child: Text(
          l10n.streakTrophyLabel(streak.currentStreak),
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
          // Pass `daysToGo` (already computed by the server) as the
          // `daysLeft` ICU plural variable. Server returns this as the
          // exact number of days remaining to the next milestone (e.g.
          // 3 for streak 4 / milestone 7). The plural picks the
          // Russian/English form automatically.
          l10n.streakMilestoneProgress(
            streak.currentStreak,
            next,
            daysToGo,
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

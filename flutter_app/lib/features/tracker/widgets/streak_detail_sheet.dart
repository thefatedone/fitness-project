import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/streak_model.dart';

/// Bottom-sheet body for the streak detail. Hosted via
/// `showGlassBottomSheet(...)` from `widgets/glass/glass_bottom_sheet.dart`,
/// which gives it the Liquid Glass backdrop-blur + drag handle + spring
/// slide-in — this widget contributes only the content.
///
/// Layout, top to bottom:
///   1. Big streak number + fire emoji, in the same `titleLarge + w700`
///      type scale the calorie hero number uses on the Today screen.
///   2. 14-day history strip — a `Row` of 14 small circular cells,
///      oldest left, today right. Logged = filled brand circle,
///      unlogged = outlined muted circle. Today's cell has a
///      distinct outer ring regardless of logged state so the user
///      can always locate it.
///   3. Milestone progress — slim `LinearProgressIndicator` styled
///      like the macro rows, or a trophy line when the user has
///      already passed the largest defined milestone.
///   4. Plain one-line caption explaining how the streak works.
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
    return Padding(
      padding: _sheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroNumber(streak: streak),
          const SizedBox(height: 24),
          _HistoryStrip(history: streak.history),
          const SizedBox(height: 24),
          _MilestoneProgress(streak: streak),
          const SizedBox(height: 16),
          _Caption(loggedToday: streak.loggedToday),
        ],
      ),
    );
  }
}

/// "🔥 N" big number — matches the calorie ring's type scale (titleLarge
/// + w700) so the two "hero" reads across the app feel like a coherent
/// pair rather than two unrelated number systems.
class _HeroNumber extends StatelessWidget {
  const _HeroNumber({required this.streak});

  final StreakModel streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '🔥 ${streak.currentStreak}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.brand,
            fontSize: 32,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          streak.currentStreak == 1 ? 'day streak' : 'day streak',
          // Same style/colour as the calorie ring's "%" caption —
          // small, muted, anchors the big number without competing.
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 14 circular cells, oldest left, today right. Today's cell wears a
/// distinct outer ring so the user can locate it without counting.
class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({required this.history});

  final List<StreakDayModel> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    // Index 13 is today (server-aligned — see StreakModel.history
    // doc). Compare on the year/month/day triple, not via `isAtSameMomentAs`,
    // because the server emits `YYYY-MM-DD` (date-only) which parses
    // to local midnight.
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < history.length; i++)
          _DayCell(
            day: history[i],
            isToday: isSameDay(history[i].date, today),
            // The muted tone mirrors GlassChip's unselected border
            // alpha — same visual register as the rest of the app's
            // "off" states, so the strip doesn't introduce a new
            // color it just happens to use.
            mutedColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            todayRingColor: theme.colorScheme.primary,
          ),
      ],
    );
  }
}

/// One circular cell in the 14-day strip. Filled brand circle when
/// logged, outlined muted circle when not. Today's cell has an
/// outer ring regardless of logged state so it stands out.
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

  /// Visual diameter for each cell. Tighter than the chip so the
  /// strip reads as a strip of dots, not a row of buttons.
  static const double _diameter = 16;

  /// Padding around today's outer ring, sized to match [_diameter].
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
    // Today's cell: wrap the dot in a transparent "ring" container
    // so the user can pick it out without counting from the right.
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

/// Milestone progress. When there's a next milestone: a slim progress
/// bar styled like the macro rows. When there isn't (>= 365 days): a
/// "🏆 N day streak" line — no division by a null milestone.
class _MilestoneProgress extends StatelessWidget {
  const _MilestoneProgress({required this.streak});

  final StreakModel streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = streak.nextMilestone;
    final daysToGo = streak.daysToNextMilestone;

    if (next == null || daysToGo == null) {
      // Past the largest milestone — celebrate without a numeric
      // progress target. The trophy reads as "you've made it" rather
      // than "keep going".
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
        // Slim bar mirrors the macro-row `LinearProgressIndicator`
        // recipe so a user scrolling between screens sees a consistent
        // "progress primitive" everywhere. `valueColor` is `brand`
        // (not `primary`) because the streak is a brand-toned counter.
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
        // Caption: "{current} / {next} days". On the last day before
        // the milestone ("1 more day") the singular reads naturally
        // thanks to the natural-language adjustment below.
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

/// One-line, plain-text caption explaining how the streak is sustained.
/// No exclamation marks, no "don't break your streak!" framing —
/// matches the app's existing restraint on copy.
class _Caption extends StatelessWidget {
  const _Caption({required this.loggedToday});

  final bool loggedToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      loggedToday
          // Today's done — encourage continuity without sounding
          // urgent.
          ? 'Come back tomorrow to keep it going.'
          // Today still empty — neutral phrasing, no guilt framing.
          : 'Log any meal or water once a day to keep this going.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

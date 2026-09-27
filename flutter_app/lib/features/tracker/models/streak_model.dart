/// One cell in the 14-day streak history strip rendered in the
/// detail bottom sheet. Maps 1-to-1 with the `StreakDayEntry`
/// schema on the backend.
class StreakDayModel {
  /// Local-calendar date for this cell. The detail sheet's strip
  /// renders cells oldest → newest left → right, so the cell at
  /// index 13 of `StreakModel.history` is "today".
  final DateTime date;

  /// `true` if any food or water entry exists for this date.
  /// The detail sheet renders `logged: true` cells as filled
  /// `AppColors.brand` circles and `logged: false` cells as
  /// outlined/muted circles.
  final bool logged;

  const StreakDayModel({required this.date, required this.logged});

  factory StreakDayModel.fromJson(Map<String, dynamic> json) {
    return StreakDayModel(
      // Server emits `YYYY-MM-DD`; we parse at local midnight so
      // date-only comparisons against `DateTime.now()` work
      // without timezone surprises.
      date: DateTime.parse(json['date'] as String),
      logged: json['logged'] as bool,
    );
  }
}

/// Immutable representation of the user's current diary-streak
/// snapshot, as returned by `GET /api/v1/tracker/streak`.
///
/// Single responsibility: parse the snake_case JSON payload
/// (`StreakResponse` from the tracker router) into a typed Dart
/// value. The streak is *computed server-side* from existing
/// `food_logs` / `water_logs` rows on every request (no separate
/// stored counter), so the model is always self-consistent with
/// the underlying log data.
///
/// The detail-screen fields (`history`, `nextMilestone`,
/// `daysToNextMilestone`) were added alongside the bottom-sheet
/// UI in a follow-up; the sheet reads them directly off the same
/// model the badge reads from.
class StreakModel {
  /// Number of consecutive calendar days, ending today (or
  /// yesterday, under the grace period — see the
  /// `logged_today` flag) that have at least one food or water
  /// entry. `0` means the streak is broken: neither today nor
  /// yesterday had any diary activity.
  final int currentStreak;

  /// Whether today's local calendar day has at least one food
  /// or water entry. The counter is unchanged across this flag
  /// flipping — only the surface treatment of the UI badge
  /// changes (the "alive today" vs "still alive, log to keep"
  /// states).
  final bool loggedToday;

  /// The last 14 calendar days ending on today, oldest first
  /// (`history[0]` is `today - 13` days, `history.last` is
  /// today). Always inclusive of today regardless of the
  /// grace-period anchor used for [currentStreak] — the strip
  /// represents the real calendar, not the streak count.
  ///
  /// Used by the detail bottom sheet to render the 14-day
  /// history strip. Empty/short streaks still show all 14
  /// entries (most of them `logged: false`).
  final List<StreakDayModel> history;

  /// The smallest milestone strictly greater than
  /// [currentStreak] from the product-defined ladder
  /// (3, 7, 14, 30, 60, 100, 365). `null` once the user has
  /// met or passed the largest milestone — the sheet then
  /// renders a "🏆 N day streak" line instead of a progress
  /// bar.
  final int? nextMilestone;

  /// `nextMilestone - currentStreak` when [nextMilestone] is
  /// non-null; `null` alongside a `null` [nextMilestone].
  /// Renders as the "X more days" caption on the sheet.
  final int? daysToNextMilestone;

  const StreakModel({
    required this.currentStreak,
    required this.loggedToday,
    required this.history,
    required this.nextMilestone,
    required this.daysToNextMilestone,
  });

  /// Builds a [StreakModel] from the `StreakResponse` JSON.
  /// Snake-case → camelCase mapping mirrors the conversion pattern
  /// used by every other model in `features/tracker/models/`.
  factory StreakModel.fromJson(Map<String, dynamic> json) {
    final historyRaw = (json['history'] as List?) ?? const [];
    return StreakModel(
      currentStreak: (json['current_streak'] as num).toInt(),
      loggedToday: json['logged_today'] as bool,
      history: historyRaw
          .cast<Map<String, dynamic>>()
          .map(StreakDayModel.fromJson)
          .toList(growable: false),
      nextMilestone: json['next_milestone'] as int?,
      daysToNextMilestone: json['days_to_next_milestone'] as int?,
    );
  }
}

/// Immutable representation of the user's current diary-streak
/// snapshot, as returned by `GET /api/v1/tracker/streak`.
///
/// Single responsibility: parse the snake_case JSON payload
/// (`StreakResponse` from the tracker router) into a typed Dart
/// value. The streak is *computed server-side* from existing
/// `food_logs` / `water_logs` rows on every request (no separate
/// stored counter), so the model is always self-consistent with
/// the underlying log data.
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

  const StreakModel({
    required this.currentStreak,
    required this.loggedToday,
  });

  /// Builds a [StreakModel] from the `StreakResponse` JSON.
  /// Snake-case → camelCase mapping mirrors the conversion pattern
  /// used by every other model in `features/tracker/models/`.
  factory StreakModel.fromJson(Map<String, dynamic> json) {
    return StreakModel(
      currentStreak: (json['current_streak'] as num).toInt(),
      loggedToday: json['logged_today'] as bool,
    );
  }
}

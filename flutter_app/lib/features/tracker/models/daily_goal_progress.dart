/// Product tolerance for diary feedback, not a nutrition recommendation.
/// Values are recomputed from the selected day's actual log and profile goals.
class DailyGoalProgress {
  const DailyGoalProgress({required this.consumed, required this.target});

  final double consumed;
  final double? target;
  static const tolerance = .10;

  bool get isConfigured => target != null && target!.isFinite && target! > 0;
  bool get hasValidIntake => consumed.isFinite && consumed >= 0;
  double get lowerBound => isConfigured ? target! * (1 - tolerance) : 0;
  double get upperBound => isConfigured ? target! * (1 + tolerance) : 0;
  bool get isInRange =>
      isConfigured &&
      hasValidIntake &&
      consumed >= lowerBound - 1e-8 &&
      consumed <= upperBound + 1e-8;
  bool get isAboveRange =>
      isConfigured && hasValidIntake && consumed > upperBound + 1e-8;
  double get progress =>
      isConfigured && hasValidIntake ? (consumed / target!).clamp(0.0, 1.0) : 0;
}

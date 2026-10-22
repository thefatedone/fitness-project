class GardenDay {
  const GardenDay({required this.date, required this.earned});
  final DateTime date;
  final bool earned;
}

class GardenModel {
  const GardenModel({
    required this.today,
    required this.totalDays,
    required this.loggedToday,
    required this.weekDays,
    required this.potUnlocked,
  });
  final DateTime today;
  final int totalDays;
  final bool loggedToday;
  final List<GardenDay> weekDays;
  final bool potUnlocked;

  static const thresholds = [0, 3, 7, 14, 21];
  int get grownTrees => totalDays ~/ 21;
  // Keep the mature tree visible on the day it is completed.
  int get growthDays => totalDays == 0 ? 0 : (totalDays - 1) % 21 + 1;
  int get stage => thresholds.lastIndexWhere((day) => growthDays >= day);
  int get nextThreshold => stage < 4 ? thresholds[stage + 1] : 21;
  int get daysToNextStage => nextThreshold - growthDays;
  double get stageProgress => stage == 4
      ? 1
      : (growthDays - thresholds[stage]) / (nextThreshold - thresholds[stage]);
  int get weekCount => weekDays.where((day) => day.earned).length;
  bool get weeklyComplete => weekCount >= 4;

  factory GardenModel.fromJson(Map<String, dynamic> json) => GardenModel(
    today: DateTime.parse(json['today'] as String),
    totalDays: (json['total_days'] as num).toInt(),
    loggedToday: json['logged_today'] as bool,
    potUnlocked: json['pot_unlocked'] as bool,
    weekDays: (json['week_days'] as List)
        .map(
          (item) => GardenDay(
            date: DateTime.parse(item['date'] as String),
            earned: item['earned'] as bool,
          ),
        )
        .toList(growable: false),
  );
}

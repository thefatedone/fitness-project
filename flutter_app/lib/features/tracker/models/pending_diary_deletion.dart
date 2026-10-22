import 'food_log_model.dart';
import 'water_log_model.dart';

class PendingDiaryDeletion {
  final String id;
  final List<FoodLogModel> foods;
  final List<WaterLogModel> water;
  final DateTime undoUntil;
  final bool restore;
  final bool confirmed;
  const PendingDiaryDeletion({
    required this.id,
    required this.foods,
    required this.water,
    required this.undoUntil,
    this.restore = false,
    this.confirmed = false,
  });

  PendingDiaryDeletion copyWith({
    bool? restore,
    bool? confirmed,
    DateTime? undoUntil,
  }) => PendingDiaryDeletion(
    id: id,
    foods: foods,
    water: water,
    undoUntil: undoUntil ?? this.undoUntil,
    restore: restore ?? this.restore,
    confirmed: confirmed ?? this.confirmed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'foods': foods.map((v) => v.toCacheJson()).toList(),
    'water': water.map((v) => v.toCacheJson()).toList(),
    'undo_until': undoUntil.toIso8601String(),
    'restore': restore,
    'confirmed': confirmed,
  };
  factory PendingDiaryDeletion.fromJson(
    Map<String, dynamic> json,
  ) => PendingDiaryDeletion(
    id: json['id'] as String,
    foods: (json['foods'] as List)
        .map((v) => FoodLogModel.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    water: (json['water'] as List)
        .map((v) => WaterLogModel.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    undoUntil: DateTime.parse(json['undo_until'] as String),
    restore: json['restore'] as bool,
    confirmed: json['confirmed'] as bool,
  );
  Map<String, dynamic> toRequest() => {
    'id': id,
    'food_ids': foods.map((v) => v.id).toList(),
    'water_ids': water.map((v) => v.id).toList(),
    'restore': restore,
  };
}

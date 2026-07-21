/// Immutable representation of a single water-intake entry as returned by
/// `GET /api/v1/tracker/water` and `POST /api/v1/tracker/water`.
///
/// Single responsibility: parse the `WaterLogResponse` JSON into a typed
/// Dart value. Writes (POSTs) are constructed inline by `TrackerApi.addWater`
/// because they only need `date` + `amount` — there's no rich payload.
class WaterLogModel {
  /// Server-assigned UUID.
  final String id;

  /// Owning user's UUID.
  final String userId;

  /// When the water was logged (ISO 8601 on the wire, DateTime in the model).
  final DateTime date;

  /// Volume in millilitres.
  final int amount;

  /// Server-side creation timestamp.
  final DateTime createdAt;

  const WaterLogModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.amount,
    required this.createdAt,
  });

  /// Builds a [WaterLogModel] from the `WaterLogResponse` JSON.
  factory WaterLogModel.fromJson(Map<String, dynamic> json) {
    return WaterLogModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

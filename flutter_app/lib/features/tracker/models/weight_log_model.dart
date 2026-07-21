/// Immutable representation of a single weight entry as returned by
/// `GET /api/v1/tracker/weight` and `POST /api/v1/tracker/weight`.
///
/// Single responsibility: parse `WeightLogResponse` JSON into a typed Dart
/// value. Note that the *history* endpoint (`WeightHistoryEntry`) returns
/// a different shape — `date` is a plain `"yyyy-MM-dd"` string, not a full
/// ISO datetime — so it has its own dedicated class below.
class WeightLogModel {
  /// Server-assigned UUID.
  final String id;

  /// Owning user's UUID.
  final String userId;

  /// When the weight was logged.
  final DateTime date;

  /// Body weight in kilograms.
  final double weight;

  /// Optional free-text note (e.g. `"morning, before breakfast"`).
  final String? note;

  /// Server-side creation timestamp.
  final DateTime createdAt;

  const WeightLogModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.weight,
    required this.createdAt,
    this.note,
  });

  /// Builds a [WeightLogModel] from the `WeightLogResponse` JSON.
  factory WeightLogModel.fromJson(Map<String, dynamic> json) {
    return WeightLogModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      weight: (json['weight'] as num).toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// One row of `GET /api/v1/tracker/weight/history`.
///
/// `date` here is *intentionally* kept as a `String` in `"yyyy-MM-dd"`
/// format — the backend's `WeightLogHistoryResponse` schema pins it that
/// way, and there is no timezone attached. Parsing it into a [DateTime]
/// would invent a timezone that the wire doesn't carry, so the consumer
/// renders it as-is.
class WeightHistoryEntry {
  /// Server-assigned UUID.
  final String id;

  /// Day the weight was logged, formatted as `yyyy-MM-dd`.
  final String date;

  /// Body weight in kilograms.
  final double weight;

  /// Optional free-text note. `null` when absent.
  final String? note;

  const WeightHistoryEntry({
    required this.id,
    required this.date,
    required this.weight,
    this.note,
  });

  /// Builds a [WeightHistoryEntry] from the `WeightLogHistoryResponse` JSON.
  factory WeightHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WeightHistoryEntry(
      id: json['id'] as String,
      date: json['date'] as String,
      weight: (json['weight'] as num).toDouble(),
      note: json['note'] as String?,
    );
  }
}

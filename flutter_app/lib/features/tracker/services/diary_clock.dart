/// Device calendar days, independent of language or country. Historical diary
/// dates stay attached to the day on which the user recorded them.
class DiaryClock {
  int _day;
  Duration _offset;
  String _zone;

  DiaryClock(DateTime now)
    : _day = dayKey(now),
      _offset = now.timeZoneOffset,
      _zone = now.timeZoneName;

  static int dayKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  /// Null means no clock change. Follow today only if it was being viewed.
  DateTime? observe(DateTime now, DateTime selected) {
    final day = dayKey(now);
    if (day == _day &&
        _offset == now.timeZoneOffset &&
        _zone == now.timeZoneName) {
      return null;
    }
    final followToday = dayKey(selected) == _day;
    _day = day;
    _offset = now.timeZoneOffset;
    _zone = now.timeZoneName;
    return followToday ? DateTime(now.year, now.month, now.day) : selected;
  }

  static DateTime shiftDay(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static Duration nextCheck(DateTime now) {
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);
    return remaining < const Duration(seconds: 30)
        ? remaining
        : const Duration(seconds: 30);
  }
}

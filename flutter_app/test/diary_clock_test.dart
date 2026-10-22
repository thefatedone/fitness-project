import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/features/tracker/services/diary_clock.dart';

class _ZoneSample extends Fake implements DateTime {
  @override
  final int year = 2026;
  @override
  final int month = 10;
  @override
  final int day = 21;
  @override
  final Duration timeZoneOffset;
  @override
  final String timeZoneName;
  _ZoneSample(int hours, this.timeZoneName)
    : timeZoneOffset = Duration(hours: hours);
}

void main() {
  test('timezone and DST changes refresh even without a calendar change', () {
    final clock = DiaryClock(_ZoneSample(4, 'GET'));
    final selected = DateTime(2026, 10, 21);
    expect(clock.observe(_ZoneSample(3, 'EEST'), selected), selected);
    expect(clock.observe(_ZoneSample(3, 'EEST'), selected), isNull);
    expect(clock.observe(_ZoneSample(2, 'EET'), selected), selected);
  });
  test('today follows local midnight, including month/year change', () {
    final clock = DiaryClock(DateTime(2026, 12, 31, 23, 59));
    expect(
      clock.observe(DateTime(2027, 1, 1), DateTime(2026, 12, 31)),
      DateTime(2027, 1, 1),
    );
    expect(
      clock.observe(DateTime(2027, 1, 1, 9), DateTime(2027, 1, 1)),
      isNull,
    );
  });
  test(
    'historical selection survives midnight and travel in either direction',
    () {
      final clock = DiaryClock(DateTime(2026, 10, 21, 23));
      final history = DateTime(2026, 10, 10);
      expect(clock.observe(DateTime(2026, 10, 22), history), history);
      expect(clock.observe(DateTime(2026, 10, 21, 20), history), history);
    },
  );
  test('today follows a region whose local calendar is still yesterday', () {
    final clock = DiaryClock(DateTime(2026, 10, 22, 1));
    expect(
      clock.observe(DateTime(2026, 10, 21, 18), DateTime(2026, 10, 22)),
      DateTime(2026, 10, 21),
    );
  });
  test('schedule reaches local midnight exactly and checks zone changes', () {
    expect(
      DiaryClock.nextCheck(DateTime(2026, 10, 21, 23, 59, 59)),
      const Duration(seconds: 1),
    );
    expect(
      DiaryClock.nextCheck(DateTime(2026, 10, 21, 12)),
      const Duration(seconds: 30),
    );
  });
  test('calendar navigation remains at midnight across DST changes', () {
    for (final day in [DateTime(2026, 3, 8), DateTime(2026, 11, 1)]) {
      final next = DiaryClock.shiftDay(day, 1);
      expect(next.hour, 0);
      expect(next.day, day.day + 1);
      expect(DiaryClock.shiftDay(next, -1), day);
    }
  });
}

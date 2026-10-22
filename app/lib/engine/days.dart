/// Study days. A new day starts at 04:00 local time (RES-47 §5.6), so a late-night session still
/// counts for the evening it belongs to.
const int dayRolloverHour = 4;
const int msPerDay = 86400000;
const int msPerHour = 3600000;

/// Whole study days since 1970 for a local timestamp.
int dayNumber(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms).subtract(const Duration(hours: dayRolloverHour));
  return DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ msPerDay;
}

/// "2026-10-22" for a study day number.
String dayKey(int day) {
  final d = DateTime.fromMillisecondsSinceEpoch(day * msPerDay, isUtc: true);
  return '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

int dayFromKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]).millisecondsSinceEpoch ~/ msPerDay;
}

/// Weekday of a study day, 1 = Monday … 7 = Sunday.
int weekdayOf(int day) => DateTime.fromMillisecondsSinceEpoch(day * msPerDay, isUtc: true).weekday;

/// Whole study days between two timestamps (what FSRS calls elapsed days).
int elapsedStudyDays(int fromMs, int toMs) => dayNumber(toMs) - dayNumber(fromMs);

String _two(int v) => v < 10 ? '0$v' : '$v';

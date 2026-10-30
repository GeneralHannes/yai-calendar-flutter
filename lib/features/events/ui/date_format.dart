import '../data/calendar_event.dart';

const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String two(int n) => n.toString().padLeft(2, '0');

/// Midnight of [d] in local time.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "09:00–10:00", or "All day".
String timeRange(CalendarEvent e) {
  if (e.allDay) return 'All day';
  final s = e.start.toLocal(), t = e.end.toLocal();
  return '${two(s.hour)}:${two(s.minute)}–${two(t.hour)}:${two(t.minute)}';
}

/// "Friday, 30 October".
String dayLabel(DateTime d) =>
    '${weekdayNames[d.weekday - 1]}, ${d.day} ${monthNames[d.month - 1]}';

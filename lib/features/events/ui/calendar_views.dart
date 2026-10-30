import 'package:flutter/material.dart';

import '../../../core/theme/yai_theme.dart';
import '../data/calendar_event.dart';
import 'date_format.dart';

/// Events bucketed by local day, each day sorted by start time.
Map<DateTime, List<CalendarEvent>> groupByDay(List<CalendarEvent> events) {
  final out = <DateTime, List<CalendarEvent>>{};
  for (final e in events) {
    out.putIfAbsent(dayOf(e.start.toLocal()), () => []).add(e);
  }
  for (final l in out.values) {
    l.sort((a, b) => a.start.compareTo(b.start));
  }
  return out;
}

/// Journal-style section heading: small gold caps with wide tracking.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        color: c.gold,
      ),
    );
  }
}

/// Month grid, Monday first: no boxes, just hairlines between weeks. Today is
/// a gold disc, the selected day a ringed one.
/// Each day shows its event titles as small tinted chips; extra events
/// collapse into "+N".
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.events,
    required this.selected,
    required this.onDayTap,
    this.fill = false,
  });

  /// Stretch the cells to fill the available height (desktop) instead of a
  /// size based on the width (phones, inside a scroll view).
  final bool fill;

  final DateTime month;
  final List<CalendarEvent> events;
  final DateTime selected;
  final ValueChanged<DateTime> onDayTap;

  static const _dow = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _headerHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    final byDay = groupByDay(events);
    final first = DateTime(month.year, month.month);
    final lead = first.weekday - 1;
    final start = DateTime(first.year, first.month, 1 - lead);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((lead + days) / 7).ceil();
    DateTime dateAt(int w, int d) =>
        DateTime(start.year, start.month, start.day + w * 7 + d);
    final line = c.ink.withValues(alpha: .14);

    return LayoutBuilder(
      builder: (context, box) {
        final cellHeight = fill && box.hasBoundedHeight
            ? ((box.maxHeight - _headerHeight - weeks) / weeks)
                .clamp(72.0, 220.0)
            : (box.maxWidth / 7 * 1.45).clamp(72.0, 130.0);
        return Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  for (final d in _dow)
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (var w = 0; w < weeks; w++)
              DecoratedBox(
                key: ValueKey('${month.year}-${month.month}-$w'),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: line)),
                ),
                child: Row(
                  children: [
                    for (var d = 0; d < 7; d++)
                      Expanded(
                        child: _FadeIn(
                          delay: (w * 7 + d) * 8,
                          child: SizedBox(
                            height: cellHeight,
                            child: _DayCell(
                              day: dateAt(w, d),
                              inMonth: dateAt(w, d).month == month.month,
                              selected: selected,
                              events: byDay[dateAt(w, d)] ?? const [],
                              onTap: onDayTap,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Container(height: 1, color: line),
          ],
        );
      },
    );
  }
}

/// Cells fade in one after another when a month appears.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.delay, required this.child});

  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + delay),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.events,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final DateTime selected;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onTap;

  static const _chipHeight = 15.0;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    final isToday = sameDay(day, DateTime.now());
    final isSelected = sameDay(day, selected);
    // Roomier desktop cells get slightly larger type.
    final scale = MediaQuery.sizeOf(context).width >= 900 ? 1.25 : 1.0;

    // Today: gold disc. Selected: accent ring. Otherwise plain.
    final disc = isToday ? c.gold : null;
    final numberColor =
        isToday ? c.bg1 : (inMonth ? c.ink : c.muted.withValues(alpha: .6));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(day),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 5, 2, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                constraints: BoxConstraints(
                  minWidth: 26 * scale,
                  minHeight: 26 * scale,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: disc,
                  borderRadius: BorderRadius.circular(16 * scale),
                  border: isSelected && !isToday
                      ? Border.all(color: c.act, width: 1.5)
                      : null,
                ),
                // widthFactor keeps the disc hugging the digits.
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: numberColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Expanded(child: _titles(c, scale)),
          ],
        ),
      ),
    );
  }

  Widget _titles(YaiPalette c, double scale) {
    if (events.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final chipHeight = _chipHeight * scale;
        final fit = (box.maxHeight / (chipHeight + 2)).floor();
        final overflow = events.length > fit;
        final shown =
            overflow ? (fit - 1).clamp(0, events.length) : events.length;
        return ClipRect(
          child: Opacity(
            opacity: inMonth ? 1 : .55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in events.take(shown))
                  Container(
                    height: chipHeight,
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: c.act.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10 * scale,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: c.act,
                      ),
                    ),
                  ),
                if (events.length - shown > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Text(
                      '+${events.length - shown}',
                      style: TextStyle(
                        fontSize: 10 * scale,
                        height: 1,
                        color: c.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One event, as in Apple's day list: start and end time, a calendar-coloured
/// bar, then title and location. Swipe left to delete.
class EventTile extends StatelessWidget {
  const EventTile({
    super.key,
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    final s = event.start.toLocal(), t = event.end.toLocal();
    final times = event.allDay
        ? [Text('all-day', style: TextStyle(fontSize: 14, color: c.ink))]
        : [
            Text(
              '${two(s.hour)}:${two(s.minute)}',
              style: TextStyle(fontSize: 15, color: c.ink),
            ),
            Text(
              '${two(t.hour)}:${two(t.minute)}',
              style: TextStyle(fontSize: 14, color: c.muted),
            ),
          ];
    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: c.bad,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: c.bg1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: times,
                  ),
                ),
                Container(
                  width: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: c.act,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      if ((event.location ?? '').isNotEmpty)
                        Text(
                          event.location!,
                          style: TextStyle(fontSize: 14, color: c.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain list of [EventTile]s separated by hairlines.
class EventPanel extends StatelessWidget {
  const EventPanel({
    super.key,
    required this.events,
    required this.onTap,
    required this.onDelete,
  });

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onTap;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    return Column(
      children: [
        for (final (i, e) in events.indexed) ...[
          if (i > 0) Divider(height: 1, color: c.ink.withValues(alpha: .12)),
          EventTile(
            event: e,
            onTap: () => onTap(e),
            onDelete: () => onDelete(e.id),
          ),
        ],
      ],
    );
  }
}

/// Upcoming events, grouped under a heading per day.
class UpNextList extends StatelessWidget {
  const UpNextList({
    super.key,
    required this.events,
    required this.onTap,
    required this.onDelete,
  });

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onTap;
  final Future<void> Function(String id) onDelete;

  static String? _relative(DateTime day) {
    final diff = day.difference(dayOf(DateTime.now())).inDays;
    return switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    final groups = groupByDay(events);
    final days = groups.keys.toList()..sort();
    if (days.isEmpty) {
      return Text('Nothing coming up.', style: TextStyle(color: c.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: dayLabel(day)),
                  if (_relative(day) case final rel?)
                    TextSpan(
                      text: '  ·  $rel',
                      style: TextStyle(
                        color: c.muted,
                      ),
                    ),
                ],
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
          EventPanel(events: groups[day]!, onTap: onTap, onDelete: onDelete),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

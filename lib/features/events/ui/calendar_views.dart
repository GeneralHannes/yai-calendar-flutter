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

/// Month grid, Monday first. Tap a day to select it. Each day shows its
/// event titles (one line each); extra events collapse into "+N".
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.events,
    required this.selected,
    required this.onDayTap,
  });

  final DateTime month;
  final List<CalendarEvent> events;
  final DateTime selected;
  final ValueChanged<DateTime> onDayTap;

  static const _dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _gap = 4.0;

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

    return LayoutBuilder(
      builder: (context, box) {
        // Cells grow with the width, within sensible limits.
        final cellHeight = (box.maxWidth / 7 * 1.05).clamp(64.0, 110.0);
        return Column(
          spacing: _gap,
          children: [
            Row(
              spacing: _gap,
              children: [
                for (final d in _dow)
                  Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(fontSize: 12, color: c.muted),
                      ),
                    ),
                  ),
              ],
            ),
            for (var w = 0; w < weeks; w++)
              Row(
                spacing: _gap,
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
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
                ],
              ),
          ],
        );
      },
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

  static const _chipHeight = 16.0;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    final isToday = sameDay(day, DateTime.now());
    final isSelected = sameDay(day, selected);

    return Opacity(
      opacity: inMonth ? 1 : .4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(day),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? c.act.withValues(alpha: .16) : c.bg2,
            borderRadius: BorderRadius.circular(8),
            // Journal rings: gold for today, accent for a day with something
            // planned, a plain hairline otherwise.
            border: Border.all(
              color: isSelected
                  ? c.act
                  : isToday
                      ? c.gold
                      : events.isNotEmpty
                          ? c.act.withValues(alpha: .45)
                          : c.ink.withValues(alpha: .1),
              width: isSelected || isToday ? 1.5 : 1,
            ),
            boxShadow: [
              if (isToday)
                BoxShadow(color: c.gold.withValues(alpha: .3), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(
                        color: c.gold,
                        borderRadius: BorderRadius.circular(11),
                      )
                    : null,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? c.bg1 : c.ink,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Expanded(child: _titles(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titles(YaiPalette c) {
    if (events.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final fit = (box.maxHeight / (_chipHeight + 2)).floor();
        final overflow = events.length > fit;
        final shown =
            overflow ? (fit - 1).clamp(0, events.length) : events.length;
        return ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in events.take(shown))
                Container(
                  height: _chipHeight,
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: c.act.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, height: 1, color: c.act),
                  ),
                ),
              if (events.length - shown > 0)
                Text(
                  '+${events.length - shown}',
                  style: TextStyle(fontSize: 10, height: 1, color: c.muted),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One event: time, title, location. Swipe left to delete.
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
    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: c.bad.withValues(alpha: .25),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete_outline, color: c.bad),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  timeRange(event),
                  style: TextStyle(fontSize: 13, height: 1.4, color: c.muted),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    if ((event.location ?? '').isNotEmpty)
                      Text(
                        event.location!,
                        style: TextStyle(fontSize: 12, color: c.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bordered list of [EventTile]s.
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
    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.ink.withValues(alpha: .1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, e) in events.indexed) ...[
            if (i > 0) Divider(height: 1, color: c.ink.withValues(alpha: .1)),
            EventTile(
              event: e,
              onTap: () => onTap(e),
              onDelete: () => onDelete(e.id),
            ),
          ],
        ],
      ),
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
                        color: rel == 'Today' ? c.warn : c.act,
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

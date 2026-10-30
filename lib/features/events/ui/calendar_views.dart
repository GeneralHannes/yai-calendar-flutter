import 'dart:math' as math;

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

/// A stable rainbow colour per event, from the bifrost palette.
Color eventColor(String id) =>
    YaiPalette.bifrost[id.hashCode.abs() % YaiPalette.bifrost.length];

/// Journal-style section heading: small gold caps with wide tracking.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 2,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(colors: [
              for (final x in YaiPalette.bifrost) x.withValues(alpha: .85),
            ]),
          ),
        ),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: c.gold,
          ),
        ),
      ],
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
    this.fill = false,
  });

  /// Stretch the cells to fill the available height (desktop) instead of a
  /// size based on the width (phones, inside a scroll view).
  final bool fill;

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
        final cellHeight = fill && box.hasBoundedHeight
            ? ((box.maxHeight - 24 - _gap * weeks) / weeks).clamp(64.0, 220.0)
            : (box.maxWidth / 7 * 1.05).clamp(64.0, 110.0);
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
                key: ValueKey('${month.year}-${month.month}-$w'),
                spacing: _gap,
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: _FadeIn(
                        delay: (w * 7 + d) * 14,
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
          ],
        );
      },
    );
  }
}

/// Cells rise and fade in one after another when a month appears.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.delay, required this.child});

  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
      ),
      child: child,
    );
  }
}

/// A light that circles today's border, like the journal's border beam.
class _Beam extends StatefulWidget {
  const _Beam({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  State<_Beam> createState() => _BeamState();
}

class _BeamState extends State<_Beam> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) => CustomPaint(
            painter: _BeamPainter(_t.value, widget.color, widget.radius),
          ),
        ),
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter(this.t, this.color, this.radius);

  final double t;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    final shader = SweepGradient(
      transform: GradientRotation(t * 2 * math.pi),
      colors: [
        Colors.transparent,
        Colors.transparent,
        color.withValues(alpha: .0),
        color,
        Colors.white.withValues(alpha: .9),
        Colors.transparent,
      ],
      stops: const [0, .55, .7, .9, .96, 1],
    ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_BeamPainter old) => old.t != t || old.color != color;
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
    // Roomier desktop cells get slightly larger type.
    final scale = MediaQuery.sizeOf(context).width >= 900 ? 1.25 : 1.0;

    final cell = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(day),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? c.act.withValues(alpha: .16) : null,
          gradient: isSelected
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.bg2,
                    Color.alphaBlend(
                      (isToday ? c.warn : c.act).withValues(alpha: .07),
                      c.bg2,
                    ),
                  ],
                ),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: 22 * scale,
                  minHeight: 22 * scale,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: isToday
                    ? BoxDecoration(
                        color: c.gold,
                        borderRadius: BorderRadius.circular(12 * scale),
                      )
                    : null,
                // widthFactor keeps the marker hugging the digits.
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday ? c.bg1 : c.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(child: _titles(c, scale)),
          ],
        ),
      ),
    );
    return Opacity(
      opacity: inMonth ? 1 : .4,
      child: isToday
          ? Stack(
              fit: StackFit.expand,
              children: [
                cell,
                Positioned.fill(child: _Beam(color: c.warn, radius: 8))
              ],
            )
          : cell,
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
                    color: eventColor(e.id).withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(3),
                    border: Border(
                      left: BorderSide(color: eventColor(e.id), width: 2),
                    ),
                  ),
                  child: Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10 * scale,
                      height: 1,
                      color: Color.lerp(eventColor(e.id), c.ink, .45),
                    ),
                  ),
                ),
              if (events.length - shown > 0)
                Text(
                  '+${events.length - shown}',
                  style: TextStyle(
                      fontSize: 10 * scale, height: 1, color: c.muted),
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
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: eventColor(event.id), width: 3),
            ),
          ),
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

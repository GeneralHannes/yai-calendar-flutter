import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/sync/sync_engine.dart';
import '../../../core/theme/yai_theme.dart';
import '../calendar_controller.dart';
import '../data/calendar_event.dart';
import 'calendar_views.dart';
import 'date_format.dart';
import 'event_sheets.dart';

/// The whole app: a month calendar, the events on the selected date, and
/// what's coming up next.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.controller,
    required this.sync,
    this.code,
    this.onLeave,
  });

  final CalendarController controller;
  final SyncEngine sync;

  /// The shared calendar's code, when the app is in shared mode.
  final String? code;
  final VoidCallback? onLeave;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selected = dayOf(DateTime.now());

  CalendarController get _c => widget.controller;

  void _shiftMonth(int delta) {
    final m = _c.month;
    _c.showMonth(DateTime(m.year, m.month + delta));
  }

  void _goToday() {
    setState(() => _selected = dayOf(DateTime.now()));
    _c.showMonth(DateTime.now());
  }

  void _select(DateTime day) {
    setState(() => _selected = day);
    // Tapping a grey spill-over day moves to its month.
    if (day.month != _c.month.month || day.year != _c.month.year) {
      _c.showMonth(day);
    }
    // And pop up everything about that date.
    showDayDetails(
      context,
      day: day,
      eventsFor: _all,
      onSave: _c.save,
      onDelete: _c.delete,
    );
  }

  /// Every loaded event (visible window + upcoming), de-duplicated by id.
  List<CalendarEvent> _all() => {
        for (final e in [..._c.events, ..._c.upcoming]) e.id: e,
      }.values.toList();

  List<CalendarEvent> _onSelected() =>
      _all().where((e) => sameDay(e.start.toLocal(), _selected)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  List<CalendarEvent> _upNext() {
    final now = DateTime.now().toUtc();
    return _c.upcoming.where((e) => e.end.isAfter(now)).take(12).toList();
  }

  Widget? _shareButton(YaiPalette c) {
    final code = widget.code, leave = widget.onLeave;
    if (code == null || leave == null) return null;
    return IconButton(
      tooltip: 'Calendar code',
      onPressed: () => showSharingSheet(context, code: code, onLeave: leave),
      icon: Icon(CupertinoIcons.person_2, color: c.gold),
    );
  }

  Future<void> _add() async {
    final event = await showEventEditor(context, day: _selected);
    if (event != null) await _c.save(event);
  }

  Future<void> _edit(CalendarEvent e) async {
    final edited = await showEventEditor(
      context,
      day: dayOf(e.start.toLocal()),
      existing: e,
    );
    if (edited != null) await _c.save(edited);
  }

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);

    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final month = _c.month;
        final wide = MediaQuery.sizeOf(context).width >= 900;

        final grid = MonthGrid(
          month: month,
          events: _c.events,
          selected: _selected,
          onDayTap: _select,
        );

        final gridFill = MonthGrid(
          fill: true,
          month: month,
          events: _c.events,
          selected: _selected,
          onDayTap: _select,
        );

        final selectedEvents = _onSelected();
        final selectedSection = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              dayLabel(_selected),
              style: TextStyle(
                fontSize: 22,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 4),
            if (selectedEvents.isEmpty)
              Text('No events.', style: TextStyle(color: c.muted))
            else
              EventPanel(
                events: selectedEvents,
                onTap: _edit,
                onDelete: _c.delete,
              ),
          ],
        );

        final upNextSection = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Up next'),
            const SizedBox(height: 8),
            UpNextList(events: _upNext(), onTap: _edit, onDelete: _c.delete),
          ],
        );

        // The glass scaffold lays the bar over the content and reports its
        // height through MediaQuery padding, so the lists start below it.
        final safe = MediaQuery.paddingOf(context);
        // Clear the glass bar on top (44 + a gap) and the bottom controls
        // (52 + padding) so nothing ends up underneath them.
        final top = safe.top + 12;
        final bottom = safe.bottom + 100;

        return Material(
          type: MaterialType.transparency,
          child: GlassScaffold(
            background: const _Backdrop(),
            edgeToEdge: true,
            // Top: just the month, in the journal's gold caps over its
            // hairline. Every control lives at the bottom, in thumb reach.
            appBar: null,
            bottomBar: wide
                ? null
                : SafeArea(
                    top: false,
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: _BottomControls(
                            onPrev: () => _shiftMonth(-1),
                            onNext: () => _shiftMonth(1),
                            onToday: _goToday,
                            onAdd: _add,
                          ),
                        ),
                      ),
                    ),
                  ),
            body: wide
                // Landscape: calendar on the left, the lists on the right.
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      36,
                      safe.top + 28,
                      36,
                      safe.bottom + 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DesktopHeader(
                          month: month,
                          trailing: _shareButton(c),
                          onPrev: () => _shiftMonth(-1),
                          onNext: () => _shiftMonth(1),
                          onToday: _goToday,
                          onAdd: _add,
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // The calendar fills the window.
                              Expanded(child: gridFill),
                              const SizedBox(width: 32),
                              // Side panel: the selected date, then Up next.
                              SizedBox(
                                width: (MediaQuery.sizeOf(context).width * .27)
                                    .clamp(340.0, 460.0),
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    selectedSection,
                                    const SizedBox(height: 28),
                                    upNextSection,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: widget.sync.syncNow,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
                      children: [
                        _MonthTitle(month: month, trailing: _shareButton(c)),
                        const SizedBox(height: 12),
                        grid,
                        const SizedBox(height: 20),
                        selectedSection,
                        const SizedBox(height: 28),
                        upNextSection,
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// Desktop header: a large month title on the left, the controls on the
/// right. (Phones use the compact top title and the bottom controls instead.)
class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.month,
    this.trailing,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onAdd,
  });

  final DateTime month;
  final Widget? trailing;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: monthNames[month.month - 1],
                  style: TextStyle(color: c.ink),
                ),
                TextSpan(
                  text: ' ${month.year}',
                  style: TextStyle(color: c.gold, fontWeight: FontWeight.w400),
                ),
              ],
            ),
            style: const TextStyle(
              fontFamily: YaiPalette.fontFamily,
              fontSize: 40,
              height: 1.1,
            ),
          ),
        ),
        if (trailing != null) trailing!,
        const SizedBox(width: 8),
        _BottomControls(
          alignment: MainAxisAlignment.end,
          onPrev: onPrev,
          onNext: onNext,
          onToday: onToday,
          onAdd: onAdd,
        ),
      ],
    );
  }
}

/// Phone title: the year in gold above a large serif month name.
class _MonthTitle extends StatelessWidget {
  const _MonthTitle({required this.month, this.trailing});

  final DateTime month;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${month.year}',
          style: TextStyle(
            fontSize: 15,
            letterSpacing: 1.6,
            color: c.gold,
          ),
        ),
        Text(
          monthNames[month.month - 1],
          style: TextStyle(
            fontSize: 36,
            height: 1.15,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 96,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(colors: [
              for (final x in YaiPalette.bifrost) x.withValues(alpha: .7),
            ]),
          ),
        ),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: title), if (trailing != null) trailing!],
    );
  }
}

/// Thumb-reach controls, centred: previous / today / next / add. Big (52) glass targets, so they're easy to hit one-handed.
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onAdd,
    this.alignment = MainAxisAlignment.center,
  });

  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onAdd;
  final MainAxisAlignment alignment;

  static const _size = 52.0;

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        GlassIconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: c.gold),
          onPressed: onPrev,
          size: _size,
          semanticLabel: 'Previous month',
        ),
        const SizedBox(width: 10),
        GlassButton.custom(
          onTap: onToday,
          width: 92,
          height: _size,
          shape: const LiquidRoundedSuperellipse(borderRadius: 26),
          label: 'Jump to today',
          child: Text(
            'Today',
            style: TextStyle(
              fontFamily: YaiPalette.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.gold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        GlassIconButton(
          icon: Icon(CupertinoIcons.chevron_right, color: c.gold),
          onPressed: onNext,
          size: _size,
          semanticLabel: 'Next month',
        ),
        const SizedBox(width: 10),
        GlassIconButton(
          icon: Icon(CupertinoIcons.add, color: c.gold),
          onPressed: onAdd,
          size: _size,
          semanticLabel: 'Add event',
        ),
      ],
    );
  }
}

/// Page backdrop: the glass controls refract this, so it has a little colour
/// variation: a quiet gradient, a faint blue wash top-left, gold bottom-right.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.bg1,
            Color.alphaBlend(c.act.withValues(alpha: .06), c.bg1)
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1, -1.1),
            radius: 1.2,
            colors: [c.act.withValues(alpha: .16), Colors.transparent],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.1, 1.1),
              radius: 1.0,
              colors: [c.gold.withValues(alpha: .08), Colors.transparent],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

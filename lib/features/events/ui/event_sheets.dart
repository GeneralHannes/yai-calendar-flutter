import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/yai_theme.dart';
import '../data/calendar_event.dart';
import 'calendar_views.dart' show SectionLabel;
import 'date_format.dart';

/// Shows [child] as glass chrome: a bottom sheet on phones; on wide screens a
/// glass card that fades and scales in instead of sliding up.
Future<T?> showGlassPopup<T>(
  BuildContext context, {
  required Widget child,
  GlassSheetState state = GlassSheetState.full,
}) {
  final content = Material(type: MaterialType.transparency, child: child);

  if (MediaQuery.sizeOf(context).width < 700) {
    return GlassModalSheet.show<T>(
      context: context,
      initialState: state,
      builder: (_) => content,
    );
  }

  final c = YaiPalette.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: .5),
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (_, __, ___) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.premium,
              shape: const LiquidRoundedSuperellipse(borderRadius: 28),
              color: c.bg2.withValues(alpha: .62),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(.16, 1, .3, 1),
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: .94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Add / edit form. Returns the event to save, or null when cancelled.
Future<CalendarEvent?> showEventEditor(
  BuildContext context, {
  required DateTime day,
  CalendarEvent? existing,
}) =>
    showGlassPopup<CalendarEvent>(
      context,
      child: _EventEditor(day: day, existing: existing),
    );

/// Everything about one date: each event's time, title, location and notes,
/// with edit, delete and add. Opens when a calendar cell is tapped.
Future<void> showDayDetails(
  BuildContext context, {
  required DateTime day,
  required List<CalendarEvent> Function() eventsFor,
  required Future<void> Function(CalendarEvent) onSave,
  required Future<void> Function(String id) onDelete,
}) =>
    showGlassPopup<void>(
      context,
      state: GlassSheetState.half,
      child: _DayDetails(
        day: day,
        eventsFor: eventsFor,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );

TextStyle _fieldText(Color color) => TextStyle(
      fontFamily: YaiPalette.fontFamily,
      fontSize: 16,
      color: color,
    );

class _EventEditor extends StatefulWidget {
  const _EventEditor({required this.day, this.existing});

  final DateTime day;
  final CalendarEvent? existing;

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _location = TextEditingController(text: widget.existing?.location);
  late final _notes = TextEditingController(text: widget.existing?.description);
  late DateTime _date = widget.existing == null
      ? widget.day
      : dayOf(widget.existing!.start.toLocal());
  late TimeOfDay _from = widget.existing == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(widget.existing!.start.toLocal());
  late TimeOfDay _to = widget.existing == null
      ? const TimeOfDay(hour: 10, minute: 0)
      : TimeOfDay.fromDateTime(widget.existing!.end.toLocal());
  late bool _allDay = widget.existing?.allDay ?? false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool from}) async {
    final picked =
        await showTimePicker(context: context, initialTime: from ? _from : _to);
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final start = _allDay
        ? DateTime(_date.year, _date.month, _date.day)
        : DateTime(
            _date.year, _date.month, _date.day, _from.hour, _from.minute);
    var end = _allDay
        ? start.add(const Duration(days: 1))
        : DateTime(_date.year, _date.month, _date.day, _to.hour, _to.minute);
    if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();

    final base = widget.existing;
    final event = base == null
        ? CalendarEvent.create(
            title: title,
            start: start,
            end: end,
            location: orNull(_location.text),
            description: orNull(_notes.text),
            allDay: _allDay,
          )
        // Built directly (not copyWith) so an emptied location/notes field is
        // really cleared instead of keeping the old value.
        : CalendarEvent(
            id: base.id,
            title: title,
            start: start.toUtc(),
            end: end.toUtc(),
            location: orNull(_location.text),
            description: orNull(_notes.text),
            allDay: _allDay,
            updatedAt: base.updatedAt,
          );
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final c = YaiPalette.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        30,
        24,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'New event' : 'Edit event',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          GlassTextField(
            controller: _title,
            placeholder: 'Title',
            autofocus: widget.existing == null,
            surfaceStyle: GlassSurfaceStyle.solid,
            textStyle: _fieldText(c.ink),
            placeholderStyle: _fieldText(c.muted),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: _location,
            placeholder: 'Location',
            surfaceStyle: GlassSurfaceStyle.solid,
            textStyle: _fieldText(c.ink),
            placeholderStyle: _fieldText(c.muted),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: _notes,
            placeholder: 'Notes',
            minLines: 2,
            maxLines: 4,
            surfaceStyle: GlassSurfaceStyle.solid,
            textStyle: _fieldText(c.ink),
            placeholderStyle: _fieldText(c.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(loc.formatFullDate(_date)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('All day'),
            value: _allDay,
            onChanged: (v) => setState(() => _allDay = v),
          ),
          if (!_allDay)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(from: true),
                    child: Text(loc.formatTimeOfDay(_from,
                        alwaysUse24HourFormat: true)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(from: false),
                    child: Text(
                        loc.formatTimeOfDay(_to, alwaysUse24HourFormat: true)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class _DayDetails extends StatefulWidget {
  const _DayDetails({
    required this.day,
    required this.eventsFor,
    required this.onSave,
    required this.onDelete,
  });

  final DateTime day;
  final List<CalendarEvent> Function() eventsFor;
  final Future<void> Function(CalendarEvent) onSave;
  final Future<void> Function(String id) onDelete;

  @override
  State<_DayDetails> createState() => _DayDetailsState();
}

class _DayDetailsState extends State<_DayDetails> {
  Future<void> _add() async {
    final event = await showEventEditor(context, day: widget.day);
    if (event == null) return;
    await widget.onSave(event);
    if (mounted) setState(() {});
  }

  Future<void> _edit(CalendarEvent e) async {
    final edited = await showEventEditor(context, day: widget.day, existing: e);
    if (edited == null) return;
    await widget.onSave(edited);
    if (mounted) setState(() {});
  }

  Future<void> _delete(CalendarEvent e) async {
    await widget.onDelete(e.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    final events = widget
        .eventsFor()
        .where((e) => sameDay(e.start.toLocal(), widget.day))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final d = widget.day;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            weekdayNames[d.weekday - 1].toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: c.gold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${d.day} ${monthNames[d.month - 1]} ${d.year}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            events.isEmpty
                ? 'Nothing planned'
                : '${events.length} ${events.length == 1 ? 'event' : 'events'}',
            style: TextStyle(color: c.muted),
          ),
          const SizedBox(height: 16),
          for (final e in events) ...[
            _DetailCard(
              event: e,
              onTap: () => _edit(e),
              onDelete: () => _delete(e),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add event'),
          ),
        ],
      ),
    );
  }
}

/// One event with all of its details. Tap to edit.
class _DetailCard extends StatelessWidget {
  const _DetailCard({
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
    final location = event.location;
    final notes = event.description;
    return Material(
      color: c.bg2,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.ink.withValues(alpha: .1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeRange(event),
                      style: TextStyle(fontSize: 13, color: c.gold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    if (location != null && location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 16, color: c.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(fontSize: 14, color: c.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        notes,
                        style:
                            TextStyle(fontSize: 14, height: 1.4, color: c.ink),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline, color: c.bad),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The calendar's code, with copy and "leave this calendar".
Future<void> showSharingSheet(
  BuildContext context, {
  required String code,
  required VoidCallback onLeave,
}) {
  return showGlassPopup<void>(
    context,
    state: GlassSheetState.half,
    child: Builder(
      builder: (context) {
        final c = YaiPalette.of(context);
        final pretty = [
          for (var i = 0; i < code.length; i += 4)
            code.substring(i, i + 4 > code.length ? code.length : i + 4),
        ].join('-');
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('Shared calendar'),
              const SizedBox(height: 10),
              SelectableText(
                pretty,
                style: TextStyle(fontSize: 24, letterSpacing: 1, color: c.gold),
              ),
              const SizedBox(height: 8),
              Text(
                'Everyone who enters this code sees and edits the same events.',
                style: TextStyle(color: c.muted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: pretty));
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.bg1,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Copy code'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onLeave();
                },
                style: TextButton.styleFrom(foregroundColor: c.bad),
                child: const Text('Leave this calendar'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

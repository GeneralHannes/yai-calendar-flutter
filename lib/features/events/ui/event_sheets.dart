import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/yai_theme.dart';
import '../data/calendar_event.dart';
import 'date_format.dart';

/// Add / edit form. A glass bottom sheet on phones; on wide screens a glass
/// card that fades and scales in instead of sliding up. Returns the event to
/// save, or null when cancelled.
Future<CalendarEvent?> showEventEditor(
  BuildContext context, {
  required DateTime day,
  CalendarEvent? existing,
}) {
  final editor = Material(
    type: MaterialType.transparency,
    child: _EventEditor(day: day, existing: existing),
  );

  if (MediaQuery.sizeOf(context).width < 700) {
    return GlassModalSheet.show<CalendarEvent>(
      context: context,
      initialState: GlassSheetState.full,
      builder: (_) => editor,
    );
  }

  final c = YaiPalette.of(context);
  return showGeneralDialog<CalendarEvent>(
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
              child: editor,
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

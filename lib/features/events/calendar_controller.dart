import 'package:flutter/foundation.dart';

import '../../core/sync/sync_engine.dart';
import 'data/calendar_event.dart';
import 'data/event_local_data_source.dart';

/// View state for the visible date window. Reads and writes go straight to
/// SQLite; the network is only ever touched by [SyncEngine].
class CalendarController extends ChangeNotifier {
  CalendarController(this._local, this._sync) {
    _sync.dataRevision.addListener(_reload);
  }

  final EventLocalDataSource _local;
  final SyncEngine _sync;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  List<CalendarEvent> _events = const [];
  List<CalendarEvent> _upcoming = const [];

  /// First day of the month the grid is showing.
  DateTime get month => _month;
  DateTime get from => _from;
  DateTime get to => _to;
  List<CalendarEvent> get events => _events;

  /// Events from now on, independent of the visible month, so "Up next" never
  /// goes empty just because the grid is showing another month.
  List<CalendarEvent> get upcoming => _upcoming;

  Future<void> showRange(DateTime from, DateTime to) {
    _from = from;
    _to = to;
    return _reload();
  }

  static DateTime _gridStart(DateTime firstOfMonth) => DateTime(
      firstOfMonth.year, firstOfMonth.month, 1 - (firstOfMonth.weekday - 1));

  static DateTime _gridEnd(DateTime firstOfMonth) {
    final lead = firstOfMonth.weekday - 1;
    final days = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
    final start = _gridStart(firstOfMonth);
    return DateTime(
        start.year, start.month, start.day + ((lead + days) / 7).ceil() * 7);
  }

  /// Shows the month containing [anyDayInMonth]. The loaded window spans the
  /// previous, current and next month grids, so the month film strip can show
  /// its neighbours (and the spill-over days) with their events already there.
  Future<void> showMonth(DateTime anyDayInMonth) {
    _month = DateTime(anyDayInMonth.year, anyDayInMonth.month);
    return showRange(
      _gridStart(DateTime(_month.year, _month.month - 1)),
      _gridEnd(DateTime(_month.year, _month.month + 1)),
    );
  }

  Future<void> save(CalendarEvent event) async {
    await _local.upsertLocal(event.copyWith(updatedAt: DateTime.now().toUtc()));
    await _reload();
    _sync.onLocalWrite();
  }

  Future<void> delete(String id) async {
    await _local.deleteLocal(id, DateTime.now());
    await _reload();
    _sync.onLocalWrite();
  }

  Future<void> _reload() async {
    final from = _from, to = _to;
    final now = DateTime.now();
    final result = await _local.inRange(from, to);
    final ahead = await _local.inRange(now, now.add(const Duration(days: 120)));
    // Drop results for a window the user has already navigated away from.
    if (from != _from || to != _to) return;
    _events = result;
    _upcoming = ahead;
    notifyListeners();
  }

  @override
  void dispose() {
    _sync.dataRevision.removeListener(_reload);
    super.dispose();
  }
}

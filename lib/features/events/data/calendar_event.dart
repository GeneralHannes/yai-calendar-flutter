import 'package:flutter/foundation.dart' show immutable;

import '../../../core/util/uuid.dart';

/// Local row lifecycle. Stored in `events.sync_state`.
abstract final class SyncState {
  static const int synced = 0;

  /// Local change not yet accepted by the server. Protected from being
  /// overwritten by incoming deltas.
  static const int pending = 1;

  /// Server permanently rejected the change (4xx). Not retried; the next
  /// server delta for this id overwrites it. Surface these in the UI if needed.
  static const int failed = 2;
}

@immutable
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.updatedAt,
    this.description,
    this.location,
    this.allDay = false,
    this.deleted = false,
  });

  factory CalendarEvent.create({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
    bool allDay = false,
  }) {
    return CalendarEvent(
      id: uuidV4(),
      title: title,
      start: start.toUtc(),
      end: end.toUtc(),
      description: description,
      location: location,
      allDay: allDay,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  final String id;
  final String title;
  final String? description;
  final String? location;

  /// Always UTC. Convert with `.toLocal()` at the presentation layer only.
  final DateTime start;
  final DateTime end;
  final bool allDay;

  /// Last-modified instant. Locally it is used for optimistic concurrency
  /// between UI edits and in-flight pushes; the server's own clock drives the
  /// delta cursor, so client clock skew can't cause missed updates.
  final DateTime updatedAt;
  final bool deleted;

  CalendarEvent copyWith({
    String? title,
    String? description,
    String? location,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      start: start?.toUtc() ?? this.start,
      end: end?.toUtc() ?? this.end,
      allDay: allDay ?? this.allDay,
      updatedAt: updatedAt?.toUtc() ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  // ---- SQLite ------------------------------------------------------------

  Map<String, Object?> toRow({required int syncState}) => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'start_at': start.millisecondsSinceEpoch,
        'end_at': end.millisecondsSinceEpoch,
        'all_day': allDay ? 1 : 0,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted ? 1 : 0,
        'sync_state': syncState,
      };

  factory CalendarEvent.fromRow(Map<String, Object?> r) => CalendarEvent(
        id: r['id']! as String,
        title: r['title']! as String,
        description: r['description'] as String?,
        location: r['location'] as String?,
        start: _utcMs(r['start_at']! as int),
        end: _utcMs(r['end_at']! as int),
        allDay: r['all_day'] == 1,
        updatedAt: _utcMs(r['updated_at']! as int),
        deleted: r['deleted'] == 1,
      );

  // ---- Wire format (single place to adapt to your backend's contract) ----

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'all_day': allDay,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CalendarEvent.fromJson(Map<String, Object?> j) => CalendarEvent(
        id: j['id']! as String,
        title: (j['title'] as String?) ?? '',
        description: j['description'] as String?,
        location: j['location'] as String?,
        start: DateTime.parse(j['start']! as String).toUtc(),
        end: DateTime.parse(j['end']! as String).toUtc(),
        allDay: (j['all_day'] as bool?) ?? false,
        updatedAt: DateTime.parse(j['updated_at']! as String).toUtc(),
        deleted: (j['deleted'] as bool?) ?? false,
      );

  static DateTime _utcMs(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

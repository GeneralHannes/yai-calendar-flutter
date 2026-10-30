import 'package:sqflite/sqflite.dart';

import 'calendar_event.dart';

/// All SQL for events lives here. The UI reads and writes only through this
/// class, so it never waits on the network.
class EventLocalDataSource {
  EventLocalDataSource(this._db);

  final Database _db;

  static const _table = 'events';
  static const _cursorKey = 'events_cursor';

  // ---- Reads -------------------------------------------------------------

  /// Events overlapping [from, to). Zero-length events that start inside the
  /// window are included.
  Future<List<CalendarEvent>> inRange(DateTime from, DateTime to) async {
    final f = from.toUtc().millisecondsSinceEpoch;
    final t = to.toUtc().millisecondsSinceEpoch;
    final rows = await _db.query(
      _table,
      where: 'deleted = 0 AND start_at < ? AND (end_at > ? OR start_at >= ?)',
      whereArgs: [t, f, f],
      orderBy: 'start_at ASC',
    );
    return rows.map(CalendarEvent.fromRow).toList(growable: false);
  }

  Future<CalendarEvent?> byId(String id) async {
    final rows =
        await _db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : CalendarEvent.fromRow(rows.first);
  }

  // ---- Local (user) writes: always marked pending ------------------------

  Future<void> upsertLocal(CalendarEvent e) => _db.insert(
        _table,
        e.toRow(syncState: SyncState.pending),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Soft delete: keeps a tombstone until the server acknowledges it.
  Future<void> deleteLocal(String id, DateTime now) => _db.update(
        _table,
        {
          'deleted': 1,
          'sync_state': SyncState.pending,
          'updated_at': now.toUtc().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  // ---- Sync: outbound ----------------------------------------------------

  Future<List<CalendarEvent>> pending({int limit = 50}) async {
    final rows = await _db.query(
      _table,
      where: 'sync_state = ?',
      whereArgs: [SyncState.pending],
      orderBy: 'updated_at ASC',
      limit: limit,
    );
    return rows.map(CalendarEvent.fromRow).toList(growable: false);
  }

  /// Clears the pending flag only if the row is still exactly the version
  /// that was pushed. If the user edited it mid-flight, it stays pending and
  /// is pushed again on the next pass.
  Future<void> markPushed(CalendarEvent pushed) {
    final args = [pushed.id, pushed.updatedAt.millisecondsSinceEpoch];
    return pushed.deleted
        ? _db.delete(_table,
            where: 'id = ? AND updated_at = ?', whereArgs: args)
        : _db.update(
            _table,
            {'sync_state': SyncState.synced},
            where: 'id = ? AND updated_at = ?',
            whereArgs: args,
          );
  }

  /// Server refused [pushed]. If it sent its own copy, server wins; otherwise
  /// park the row as failed so it stops blocking the queue.
  /// Returns true if visible data changed.
  Future<bool> markRejected(CalendarEvent pushed, CalendarEvent? serverCopy) {
    return _db.transaction((txn) async {
      final current = await txn.query(
        _table,
        columns: ['updated_at'],
        where: 'id = ?',
        whereArgs: [pushed.id],
      );
      final stillSame = current.isNotEmpty &&
          current.first['updated_at'] ==
              pushed.updatedAt.millisecondsSinceEpoch;
      if (!stillSame) return false; // newer local edit; let it be pushed

      if (serverCopy == null) {
        await txn.update(_table, {'sync_state': SyncState.failed},
            where: 'id = ?', whereArgs: [pushed.id]);
        return false;
      }
      if (serverCopy.deleted) {
        await txn.delete(_table, where: 'id = ?', whereArgs: [pushed.id]);
      } else {
        await txn.insert(_table, serverCopy.toRow(syncState: SyncState.synced),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return true;
    });
  }

  // ---- Sync: inbound -----------------------------------------------------

  Future<String?> readCursor() async {
    final rows = await _db.query('sync_meta',
        columns: ['value'], where: 'key = ?', whereArgs: [_cursorKey]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  /// Applies one delta page and advances the cursor in the same transaction,
  /// so a crash can never leave the cursor ahead of the data.
  /// Returns the number of rows that changed.
  Future<int> applyRemotePage(List<CalendarEvent> events, String cursor) {
    return _db.transaction((txn) async {
      var applied = 0;
      if (events.isNotEmpty) {
        final pendingRows = await txn.query(_table,
            columns: ['id'],
            where: 'sync_state = ?',
            whereArgs: [SyncState.pending]);
        final protected = {for (final r in pendingRows) r['id']! as String};

        final batch = txn.batch();
        for (final e in events) {
          // Unpushed local edits win locally; the server arbitrates on push.
          if (protected.contains(e.id)) continue;
          if (e.deleted) {
            batch.delete(_table, where: 'id = ?', whereArgs: [e.id]);
          } else {
            batch.insert(_table, e.toRow(syncState: SyncState.synced),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          applied++;
        }
        await batch.commit(noResult: true);
      }
      await txn.insert('sync_meta', {'key': _cursorKey, 'value': cursor},
          conflictAlgorithm: ConflictAlgorithm.replace);
      return applied;
    });
  }

  /// Forces a full re-download on next sync (e.g. after logout/login).
  Future<void> resetCursor() =>
      _db.delete('sync_meta', where: 'key = ?', whereArgs: [_cursorKey]);
}

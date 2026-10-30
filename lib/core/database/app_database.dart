import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'db_factory.dart';

/// Owns the single SQLite connection and the schema.
///
/// Migrations are append-only: add a new entry to [_migrations] and bump
/// nothing else — the version is derived from the list length.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _fileName = 'calendar.db';

  /// Index i upgrades the schema from version i to version i + 1.
  static const List<List<String>> _migrations = [
    // v1
    [
      '''
      CREATE TABLE events (
        id          TEXT PRIMARY KEY,
        title       TEXT    NOT NULL,
        description TEXT,
        location    TEXT,
        start_at    INTEGER NOT NULL,          -- epoch ms, UTC
        end_at      INTEGER NOT NULL,          -- epoch ms, UTC
        all_day     INTEGER NOT NULL DEFAULT 0,
        updated_at  INTEGER NOT NULL,          -- epoch ms, UTC
        deleted     INTEGER NOT NULL DEFAULT 0, -- tombstone awaiting push
        sync_state  INTEGER NOT NULL DEFAULT 0  -- see SyncState
      )
      ''',
      'CREATE INDEX idx_events_range ON events(deleted, start_at)',
      'CREATE INDEX idx_events_pending ON events(sync_state) WHERE sync_state <> 0',
      '''
      CREATE TABLE sync_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
      ''',
    ],
  ];

  static Future<AppDatabase> open(
      {String? path, DatabaseFactory? factory}) async {
    final f = factory ?? platformDatabaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), _fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _migrations.length,
        onConfigure: (db) async {
          // WAL lets UI reads proceed while sync writes. rawQuery (not
          // execute) because the pragma returns a row on Android. The web
          // IndexedDB backend has no WAL support.
          if (!kIsWeb) await db.rawQuery('PRAGMA journal_mode=WAL');
        },
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    final batch = db.batch();
    for (var v = from; v < to; v++) {
      for (final sql in _migrations[v]) {
        batch.execute(sql);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() => db.close();
}

import 'dart:convert';

import 'package:calendar_app/core/database/app_database.dart';
import 'package:calendar_app/core/network/api_client.dart';
import 'package:calendar_app/core/sync/sync_engine.dart';
import 'package:calendar_app/features/events/data/calendar_event.dart';
import 'package:calendar_app/features/events/data/event_local_data_source.dart';
import 'package:calendar_app/features/events/data/event_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late AppDatabase db;
  late EventLocalDataSource local;

  setUp(() async {
    db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    local = EventLocalDataSource(db.db);
  });

  tearDown(() => db.close());

  SyncEngine engineWith(MockClient client) => SyncEngine(
        local: local,
        remote: EventRemoteDataSource(
            ApiClient(client: client, baseUrl: 'https://x.test')),
      );

  test('pushes pending writes, pulls deltas and stores the cursor', () async {
    final pushed = <String>[];
    String? sinceSeen = 'unset';
    final remoteEvent = CalendarEvent.create(
      title: 'From server',
      start: DateTime.utc(2026, 11, 2, 9),
      end: DateTime.utc(2026, 11, 2, 10),
    );

    final engine = engineWith(MockClient((req) async {
      if (req.method == 'PUT') {
        pushed.add(req.url.pathSegments.last);
        return http.Response('', 204);
      }
      sinceSeen = req.url.queryParameters['since'];
      return http.Response(
        jsonEncode({
          'events': [remoteEvent.toJson()],
          'cursor': 'c1',
          'has_more': false,
        }),
        200,
      );
    }));

    final mine = CalendarEvent.create(
      title: 'Mine',
      start: DateTime.utc(2026, 11, 1, 9),
      end: DateTime.utc(2026, 11, 1, 10),
    );
    await local.upsertLocal(mine);

    await engine.syncNow();

    expect(pushed, [mine.id]);
    expect(sinceSeen, isNull);
    expect(await local.pending(), isEmpty);
    expect(await local.readCursor(), 'c1');
    final month =
        await local.inRange(DateTime.utc(2026, 11), DateTime.utc(2026, 12));
    expect(month.map((e) => e.title), ['Mine', 'From server']);
    expect(engine.status.value.phase, SyncPhase.idle);
    engine.dispose();
  });

  test('offline keeps local writes pending and reports offline', () async {
    final engine = engineWith(
        MockClient((_) async => throw http.ClientException('no route')));
    await local.upsertLocal(CalendarEvent.create(
      title: 'Offline',
      start: DateTime.utc(2026, 11, 1),
      end: DateTime.utc(2026, 11, 1, 1),
    ));

    await engine.syncNow();

    expect(await local.pending(), hasLength(1));
    expect(engine.status.value.phase, SyncPhase.offline);
    engine.dispose();
  });

  test('incoming delta does not clobber an unpushed local edit', () async {
    final e = CalendarEvent.create(
      title: 'Local edit',
      start: DateTime.utc(2026, 11, 1),
      end: DateTime.utc(2026, 11, 1, 1),
    );
    await local.upsertLocal(e);
    await local.applyRemotePage([e.copyWith(title: 'Stale server copy')], 'c2');

    expect((await local.byId(e.id))!.title, 'Local edit');
    expect(await local.readCursor(), 'c2');
  });

  test('server tombstone removes the local row', () async {
    final e = CalendarEvent.create(
      title: 'Gone',
      start: DateTime.utc(2026, 11, 1),
      end: DateTime.utc(2026, 11, 1, 1),
    );
    await local.applyRemotePage([e], 'c1');
    await local.applyRemotePage([e.copyWith(deleted: true)], 'c2');
    expect(await local.byId(e.id), isNull);
  });
}

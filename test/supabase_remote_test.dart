import 'dart:convert';

import 'package:calendar_app/core/network/api_client.dart';
import 'package:calendar_app/features/events/data/calendar_event.dart';
import 'package:calendar_app/features/events/data/event_remote_data_source.dart';
import 'package:calendar_app/features/events/data/supabase_event_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

SupabaseEventRemote remoteWith(MockClient client) =>
    SupabaseEventRemote.withClient(
      client: client,
      url: 'https://x.supabase.co',
      anonKey: 'anon',
      code: 'abcd-efgh',
    );

void main() {
  test('pull uses the seq cursor and the calendar-code header', () async {
    late http.Request seen;
    final remote = remoteWith(MockClient((req) async {
      seen = req;
      return http.Response(
        jsonEncode([
          {
            'id': 'e1',
            'title': 'Lunch',
            'description': null,
            'location': null,
            'start_at': '2026-11-02T12:00:00+00:00',
            'end_at': '2026-11-02T13:00:00+00:00',
            'all_day': false,
            'updated_at': '2026-11-01T09:00:00+00:00',
            'deleted': false,
            'seq': 42,
          },
        ]),
        200,
      );
    }));

    final page = await remote.fetchChanges(since: '41');
    expect(seen.url.path, '/rest/v1/events');
    expect(seen.url.queryParameters['seq'], 'gt.41');
    expect(seen.headers['x-calendar-code'], 'abcd-efgh');
    expect(seen.headers['apikey'], 'anon');
    expect(page.cursor, '42');
    expect(page.events.single.title, 'Lunch');
    expect(page.hasMore, isFalse);
  });

  test('empty page keeps the cursor', () async {
    final remote =
        remoteWith(MockClient((_) async => http.Response('[]', 200)));
    expect((await remote.fetchChanges(since: '7')).cursor, '7');
    expect((await remote.fetchChanges()).cursor, '0');
  });

  test('push upserts with merge-duplicates and tombstones deletes', () async {
    late http.Request seen;
    final remote = remoteWith(MockClient((req) async {
      seen = req;
      return http.Response('', 201);
    }));
    final e = CalendarEvent.create(
      title: 'x',
      start: DateTime.utc(2026, 11, 2, 9),
      end: DateTime.utc(2026, 11, 2, 10),
    ).copyWith(deleted: true);

    expect(await remote.push(e), isA<PushAccepted>());
    expect(seen.method, 'POST');
    expect(seen.url.queryParameters['on_conflict'], 'calendar_code,id');
    expect(seen.headers['Prefer'], contains('merge-duplicates'));
    final body = jsonDecode(seen.body) as Map<String, Object?>;
    expect(body['deleted'], true);
    expect(body['calendar_code'], 'abcd-efgh');
  });

  test('a 4xx push is rejected, a 5xx is retried later', () async {
    final bad = remoteWith(MockClient((_) async => http.Response('{}', 400)));
    final down = remoteWith(MockClient((_) async => http.Response('', 503)));
    final e = CalendarEvent.create(
      title: 'x',
      start: DateTime.utc(2026, 11, 2, 9),
      end: DateTime.utc(2026, 11, 2, 10),
    );
    expect(await bad.push(e), isA<PushRejected>());
    expect(down.push(e), throwsA(isA<ApiException>()));
  });
}

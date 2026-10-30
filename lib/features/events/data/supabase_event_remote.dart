import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import 'calendar_event.dart';
import 'event_remote_data_source.dart';

/// [EventRemoteDataSource] on Supabase's REST API (PostgREST). The calendar
/// code travels in the `x-calendar-code` header; see supabase/schema.sql.
///
/// The cursor is the table's `seq` column, which the database bumps on every
/// insert/update, so client clocks never matter. Deletes are tombstones
/// (`deleted = true`) so other devices learn about them.
class SupabaseEventRemote extends EventRemoteDataSource {
  SupabaseEventRemote._(this._rest, this._code) : super(_rest);

  factory SupabaseEventRemote({
    required String url,
    required String anonKey,
    required String code,
  }) =>
      SupabaseEventRemote.withClient(
        url: url,
        anonKey: anonKey,
        code: code,
      );

  /// Same, with an injectable HTTP client (tests).
  factory SupabaseEventRemote.withClient({
    required String url,
    required String anonKey,
    required String code,
    http.Client? client,
  }) {
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    return SupabaseEventRemote._(
      ApiClient(
        client: client,
        baseUrl: '$base/rest/v1',
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
          'x-calendar-code': code,
        },
      ),
      code,
    );
  }

  final ApiClient _rest;
  final String _code;

  static const _pageSize = 500;

  @override
  Future<DeltaPage> fetchChanges({String? since}) async {
    final rows = await _rest.get('/events', query: {
      'select': 'id,title,description,location,start_at,end_at,all_day,'
          'updated_at,deleted,seq',
      'seq': 'gt.${since ?? 0}',
      'order': 'seq.asc',
      'limit': '$_pageSize',
    }) as List<Object?>;
    final list = rows.cast<Map<String, Object?>>();
    final events = [
      for (final r in list)
        CalendarEvent.fromJson({
          ...r,
          'start': r['start_at'],
          'end': r['end_at'],
        }),
    ];
    final cursor = list.isEmpty ? (since ?? '0') : '${list.last['seq']}';
    return DeltaPage(events, cursor, hasMore: list.length == _pageSize);
  }

  @override
  Future<PushOutcome> push(CalendarEvent e) async {
    try {
      await _rest.post(
        '/events',
        {
          'calendar_code': _code,
          'id': e.id,
          'title': e.title,
          'description': e.description,
          'location': e.location,
          'start_at': e.start.toIso8601String(),
          'end_at': e.end.toIso8601String(),
          'all_day': e.allDay,
          'updated_at': e.updatedAt.toIso8601String(),
          'deleted': e.deleted,
        },
        query: {'on_conflict': 'calendar_code,id'},
        headers: {'Prefer': 'resolution=merge-duplicates,return=minimal'},
      );
      return const PushAccepted();
    } on ApiException catch (err) {
      if (err.isTransient) rethrow;
      return const PushRejected(null);
    }
  }
}

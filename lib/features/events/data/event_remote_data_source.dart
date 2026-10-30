import '../../../core/network/api_client.dart';
import 'calendar_event.dart';

/// Assumed backend contract (adapt here; nothing else knows about HTTP):
///
/// ```text
/// GET    /events?since=<cursor>
///          -> { "events": [...], "cursor": "<opaque>", "has_more": bool }
///          Tombstones arrive as { "id": ..., "deleted": true, ... }.
///          `cursor` is produced by the server clock and echoed back verbatim.
/// PUT    /events/{id}   body = event JSON (idempotent upsert)
/// DELETE /events/{id}   404 is treated as success
/// 409 on PUT/DELETE     body = the server's current event (server wins)
/// ```
class DeltaPage {
  const DeltaPage(this.events, this.cursor, {required this.hasMore});

  final List<CalendarEvent> events;
  final String cursor;
  final bool hasMore;
}

sealed class PushOutcome {
  const PushOutcome();
}

final class PushAccepted extends PushOutcome {
  const PushAccepted();
}

final class PushRejected extends PushOutcome {
  const PushRejected(this.serverCopy);

  /// Authoritative server version, when the server supplied one.
  final CalendarEvent? serverCopy;
}

class EventRemoteDataSource {
  EventRemoteDataSource(this._api);

  final ApiClient _api;

  Future<DeltaPage> fetchChanges({String? since}) async {
    final json =
        await _api.get('/events', query: {if (since != null) 'since': since})
            as Map<String, Object?>;
    final events = (json['events'] as List? ?? const [])
        .cast<Map<String, Object?>>()
        .map(CalendarEvent.fromJson)
        .toList(growable: false);
    return DeltaPage(
      events,
      json['cursor']! as String,
      hasMore: (json['has_more'] as bool?) ?? false,
    );
  }

  /// Transient failures are thrown as [ApiException]; permanent ones are
  /// returned as [PushRejected] so the queue can move on.
  Future<PushOutcome> push(CalendarEvent e) async {
    final path = '/events/${Uri.encodeComponent(e.id)}';
    try {
      if (e.deleted) {
        await _api.delete(path);
      } else {
        await _api.put(path, e.toJson());
      }
      return const PushAccepted();
    } on ApiException catch (err) {
      if (err.isTransient) rethrow;
      if (e.deleted && err.statusCode == 404) return const PushAccepted();
      final body = err.body;
      final serverCopy = err.statusCode == 409 && body is Map<String, Object?>
          ? CalendarEvent.fromJson(body)
          : null;
      return PushRejected(serverCopy);
    }
  }
}

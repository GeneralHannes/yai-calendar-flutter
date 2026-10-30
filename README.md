# calendar_app

Offline-first Flutter calendar. Dependencies: `sqflite`, `http`, `path`. Nothing else.

## Run

```bash
flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Release build with a small binary:

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define=API_BASE_URL=https://api.yourdomain.com
```

## Layout

```
lib/
  core/
    environment.dart            compile-time config (--dart-define)
    database/app_database.dart  SQLite connection, WAL, append-only migrations
    network/api_client.dart     JSON over package:http, timeouts, isolate decode
    sync/sync_engine.dart       push-then-pull delta sync, debounced, backoff
    util/uuid.dart              client-side v4 ids
  features/events/
    data/calendar_event.dart            model + row/JSON mapping
    data/event_local_data_source.dart   all SQL
    data/event_remote_data_source.dart  the backend contract
    calendar_controller.dart            ChangeNotifier view state
    ui/calendar_screen.dart             placeholder month agenda
```

## Data flow

UI → `CalendarController` → SQLite. The UI never waits on the network.
`SyncEngine` pushes rows with `sync_state = 1`, then pulls `GET /events?since=<cursor>`
and applies each page and its cursor in a single transaction. When sync changes data,
it bumps `dataRevision`, and the controller reloads the visible window.

Sync triggers: app start, app resume, local writes (debounced 2s), `onRemoteChangeHint()`
(connect it to silent push), and the exponential backoff retry timer (capped at 5 min).
There is no polling.

## Backend contract

See the doc comment in `event_remote_data_source.dart`. That file and the JSON
mapping in `calendar_event.dart` are the only code that needs to change if your API is different.

import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../features/events/data/event_local_data_source.dart';
import '../../features/events/data/event_remote_data_source.dart';
import '../network/api_client.dart';

enum SyncPhase { idle, syncing, offline, error }

@immutable
class SyncStatus {
  const SyncStatus(this.phase, {this.lastSuccess, this.message});

  final SyncPhase phase;
  final DateTime? lastSuccess;
  final String? message;
}

/// Event-driven delta sync. No polling: a pass runs when
///  * the app starts or returns to the foreground,
///  * the user writes locally (debounced, so bursts coalesce into one pass),
///  * something external hints at remote changes ([onRemoteChangeHint],
///    e.g. from a silent push notification),
///  * a failed pass's backoff timer fires.
///
/// Each pass pushes pending local changes first, then pulls deltas since the
/// stored server cursor. At most one pass runs at a time; requests during a
/// pass schedule exactly one follow-up pass.
class SyncEngine {
  SyncEngine({
    required EventLocalDataSource local,
    required EventRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final EventLocalDataSource _local;
  final EventRemoteDataSource _remote;

  final ValueNotifier<SyncStatus> status =
      ValueNotifier(const SyncStatus(SyncPhase.idle));

  /// Increments whenever sync changed local rows; views reload on it.
  final ValueNotifier<int> dataRevision = ValueNotifier(0);

  static const _localWriteDebounce = Duration(seconds: 2);
  static const _maxBackoff = Duration(minutes: 5);
  static const _maxPushPasses = 10;

  final _rng = Random();
  AppLifecycleListener? _lifecycle;
  Timer? _debounce;
  Timer? _retry;
  Future<void>? _inFlight;
  bool _rerun = false;
  int _failures = 0;
  bool _disposed = false;

  void start() {
    _lifecycle = AppLifecycleListener(onResume: requestSync);
    requestSync();
  }

  void requestSync() => _schedule(Duration.zero);

  void onLocalWrite() => _schedule(_localWriteDebounce);

  void onRemoteChangeHint() => _schedule(Duration.zero);

  /// For pull-to-refresh: runs now and completes when the pass ends.
  Future<void> syncNow() {
    _debounce?.cancel();
    return _kick();
  }

  void _schedule(Duration delay) {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(delay, _kick);
  }

  Future<void> _kick() {
    if (_disposed) return Future.value();
    final running = _inFlight;
    if (running != null) {
      _rerun = true;
      return running;
    }
    _retry?.cancel();
    final pass = _run().whenComplete(() {
      _inFlight = null;
      if (_rerun && !_disposed) {
        _rerun = false;
        unawaited(_kick());
      }
    });
    return _inFlight = pass;
  }

  Future<void> _run() async {
    final previous = status.value;
    status.value =
        SyncStatus(SyncPhase.syncing, lastSuccess: previous.lastSuccess);
    try {
      var changed = await _push();
      changed += await _pull();
      if (changed > 0) dataRevision.value++;
      _failures = 0;
      status.value = SyncStatus(SyncPhase.idle, lastSuccess: DateTime.now());
    } catch (e, st) {
      _failures++;
      final offline = e is ApiException && e.isNetworkError;
      if (!offline) debugPrint('Sync failed: $e\n$st');
      status.value = SyncStatus(
        offline ? SyncPhase.offline : SyncPhase.error,
        lastSuccess: previous.lastSuccess,
        message: e.toString(),
      );
      _scheduleRetry();
    }
  }

  Future<int> _push() async {
    var changed = 0;
    for (var pass = 0; pass < _maxPushPasses; pass++) {
      final batch = await _local.pending();
      if (batch.isEmpty) break;
      for (final e in batch) {
        switch (await _remote.push(e)) {
          case PushAccepted():
            await _local.markPushed(e);
          case PushRejected(:final serverCopy):
            if (await _local.markRejected(e, serverCopy)) changed++;
        }
      }
    }
    return changed;
  }

  Future<int> _pull() async {
    var cursor = await _local.readCursor();
    var changed = 0;
    while (true) {
      final page = await _remote.fetchChanges(since: cursor);
      changed += await _local.applyRemotePage(page.events, page.cursor);
      if (!page.hasMore || page.cursor == cursor) break;
      cursor = page.cursor;
    }
    return changed;
  }

  void _scheduleRetry() {
    if (_disposed) return;
    final exp = min(_failures, 9); // 2^9 s > max backoff
    final base = Duration(seconds: 1 << exp);
    final capped = base > _maxBackoff ? _maxBackoff : base;
    final jitter = Duration(milliseconds: _rng.nextInt(1000));
    _retry?.cancel();
    _retry = Timer(capped + jitter, _kick);
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _retry?.cancel();
    _lifecycle?.dispose();
    status.dispose();
    dataRevision.dispose();
  }
}

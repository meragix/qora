import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/queries_notifier.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';
import 'package:qora_devtools_ui/src/domain/usecases/observe_events.dart';

/// UI controller for the cache inspector panel.
///
/// [CacheController] fetches a [CacheSnapshot] on demand from the runtime
/// bridge via `ext.qora.getCacheSnapshot` and keeps [QueriesNotifier] updated
/// in real-time by subscribing to the live [QoraEvent] stream.
///
/// ## Live updates
///
/// Incoming [QueryEvent]s are mapped to granular [QueriesNotifier] operations:
/// - `added`       → [QueriesNotifier.addQuery]
/// - `fetched` / `updated` / `invalidated` → [QueriesNotifier.updateQuery]
/// - `removed`     → [QueriesNotifier.removeQuery]
///
/// A manual [refresh] re-syncs the full snapshot, correcting any drift from
/// missed events.
class CacheController extends ChangeNotifier {
  /// Creates a cache controller.
  ///
  /// [observeEvents] drives the live stream for real-time query updates.
  /// [queriesNotifier] is kept in sync as [QueryEvent]s arrive.
  CacheController({
    required EventRepository repository,
    required ObserveEventsUseCase observeEvents,
    required QueriesNotifier queriesNotifier,
  })  : _repository = repository,
        _queriesNotifier = queriesNotifier {
    _subscription = observeEvents().listen(_onEvent);
  }

  final EventRepository _repository;
  final QueriesNotifier _queriesNotifier;
  late final StreamSubscription<QoraEvent> _subscription;

  CacheSnapshot? _snapshot;
  bool _loading = false;
  String? _error;

  /// The most recently fetched [CacheSnapshot], or `null` before the first
  /// successful [refresh].
  CacheSnapshot? get snapshot => _snapshot;

  /// `true` while a [refresh] call is in progress.
  bool get isLoading => _loading;

  /// Human-readable error string from the last failed [refresh], or `null`.
  String? get error => _error;

  void _onEvent(QoraEvent event) {
    if (event is! QueryEvent) return;

    final q = QuerySnapshot(
      key: event.key,
      status: event.status ?? 'unknown',
      updatedAtMs: event.timestampMs,
      data: event.data,
      hasLargePayload: event.hasLargePayload,
      payloadId: event.payloadId,
      totalChunks: event.totalChunks,
      summary: event.summary,
    );

    switch (event.type) {
      case QueryEventType.added:
        _queriesNotifier.addQuery(q);
      case QueryEventType.removed:
        _queriesNotifier.removeQuery(event.key);
      case QueryEventType.fetched:
      case QueryEventType.updated:
      case QueryEventType.invalidated:
        _queriesNotifier.updateQuery(q);
    }
  }

  /// Fetches a fresh [CacheSnapshot] from the runtime bridge.
  ///
  /// Also resets [QueriesNotifier] to the snapshot's full query list so any
  /// drift accumulated from live events is corrected.
  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response =
          await _repository.sendCommand(const GetCacheSnapshotCommand());
      _snapshot = CacheSnapshot.fromJson(Map<String, Object?>.from(response));
      _queriesNotifier.setQueries(_snapshot!.queries);
    } catch (exception) {
      _error = '$exception';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/usecases/observe_events.dart';

/// A single fetch record — either in-flight or recently completed.
class FetchRecord {
  /// Creates a fetch record.
  FetchRecord({
    required this.key,
    required this.startedAtMs,
    this.durationMs,
    this.status,
    this.approxBytes,
  });

  /// String-serialised query key.
  final String key;

  /// Unix epoch millisecond when the fetch started (Loading state entered).
  final int startedAtMs;

  /// Fetch duration in milliseconds, `null` while in-flight.
  int? durationMs;

  /// Terminal status (`'success'` or `'error'`), `null` while in-flight.
  String? status;

  /// Approximate payload size in bytes, or `null` if unavailable.
  int? approxBytes;

  /// Whether the fetch is still in progress.
  bool get isActive => durationMs == null;
}

/// Domain notifier tracking query fetch activity.
///
/// Subscribes to the live [QoraEvent] stream and maintains:
/// - [activeFetches] — queries currently in the [Loading] state
/// - [recentFetches] — last [maxRecent] completed fetches (FIFO)
///
/// ## Event mapping
///
/// | [QueryEvent.status]  | Action                                    |
/// |----------------------|-------------------------------------------|
/// | `'loading'`          | Add to [activeFetches]                    |
/// | `'success'`/`'error'`| Move to [recentFetches] with duration/size|
///
/// [fetchDurationMs] from [QueryEvent] is used when available; otherwise the
/// duration is computed from the recorded [FetchRecord.startedAtMs].
class NetworkActivityNotifier extends ChangeNotifier {
  /// Creates the notifier and immediately subscribes to [observeEvents].
  NetworkActivityNotifier({
    required ObserveEventsUseCase observeEvents,
    this.maxRecent = 100,
  }) {
    _subscription = observeEvents().listen(_onEvent);
  }

  /// Maximum number of completed fetches kept in [recentFetches].
  final int maxRecent;

  late final StreamSubscription<QoraEvent> _subscription;

  final Map<String, FetchRecord> _active = <String, FetchRecord>{};
  final List<FetchRecord> _recent = <FetchRecord>[];

  /// Queries currently in-flight (status = loading).
  List<FetchRecord> get activeFetches =>
      List<FetchRecord>.unmodifiable(_active.values);

  /// Recently completed fetches, newest first.
  List<FetchRecord> get recentFetches =>
      List<FetchRecord>.unmodifiable(_recent);

  /// Total number of completed fetch requests recorded so far.
  int get totalRequests => _recent.length;

  /// Average fetch duration across all completed fetches, in milliseconds.
  double get avgDurationMs {
    final durations = _recent
        .map((r) => r.durationMs)
        .whereType<int>()
        .toList(growable: false);
    if (durations.isEmpty) return 0;
    return durations.reduce((a, b) => a + b) / durations.length;
  }

  /// Fraction of completed fetches that ended with `'error'` status.
  double get errorRate {
    if (_recent.isEmpty) return 0;
    final errors = _recent.where((r) => r.status == 'error').length;
    return errors / _recent.length;
  }

  void _onEvent(QoraEvent event) {
    if (event is! QueryEvent) return;

    final status = event.status;
    if (status == null) return;

    if (status == 'loading') {
      _active[event.key] = FetchRecord(
        key: event.key,
        startedAtMs: event.timestampMs,
      );
      notifyListeners();
      return;
    }

    // Terminal status — move from active to recent.
    final record = _active.remove(event.key) ??
        FetchRecord(key: event.key, startedAtMs: event.timestampMs);

    record
      ..durationMs = event.fetchDurationMs ??
          (event.timestampMs - record.startedAtMs).clamp(0, 1 << 30)
      ..status = status
      ..approxBytes = event.summary?['approxBytes'] as int?;

    _recent.insert(0, record);
    if (_recent.length > maxRecent) _recent.removeLast();

    notifyListeners();
  }

  /// Clears all records.
  void clear() {
    _active.clear();
    _recent.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

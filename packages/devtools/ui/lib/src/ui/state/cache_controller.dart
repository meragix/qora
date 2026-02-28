import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';

/// UI controller for the cache inspector panel.
///
/// [CacheController] fetches a [CacheSnapshot] on demand from the runtime
/// bridge via `ext.qora.getCacheSnapshot` and exposes it to the
/// `CacheInspectorScreen`. It follows a simple loading / success / error
/// state machine built on [ChangeNotifier].
///
/// ## Usage
///
/// ```dart
/// final controller = CacheController(repository: myRepository);
/// await controller.refresh(); // fetches and notifies listeners
/// ```
///
/// ## Scaling note — large snapshots
///
/// [CacheSnapshot] payload size grows linearly with the number of active
/// queries and mutations. For very large caches:
/// - [QuerySnapshot.data] is omitted for large entries (lazy chunking applies
///   at the runtime level).
/// - [QuerySnapshot.summary] provides a lightweight preview immediately.
///
/// If the snapshot response itself becomes too large, add server-side
/// filtering/pagination to `getCacheSnapshot` in a future version.
class CacheController extends ChangeNotifier {
  /// Creates a cache controller bound to the given [repository].
  CacheController({required EventRepository repository})
      : _repository = repository;

  final EventRepository _repository;

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

  /// Fetches a fresh [CacheSnapshot] from the runtime bridge.
  ///
  /// Transitions through: loading → success | error. Notifies listeners on
  /// each transition. Concurrent calls are safe — each call is independent.
  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response =
          await _repository.sendCommand(const GetCacheSnapshotCommand());
      _snapshot = CacheSnapshot.fromJson(Map<String, Object?>.from(response));
    } catch (exception) {
      _error = '$exception';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

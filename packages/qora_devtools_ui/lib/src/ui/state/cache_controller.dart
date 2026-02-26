import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';

/// UI controller for cache snapshot and lazy payload interactions.
class CacheController extends ChangeNotifier {
  /// Creates a cache controller.
  CacheController({required EventRepository repository})
      : _repository = repository;

  final EventRepository _repository;

  CacheSnapshot? _snapshot;
  bool _loading = false;
  String? _error;

  /// Last received cache snapshot.
  CacheSnapshot? get snapshot => _snapshot;

  /// Loading state for cache fetch operations.
  bool get isLoading => _loading;

  /// Last operation error, if any.
  String? get error => _error;

  /// Requests a new cache snapshot from the runtime.
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

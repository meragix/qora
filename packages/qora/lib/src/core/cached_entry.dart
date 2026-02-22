import 'dart:async';

import 'package:qora/src/state/qora_state.dart';

/// Entrée de cache contenant l'état et les métadonnées
class CacheEntry<T> {
  QoraState<T> state;

  final DateTime createdAt;

  DateTime lastAccessedAt;

  final StreamController<QoraState<T>> _controller;

  // ignore: prefer_final_fields
  bool _isDisposed = false;

  CacheEntry({
    required this.state,
    required this.createdAt,
  })  : lastAccessedAt = createdAt,
        _controller = StreamController<QoraState<T>>.broadcast();

  /// Stream qui émet immédiatement l'état actuel puis les mises à jour
  Stream<QoraState<T>> get stream async* {
    if (_isDisposed) return;

    // Émettre immédiatement l'état actuel
    yield state;

    // Puis écouter les futurs changements
    yield* _controller.stream;
  }

  // Stream<QoraState<T>> get stream => _controller.stream*;

  void updateState(QoraState<T> newState) {
    if (_isDisposed) return;

    state = newState;
    lastAccessedAt = DateTime.now();

    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _controller.close();
  }

  bool isStale(Duration staleTime) {
    return DateTime.now().difference(createdAt) > staleTime;
  }

  bool shouldEvict(Duration cacheTime) {
    return DateTime.now().difference(lastAccessedAt) > cacheTime;
  }
}

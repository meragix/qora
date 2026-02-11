import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';

/// Implémentation Flutter du LifecycleManager
class FlutterLifecycleManager extends LifecycleManager
    with WidgetsBindingObserver {
  final QoraClient _qoraClient;
  final Duration _refetchInterval;
  DateTime? _lastPausedAt;

  final _lifecycleController = StreamController<LifecycleState>.broadcast();

  @override
  Stream<LifecycleState> get lifecycleStream => _lifecycleController.stream;

  LifecycleState _currentState = LifecycleState.active;

  @override
  LifecycleState get currentState => _currentState;

  FlutterLifecycleManager({
    required QoraClient qoraClient,
    Duration refetchInterval = const Duration(seconds: 5),
  })  : _qoraClient = qoraClient,
        _refetchInterval = refetchInterval;

  @override
  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final qoreState = _mapFlutterState(state);
    _currentState = qoreState;
    _lifecycleController.add(qoreState);

    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
    }
  }

  LifecycleState _mapFlutterState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return LifecycleState.resumed;
      case AppLifecycleState.inactive:
        return LifecycleState.inactive;
      case AppLifecycleState.paused:
        return LifecycleState.paused;
      default:
        return LifecycleState.active;
    }
  }

  void _onAppResumed() {
    if (_lastPausedAt != null) {
      final pauseDuration = DateTime.now().difference(_lastPausedAt!);
      if (pauseDuration >= _refetchInterval) {
        _qoraClient.refetchOnWindowFocus();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleController.close();
  }
}

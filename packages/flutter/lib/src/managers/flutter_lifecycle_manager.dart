import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:qora/qora.dart';

/// Flutter implementation of [LifecycleManager].
///
/// Observes [AppLifecycleState] changes via [WidgetsBindingObserver] and
/// invalidates all cached queries when the app resumes after a pause longer
/// than [refetchInterval].
///
/// ## Setup
///
/// Pass an instance to [QoraScope]:
///
/// ```dart
/// final client = QoraClient();
///
/// QoraScope(
///   client: client,
///   lifecycleManager: FlutterLifecycleManager(
///     qoraClient: client,
///     refetchInterval: Duration(seconds: 30),
///   ),
///   child: MyApp(),
/// )
/// ```
class FlutterLifecycleManager extends LifecycleManager
    with WidgetsBindingObserver {
  final QoraClient _qoraClient;

  /// Minimum pause duration before queries are invalidated on resume.
  ///
  /// If the app was in the background for less than this duration, no
  /// invalidation occurs. Default: 5 seconds.
  final Duration refetchInterval;

  DateTime? _lastPausedAt;

  final _lifecycleController = StreamController<LifecycleState>.broadcast();
  LifecycleState _currentState = LifecycleState.active;

  @override
  Stream<LifecycleState> get lifecycleStream => _lifecycleController.stream;

  @override
  LifecycleState get currentState => _currentState;

  FlutterLifecycleManager({
    required QoraClient qoraClient,
    this.refetchInterval = const Duration(seconds: 5),
  }) : _qoraClient = qoraClient;

  @override
  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final qoraState = _mapFlutterState(state);
    _currentState = qoraState;
    _lifecycleController.add(qoraState);

    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
    }
  }

  LifecycleState _mapFlutterState(AppLifecycleState state) {
    return switch (state) {
      AppLifecycleState.resumed => LifecycleState.resumed,
      AppLifecycleState.inactive => LifecycleState.inactive,
      AppLifecycleState.paused => LifecycleState.paused,
      _ => LifecycleState.active,
    };
  }

  void _onAppResumed() {
    if (_lastPausedAt == null) return;
    final pauseDuration = DateTime.now().difference(_lastPausedAt!);
    if (pauseDuration >= refetchInterval) {
      // Invalidate all cached queries. Active QoraBuilder widgets detect the
      // resulting Loading(previousData: …) state and trigger a re-fetch.
      _qoraClient.invalidateWhere((_) => true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleController.close();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/data/event_repository_impl.dart';
import 'package:qora_devtools_ui/src/data/payload_repository_impl.dart';
import 'package:qora_devtools_ui/src/data/vm_service_client.dart';
import 'package:qora_devtools_ui/src/domain/dependency_notifier.dart';
import 'package:qora_devtools_ui/src/domain/network_activity_notifier.dart';
import 'package:qora_devtools_ui/src/domain/performance_notifier.dart';
import 'package:qora_devtools_ui/src/domain/queries_notifier.dart';
import 'package:qora_devtools_ui/src/domain/usecases/fetch_large_payload.dart';
import 'package:qora_devtools_ui/src/domain/usecases/observe_events.dart';
import 'package:qora_devtools_ui/src/domain/usecases/refetch_query.dart';
import 'package:qora_devtools_ui/src/ui/shell/app_shell.dart';
import 'package:qora_devtools_ui/src/ui/state/cache_controller.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';

/// Root widget for the Qora DevTools extension.
///
/// Does NOT provide its own [MaterialApp] — theming is handled by the
/// enclosing [DevToolsExtension] widget (from `devtools_extensions`), which
/// applies [themeFor] with [lightColorScheme] / [darkColorScheme] and
/// respects the IDE's background colour.
class QoraDevToolsApp extends StatefulWidget {
  /// Creates the root DevTools widget.
  const QoraDevToolsApp({super.key});

  @override
  State<QoraDevToolsApp> createState() => _QoraDevToolsAppState();
}

class _QoraDevToolsAppState extends State<QoraDevToolsApp> {
  late final VmServiceClient _vmClient;
  late final EventRepositoryImpl _eventRepository;
  late final QueriesNotifier _queriesNotifier;
  late final TimelineController _timelineController;
  late final CacheController _cacheController;
  late final NetworkActivityNotifier _networkNotifier;
  late final PerformanceNotifier _performanceNotifier;
  late final DependencyNotifier _dependencyNotifier;

  @override
  void initState() {
    super.initState();
    _vmClient = VmServiceClient();

    final payloadRepository = PayloadRepositoryImpl(vmClient: _vmClient);
    _eventRepository = EventRepositoryImpl(
      vmClient: _vmClient,
      payloadRepository: payloadRepository,
    );

    final observeEvents = ObserveEventsUseCase(_eventRepository);

    _queriesNotifier = QueriesNotifier();

    _timelineController = TimelineController(
      observeEvents: observeEvents,
      refetchQuery: RefetchQueryUseCase(_eventRepository),
    )..start();

    _cacheController = CacheController(
      repository: _eventRepository,
      observeEvents: observeEvents,
      queriesNotifier: _queriesNotifier,
    );

    _networkNotifier = NetworkActivityNotifier(observeEvents: observeEvents);
    _performanceNotifier = PerformanceNotifier(observeEvents: observeEvents);
    _dependencyNotifier = DependencyNotifier(observeEvents: observeEvents);
  }

  @override
  void dispose() {
    _timelineController.dispose();
    _cacheController.dispose();
    _queriesNotifier.dispose();
    _networkNotifier.dispose();
    _performanceNotifier.dispose();
    _dependencyNotifier.dispose();
    unawaited(_vmClient.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      timelineController: _timelineController,
      cacheController: _cacheController,
      queriesNotifier: _queriesNotifier,
      networkNotifier: _networkNotifier,
      performanceNotifier: _performanceNotifier,
      dependencyNotifier: _dependencyNotifier,
      refetch: RefetchQueryUseCase(_eventRepository),
      fetchLargePayload: FetchLargePayloadUseCase(_eventRepository),
      repository: _eventRepository,
    );
  }
}

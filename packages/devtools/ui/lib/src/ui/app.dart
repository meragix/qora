import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/data/event_repository_impl.dart';
import 'package:qora_devtools_ui/src/data/payload_repository_impl.dart';
import 'package:qora_devtools_ui/src/data/vm_service_client.dart';
import 'package:qora_devtools_ui/src/domain/usecases/observe_events.dart';
import 'package:qora_devtools_ui/src/domain/usecases/refetch_query.dart';
import 'package:qora_devtools_ui/src/ui/shell/app_shell.dart';
import 'package:qora_devtools_ui/src/ui/state/cache_controller.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';

/// Root Material application for the Qora DevTools extension.
class QoraDevToolsApp extends StatefulWidget {
  /// Creates the root DevTools application.
  const QoraDevToolsApp({super.key});

  @override
  State<QoraDevToolsApp> createState() => _QoraDevToolsAppState();
}

class _QoraDevToolsAppState extends State<QoraDevToolsApp> {
  late final VmServiceClient _vmClient;
  late final TimelineController _timelineController;
  late final CacheController _cacheController;

  @override
  void initState() {
    super.initState();
    _vmClient = VmServiceClient();

    final payloadRepository = PayloadRepositoryImpl(vmClient: _vmClient);
    final eventRepository = EventRepositoryImpl(
      vmClient: _vmClient,
      payloadRepository: payloadRepository,
    );

    _timelineController = TimelineController(
      observeEvents: ObserveEventsUseCase(eventRepository),
      refetchQuery: RefetchQueryUseCase(eventRepository),
    )..start();

    _cacheController = CacheController(repository: eventRepository);
  }

  @override
  void dispose() {
    _timelineController.dispose();
    _cacheController.dispose();
    unawaited(_vmClient.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: DevToolsColorScheme.light.materialTheme,
      darkTheme: DevToolsColorScheme.dark.materialTheme,
      home: AppShell(
        timelineController: _timelineController,
        cacheController: _cacheController,
      ),
    );
  }
}

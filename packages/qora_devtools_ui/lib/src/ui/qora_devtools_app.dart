import 'dart:async';

import 'package:flutter/material.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:qora_devtools_ui/src/data/event_repository_impl.dart';
import 'package:qora_devtools_ui/src/data/payload_repository_impl.dart';
import 'package:qora_devtools_ui/src/data/vm_service_client.dart';
import 'package:qora_devtools_ui/src/domain/usecases/observe_events.dart';
import 'package:qora_devtools_ui/src/domain/usecases/refetch_query.dart';
import 'package:qora_devtools_ui/src/ui/screens/cache_inspector_screen.dart';
import 'package:qora_devtools_ui/src/ui/screens/mutation_timeline_screen.dart';
import 'package:qora_devtools_ui/src/ui/screens/optimistic_updates_screen.dart';
import 'package:qora_devtools_ui/src/ui/state/cache_controller.dart';
import 'package:qora_devtools_ui/src/ui/state/timeline_controller.dart';

/// Root widget for the Qora DevTools extension UI.
class QoraDevToolsApp extends StatefulWidget {
  /// Creates the root app widget.
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
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Qora DevTools'),
            bottom: const TabBar(
              tabs: <Tab>[
                Tab(text: 'Cache'),
                Tab(text: 'Timeline'),
                Tab(text: 'Optimistic'),
              ],
            ),
            actions: <Widget>[
              DevToolsButton(
                tooltip: 'Refresh cache snapshot',
                onPressed: _cacheController.refresh,
                icon: Icons.refresh,
              ),
              DevToolsButton(
                tooltip: 'Clear timeline',
                onPressed: _timelineController.clear,
                icon: Icons.delete_sweep_outlined,
              ),
            ],
          ),
          body: TabBarView(
            children: <Widget>[
              CacheInspectorScreen(controller: _cacheController),
              MutationTimelineScreen(controller: _timelineController),
              OptimisticUpdatesScreen(controller: _timelineController),
            ],
          ),
        ),
      ),
    );
  }
}

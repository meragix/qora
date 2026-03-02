import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/domain/queries_notifier.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';
import 'package:qora_devtools_ui/src/domain/usecases/fetch_large_payload.dart';
import 'package:qora_devtools_ui/src/domain/usecases/refetch_query.dart';
import 'package:qora_devtools_ui/src/ui/screens/cache_inspector_screen.dart';
import 'package:qora_devtools_ui/src/ui/state/cache_controller.dart';

/// Main content of the QUERIES tab.
class QueriesTab extends StatelessWidget {
  /// Creates queries tab.
  const QueriesTab({
    super.key,
    required this.cacheController,
    required this.queriesNotifier,
    required this.refetch,
    required this.fetchLargePayload,
    required this.repository,
  });

  /// Cache controller bound to the tab.
  final CacheController cacheController;

  /// Live query list notifier.
  final QueriesNotifier queriesNotifier;

  /// Use-case for refetching a query.
  final RefetchQueryUseCase refetch;

  /// Use-case for loading large payloads on demand.
  final FetchLargePayloadUseCase fetchLargePayload;

  /// Repository used to dispatch invalidate commands.
  final EventRepository repository;

  @override
  Widget build(BuildContext context) {
    return CacheInspectorScreen(
      controller: cacheController,
      queriesNotifier: queriesNotifier,
      refetch: refetch,
      fetchLargePayload: fetchLargePayload,
      repository: repository,
    );
  }
}

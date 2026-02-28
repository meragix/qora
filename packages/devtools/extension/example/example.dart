// ignore_for_file: avoid_print

import 'package:qora/qora.dart';
import 'package:qora_devtools_extension/qora_devtools_extension.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

// ---------------------------------------------------------------------------
// TrackingGateway implementation
//
// TrackingGateway is the anti-corruption layer between the DevTools extension
// and QoraClient. It exposes only the operations DevTools needs — refetch,
// invalidate, rollback, and cache snapshot — without leaking QoraClient
// internals into the extension.
// ---------------------------------------------------------------------------

class AppTrackingGateway implements TrackingGateway {
  AppTrackingGateway(this._client);

  final QoraClient _client;

  @override
  Future<bool> refetch(String queryKey) async {
    // invalidate() marks the entry stale and triggers a background refetch
    // if any subscriber is currently watching the key.
    _client.invalidate(queryKey);
    return true;
  }

  @override
  Future<bool> invalidate(String queryKey) async {
    _client.invalidate(queryKey);
    return true;
  }

  @override
  Future<bool> rollbackOptimistic(String queryKey) async {
    // restoreQueryData rolls back an optimistic update to the previous
    // snapshot. Pass null to clear optimistic state entirely.
    _client.restoreQueryData(queryKey, null);
    return true;
  }

  @override
  Future<CacheSnapshot> getCacheSnapshot() async {
    // In a real app, walk QoraClient.getQueryState / activeMutations to
    // build the snapshot. This stub returns an empty snapshot for brevity.
    return CacheSnapshot(
      queries: const <QuerySnapshot>[],
      mutations: const <MutationSnapshot>[],
      emittedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

// ---------------------------------------------------------------------------
// Bridge setup
//
// The LazyPayloadManager instance MUST be shared between VmTracker and
// ExtensionHandlers so that chunks stored during onQueryFetched can be
// retrieved by ext.qora.getPayloadChunk.
// ---------------------------------------------------------------------------

QoraClient createDebugClient() {
  // 1. Shared lazy payload transport — handles large responses (> 80 KB) by
  //    chunking them into base64-encoded 80 KB pieces.
  final lazy = LazyPayloadManager();

  // 2. VmTracker — implements QoraTracker and publishes events via
  //    developer.postEvent. maxBuffer controls the ring-buffer size (FIFO).
  final tracker = VmTracker(
    lazyPayloadManager: lazy,
    maxBuffer: 500,
  );

  // 3. Create the QoraClient with the tracker injected.
  //    In release builds, omit the tracker — QoraClient defaults to
  //    NoOpTracker which has zero runtime overhead.
  final client = QoraClient(
    config: const QoraClientConfig(
      defaultOptions: QoraOptions(
        staleTime: Duration(minutes: 5),
        retryCount: 3,
      ),
    ),
    tracker: tracker,
  );

  // 4. Gateway bridges DevTools commands back to the client.
  final gateway = AppTrackingGateway(client);

  // 5. Handlers implement the request/response logic for each ext.qora.*
  //    method; they validate params and delegate to the gateway or lazy store.
  final handlers = ExtensionHandlers(
    gateway: gateway,
    lazyPayloadManager: lazy,
  );

  // 6. Register all ext.qora.* VM service extensions.
  //    Call this exactly once before opening the DevTools panel.
  //
  //    Extensions registered:
  //      ext.qora.refetch
  //      ext.qora.invalidate
  //      ext.qora.rollbackOptimistic
  //      ext.qora.getCacheSnapshot
  //      ext.qora.getPayloadChunk
  //      ext.qora.getPayload  ← legacy alias
  ExtensionRegistrar(handlers: handlers).registerAll();

  return client;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main() async {
  // Debug / profile builds wire the DevTools bridge.
  // Release builds call QoraClient() directly (NoOpTracker by default).
  final client = createDebugClient();

  // Example: fetch a query and print each state transition.
  final states = <QoraState<String>>[];

  final sub = client.watchQuery<String>(
    key: const ['greeting'],
    fetcher: () async {
      // Simulate a network call.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return 'hello from Qora';
    },
  ).listen(states.add);

  // Wait for the fetch to settle.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await sub.cancel();

  for (final state in states) {
    switch (state) {
      case Initial():
        print('initial — no data yet');
      case Loading(:final previousData):
        print('loading… (previous: $previousData)');
      case Success(:final data):
        print('success: $data');
      case Failure(:final error):
        print('error: $error');
    }
  }

  print('config staleTime: ${client.config.defaultOptions.staleTime}');

  client.dispose();
}

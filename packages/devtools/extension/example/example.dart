// ignore_for_file: avoid_print

import 'package:qora/qora.dart';
import 'package:qora_devtools_extension/qora_devtools_extension.dart';

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

  // 4. Wire DevTools commands back to the client via QoraClientTrackingGateway.
  //    This default implementation covers refetch, invalidate, rollback, and
  //    cache snapshot without any extra boilerplate.
  //    To intercept or customise behaviour, implement TrackingGateway directly.
  ExtensionRegistrar(
    handlers: ExtensionHandlers(
      gateway: QoraClientTrackingGateway(client),
      lazyPayloadManager: lazy,
    ),
  ).registerAll();

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

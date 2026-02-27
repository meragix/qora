# qora_devtools_extension

Runtime VM service bridge for Qora DevTools.

This package runs inside your app isolate and exposes Qora runtime activity to
Flutter DevTools through Dart VM Service Extensions.

It is responsible for:

- publishing events (`developer.postEvent`),
- registering `ext.qora.*` extension methods,
- handling UI commands (refetch, invalidate, rollback),
- serving cache snapshots,
- lazy-loading large JSON payloads via chunked transport.

## Architecture role

- `qora`: core state management runtime.
- `qora_devtools_shared`: protocol contracts (events, commands, codecs).
- `qora_devtools_extension` (this package): runtime-side adapter/bridge.
- `qora_devtools_ui`: DevTools extension client UI.

## Features

- `VmTracker` implementation of `QoraTracker`.
- `VmEventPusher` abstraction around `developer.postEvent`.
- `ExtensionRegistrar` + `ExtensionHandlers` for VM extension endpoints:
  - `ext.qora.refetch`
  - `ext.qora.invalidate`
  - `ext.qora.rollbackOptimistic`
  - `ext.qora.getCacheSnapshot`
  - `ext.qora.getPayloadChunk`
  - legacy alias: `ext.qora.getPayload`
- Lazy payload transport:
  - chunking (`PayloadChunker`),
  - bounded in-memory storage (`PayloadStore`),
  - retrieval orchestration (`LazyPayloadManager`).

## Quick start

### 1) Implement a tracking gateway

```dart
import 'package:qora_devtools_extension/qora_devtools_extension.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class AppTrackingGateway implements TrackingGateway {
  @override
  Future<bool> refetch(String queryKey) async {
    // call your runtime/client API
    return true;
  }

  @override
  Future<bool> invalidate(String queryKey) async {
    return true;
  }

  @override
  Future<bool> rollbackOptimistic(String queryKey) async {
    return true;
  }

  @override
  Future<CacheSnapshot> getCacheSnapshot() async {
    return const CacheSnapshot(
      queries: <QuerySnapshot>[],
      mutations: <MutationSnapshot>[],
      emittedAtMs: 0,
    );
  }
}
```

### 2) Wire and register VM extensions

```dart
import 'package:qora_devtools_extension/qora_devtools_extension.dart';

void setupQoraDevtoolsBridge() {
  final lazy = LazyPayloadManager();
  final gateway = AppTrackingGateway();

  final handlers = ExtensionHandlers(
    gateway: gateway,
    lazyPayloadManager: lazy,
  );

  const pusher = VmEventPusher();
  final tracker = VmTracker(
    lazyPayloadManager: lazy,
    eventPusher: pusher,
  );

  final registrar = ExtensionRegistrar(handlers: handlers);
  registrar.registerAll();

  // Inject `tracker` into your Qora client/runtime.
}
```

## Memory safety notes

- Event history is bounded (ring buffer).
- Lazy payloads are bounded by byte budget and TTL.
- Store eviction uses LRU order under memory pressure.
- `VmTracker.dispose()` clears local retained state.

## Compatibility notes

- Protocol names are sourced from `qora_devtools_shared`.
- Legacy `ext.qora.getPayload` remains registered for backward compatibility.

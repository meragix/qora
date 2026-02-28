# qora_devtools_extension

Runtime bridge that exposes [Qora](https://pub.dev/packages/qora) internals to
Flutter DevTools.

This package runs inside your **app isolate** and has zero cost in release
builds — it is only active when a `VmTracker` is injected into `QoraClient`.

## Architecture

```text
┌──────────────────────────────────────────────────────┐
│  Your app                                             │
│  ┌────────────┐   QoraTracker   ┌──────────────────┐ │
│  │ QoraClient │ ─────────────►  │   VmTracker      │ │
│  └────────────┘                 │ (events + lazy   │ │
│                                 │  payload chunks) │ │
│                                 └────────┬─────────┘ │
│                              developer.postEvent      │
│                                          │            │
│  ┌─────────────────────────────────────── ▼ ────────┐ │
│  │  ext.qora.*  VM service extensions               │ │
│  │  (refetch · invalidate · rollback · snapshot)    │ │
│  └──────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
         ▲ DevTools UI (qora_devtools_ui) reads these
```

| Package                    | Role                                                    |
| -------------------------- | ------------------------------------------------------- |
| `qora`                     | Core state-management runtime                           |
| `qora_devtools_shared`     | Protocol contracts (events, commands, codecs)           |
| `qora_devtools_extension`  | **This package** — runtime-side adapter/bridge          |
| `qora_devtools_ui`         | DevTools extension client UI (separate Flutter project) |

## Features

- `VmTracker` — `QoraTracker` implementation that publishes typed events via
  `developer.postEvent`.
- `VmEventPusher` — thin, injectable wrapper around `developer.postEvent`.
- `TrackingGateway` — abstract interface for routing DevTools commands back to
  your `QoraClient`.
- `ExtensionHandlers` — per-command request handlers (validate → delegate →
  respond).
- `ExtensionRegistrar` — registers all `ext.qora.*` VM service extensions in
  one call.
- Lazy payload transport for large cache responses:
  - `PayloadChunker` — splits and reassembles byte arrays.
  - `PayloadStore` — bounded in-memory store with TTL and LRU eviction.
  - `LazyPayloadManager` — orchestrates push (store) / pull (chunk) strategy.

## Installation

```yaml
dependencies:
  qora: ^0.4.0
  qora_devtools_extension: ^0.1.0
  qora_devtools_shared: ^0.1.0
```

> Only add this package to debug / profile builds. In release, use the default
> `NoOpTracker` (built into `qora`) which has zero runtime overhead.

## Quick start

### 1 — Implement `TrackingGateway`

`TrackingGateway` is the anti-corruption layer between the DevTools extension
and your `QoraClient`. Implement it once and pass it to `ExtensionHandlers`.

```dart
import 'package:qora/qora.dart';
import 'package:qora_devtools_extension/qora_devtools_extension.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

class AppTrackingGateway implements TrackingGateway {
  AppTrackingGateway(this._client);

  final QoraClient _client;

  @override
  Future<bool> refetch(String queryKey) async {
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
    _client.restoreQueryData(queryKey, null);
    return true;
  }

  @override
  Future<CacheSnapshot> getCacheSnapshot() async {
    // Build a point-in-time snapshot of every active query/mutation.
    // Use QoraClient.getQueryState / activeMutations for production data.
    return CacheSnapshot(
      queries: const [],
      mutations: const [],
      emittedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
```

### 2 — Wire the bridge at startup

Call `setupQoraDevtools` once, **before** the DevTools panel is opened.
The `LazyPayloadManager` instance must be shared between `VmTracker` and
`ExtensionHandlers` so that large payloads stored during fetch can be pulled
back by the UI.

```dart
import 'package:qora/qora.dart';
import 'package:qora_devtools_extension/qora_devtools_extension.dart';

QoraClient createDebugClient() {
  final lazy = LazyPayloadManager();

  final tracker = VmTracker(lazyPayloadManager: lazy);

  final gateway = AppTrackingGateway(/* pass the client after creation */);

  final handlers = ExtensionHandlers(
    gateway: gateway,
    lazyPayloadManager: lazy,
  );

  ExtensionRegistrar(handlers: handlers).registerAll();

  return QoraClient(tracker: tracker);
}
```

### 3 — Separate debug and release entry points

```dart
// lib/main_release.dart
void main() => runApp(MyApp(client: QoraClient()));

// lib/main_debug.dart
void main() {
  final lazy    = LazyPayloadManager();
  final tracker = VmTracker(lazyPayloadManager: lazy);
  final client  = QoraClient(tracker: tracker);

  final gateway  = AppTrackingGateway(client);
  final handlers = ExtensionHandlers(
    gateway: gateway,
    lazyPayloadManager: lazy,
  );
  ExtensionRegistrar(handlers: handlers).registerAll();

  runApp(MyApp(client: client));
}
```

## VM extension endpoints

| Method                       | Description                                           |
| ---------------------------- | ----------------------------------------------------- |
| `ext.qora.refetch`           | Triggers an immediate refetch for a query key.        |
| `ext.qora.invalidate`        | Marks a key stale and schedules a background refetch. |
| `ext.qora.rollbackOptimistic`| Rolls back an in-progress optimistic update.          |
| `ext.qora.getCacheSnapshot`  | Returns a full `CacheSnapshot` JSON object.           |
| `ext.qora.getPayloadChunk`   | Pulls one base64-encoded chunk of a large payload.    |
| `ext.qora.getPayload`        | Legacy alias for `getPayloadChunk`.                   |

## Lazy payload transport

`VmTracker` automatically decides whether to inline or chunk each payload:

- **Inline** (≤ 80 KB serialised): the event carries the full data — zero
  extra round-trips.
- **Chunked** (> 80 KB): the event carries only metadata (`payloadId`,
  `totalChunks`, `summary`). The DevTools UI calls `ext.qora.getPayloadChunk`
  once per chunk and reassembles the full JSON.

`PayloadStore` enforces:

- **TTL** of 30 s per entry — pull promptly after the event arrives.
- **LRU cap** of 20 MB total — oldest entries are evicted under pressure.

Call `VmTracker.dispose()` (and therefore `LazyPayloadManager.clear()`) when
the owning `QoraClient` is no longer needed.

## Memory safety

| Guarantee                              | Component              |
| -------------------------------------- | ---------------------- |
| Ring buffer capped at N events         | `VmTracker`            |
| All emits are no-ops after `dispose()` | `VmTracker`            |
| Chunk store bounded to 20 MB           | `PayloadStore`         |
| TTL of 30 s per payload entry          | `PayloadStore`         |
| LRU eviction when budget exceeded      | `PayloadStore`         |

## Tuning `VmTracker`

```dart
VmTracker(
  lazyPayloadManager: lazy,
  maxBuffer: 200,   // reduce ring buffer for memory-constrained devices
)
```

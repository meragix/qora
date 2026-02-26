# qora_devtools_shared

Shared protocol package for Qora DevTools.

This package contains the transport contracts used by:

- `qora_devtools_extension` (runtime bridge, app side),
- `qora_devtools_ui` (Flutter DevTools extension UI, client side).

It is intentionally Flutter-agnostic and focuses on:

- typed events,
- typed commands,
- JSON codecs,
- VM extension method/event constants,
- cache/mutation/query snapshots.

## Why this package exists

`qora` (the core state-management package) should not depend on visual tooling.
`qora_devtools_shared` provides a stable protocol boundary so core, extension,
and UI can evolve independently without circular imports.

## Features

- Event contracts:
  - `QoraEvent`,
  - `QueryEvent`,
  - `MutationEvent`,
  - `GenericQoraEvent` fallback for forward compatibility.
- Command contracts:
  - `RefetchCommand`,
  - `InvalidateCommand`,
  - `RollbackOptimisticCommand`,
  - `GetCacheSnapshotCommand`,
  - `GetPayloadChunkCommand`.
- Codecs:
  - `EventCodec`,
  - `CommandCodec`.
- Protocol constants:
  - `QoraExtensionMethods` (`ext.qora.*`),
  - `QoraExtensionEvents` (`qora:event`).
- Snapshot DTOs:
  - `QuerySnapshot`,
  - `MutationSnapshot`,
  - `CacheSnapshot`.

## Installation

```yaml
dependencies:
  qora_devtools_shared:
    path: ../qora_devtools_shared
```

## Usage

### Decode incoming VM extension event

```dart
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

void onRawEvent(Map<String, Object?> raw) {
  final event = EventCodec.decode(raw);

  if (event is QueryEvent) {
    print('Query event: ${event.type} for ${event.key}');
  }
}
```

### Build and send command from UI

```dart
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

final command = RefetchCommand(queryKey: 'todos?page=1');

final extensionName = '${QoraExtensionMethods.prefix}.${command.method}';
final params = command.params;
```

### Snapshot serialization

```dart
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

final snapshot = CacheSnapshot(
  queries: const <QuerySnapshot>[],
  mutations: const <MutationSnapshot>[],
  emittedAtMs: DateTime.now().millisecondsSinceEpoch,
);

final json = snapshot.toJson();
final restored = CacheSnapshot.fromJson(json);
```

## Protocol notes

- Event payloads should stay lightweight by default.
- Large data should be represented through metadata
  (`hasLargePayload`, `payloadId`, `totalChunks`) and fetched lazily with
  `GetPayloadChunkCommand`.
- Unknown event kinds are decoded as `GenericQoraEvent` to avoid hard failures
  when producer and consumer versions are not perfectly aligned.

## Stability and versioning

- Follow semantic versioning.
- Breaking protocol changes must increment the major version.
- Adding new event/command types should be backward-compatible when possible.

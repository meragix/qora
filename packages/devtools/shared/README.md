# qora_devtools_shared

Protocol contracts, models, and codecs shared across the Qora DevTools
ecosystem — the runtime bridge, the in-app overlay, and the DevTools UI.

This package is the **single source of truth** for the JSON communication
contract. All consumers import it so that string constants, event shapes, and
command structures stay in sync across independent releases.

## Architecture role

```text
App isolate                              DevTools UI
(qora_devtools_extension)                (qora_devtools_ui)
        │                                        │
        │  push: developer.postEvent             │
        │  ──── QoraExtensionEvents.qoraEvent ──►│
        │       EventCodec.encode(event)         │
        │                                        │
        │  pull: callServiceExtension            │
        │◄───── QoraExtensionMethods.refetch ────│
        │       CommandCodec.decode(response)    │

(qora_devtools_overlay)
        │  uses TimelineEvent + TimelineEventType
        │  for the in-app query/mutation overlay
```

All three packages share this package. None of them imports the others.

## Features

**Events (push) — App to DevTools:**

- `QoraEvent` — base class with `eventId`, `kind`, `timestampMs`
- `QueryEvent` — query lifecycle: `fetched`, `invalidated`, `added`, `updated`, `removed`
- `MutationEvent` — mutation lifecycle: `started`, `settled`, `updated`
- `GenericQoraEvent` — forward-compatible fallback for unknown kinds
- `TimelineEvent` — lightweight record for the in-app overlay tracker

**Commands (pull) — DevTools to App:**

- `RefetchCommand`, `InvalidateCommand`, `RollbackOptimisticCommand`
- `GetCacheSnapshotCommand`, `GetPayloadChunkCommand`

**Codecs:**

- `EventCodec` — decodes raw VM event maps into typed `QoraEvent` subclasses
- `CommandCodec` — decodes raw maps into typed `QoraCommand` subclasses

**Models:**

- `CacheSnapshot`, `QuerySnapshot`, `MutationSnapshot` — JSON-serialisable DTOs

**Protocol constants:**

- `QoraExtensionMethods` — `ext.qora.*` VM extension method names
- `QoraExtensionEvents` — `qora:event` stream key

## Installation

```yaml
dependencies:
  qora_devtools_shared: ^0.1.0
```

## Usage

### Encode and push an event (runtime bridge side)

```dart
import 'dart:developer' as developer;
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

// Push a query-fetched event to the DevTools UI.
final event = QueryEvent.fetched(
  key: '["users"]',
  data: {'id': 1, 'name': 'Alice'},
  status: 'success',
);

developer.postEvent(
  QoraExtensionEvents.qoraEvent,
  EventCodec.encode(event),
);
```

### Decode an incoming event (DevTools UI side)

```dart
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

void onVmServiceEvent(Map<String, Object?> raw) {
  final event = EventCodec.decode(raw);

  switch (event) {
    case QueryEvent(:final key, :final type, :final hasLargePayload):
      print('Query $type for $key — large: $hasLargePayload');
    case MutationEvent(:final id, :final type, :final success):
      print('Mutation $id $type — ok: $success');
    case GenericQoraEvent(:final kind):
      print('Unknown event kind: $kind');
  }
}
```

`GenericQoraEvent` is returned for unrecognised kinds, ensuring the UI stays
functional when the runtime sends events from a newer version of the package.

### Send a command from the DevTools UI

```dart
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

// Build a typed command.
final cmd = RefetchCommand(queryKey: '["users"]');

// Dispatch it via the VM service client (pseudo-code).
await vmService.callServiceExtension(
  '${QoraExtensionMethods.prefix}.${cmd.method}', // 'ext.qora.refetch'
  args: cmd.params,                                // {'queryKey': '["users"]'}
);
```

### Decode a command (for testing or logging)

```dart
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

// Accepts both short ('refetch') and full ('ext.qora.refetch') method forms.
final cmd = CommandCodec.decode({
  'method': 'ext.qora.invalidate',
  'params': {'queryKey': '["posts"]'},
});

if (cmd is InvalidateCommand) {
  print('Invalidate: ${cmd.queryKey}');
}
```

### Snapshot serialization roundtrip

```dart
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

final snapshot = CacheSnapshot(
  queries: [
    QuerySnapshot(
      key: '["users"]',
      status: 'success',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      data: [{'id': 1, 'name': 'Alice'}],
    ),
  ],
  mutations: const [],
  emittedAtMs: DateTime.now().millisecondsSinceEpoch,
);

// Serialise → transport → deserialise.
final json = snapshot.toJson();
final restored = CacheSnapshot.fromJson(json);

print(restored.queries.first.key);   // ["users"]
print(restored.queries.first.status); // success
```

### Timeline events (overlay tracker)

`TimelineEvent` is a lightweight record used by the in-app overlay tracker.
It carries a `TimelineEventType` with a `displayName` getter for UI labels.

```dart
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

final event = TimelineEvent(
  type: TimelineEventType.fetchStarted,
  key: '["products"]',
  timestamp: DateTime.now(),
);

print(event.type.displayName); // 'Fetch Started'
```

## Protocol notes

- **Push direction** (App → DevTools): lightweight `QoraEvent` payloads via
  `developer.postEvent` on the `"Extension"` VM service stream.
- **Pull direction** (DevTools → App): commands via `callServiceExtension`.
- **Large payloads**: when a query result exceeds ~80 KB, `QueryEvent` carries
  only metadata (`hasLargePayload: true`, `payloadId`, `totalChunks`, `summary`).
  The UI then pulls individual 80 KB chunks via `GetPayloadChunkCommand`.
- **Forward compatibility**: unknown event kinds decode to `GenericQoraEvent`
  rather than throwing, so UI and runtime can be updated independently.

## Versioning discipline

| Change type             | Version bump |
| ----------------------- | ------------ |
| New event/command kind  | minor        |
| New optional JSON field | minor        |
| Renamed/removed field   | **major**    |
| New required field      | **major**    |

Both `qora_devtools_extension` and `qora_devtools_ui` must pin compatible
version constraints whenever the JSON schema changes.

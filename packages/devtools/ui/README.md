# qora_devtools_ui

Flutter Web DevTools extension UI for Qora.

This package is the client-side interface rendered inside Flutter DevTools
(VS Code / IntelliJ / browser DevTools). It consumes the protocol defined in
`qora_devtools_shared` and communicates with the app runtime through Dart VM
service extensions exposed by `qora_devtools_extension`.

## Responsibilities

- Listen to runtime extension events (`qora:event`).
- Decode and render query/mutation/optimistic timeline data.
- Send commands to runtime (`refetch`, `invalidate`, etc.).
- Lazy-load large payloads in chunks for cache inspection.

## Architecture

- Data:
  - `VmServiceClient`
  - `EventRepositoryImpl`
  - `PayloadRepositoryImpl`
- Domain:
  - repository contracts
  - use-cases (`ObserveEventsUseCase`, `RefetchQueryUseCase`, `FetchLargePayloadUseCase`)
- UI:
  - app shell + screens
  - controllers (`TimelineController`, `CacheController`)

## Entry point

```dart
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:qora_devtools_ui/src/ui/qora_devtools_app.dart';

void main() {
  runApp(const DevToolsExtension(child: QoraDevToolsApp()));
}
```

## Runtime dependencies

This package expects the target app to register VM service methods:

- `ext.qora.refetch`
- `ext.qora.invalidate`
- `ext.qora.rollbackOptimistic`
- `ext.qora.getCacheSnapshot`
- `ext.qora.getPayloadChunk`

Those methods are typically provided by `qora_devtools_extension`.

## Notes

- Payload-heavy query data should be fetched lazily using `payloadId` and
  `totalChunks` metadata.
- Unknown event kinds are safely handled by the shared protocol fallback model.

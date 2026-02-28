# qora_devtools_overlay

In-app debug overlay for [Qora](https://pub.dev/packages/qora). Injects a floating action button
and a three-column panel (Queries · Mutations · Timeline) directly into the running Flutter app.

Zero overhead in release builds — `QoraInspector` returns its `child` unchanged and the entire
widget tree is tree-shaken by the Dart compiler.

## Architecture

```text
QoraClient ──onQueryFetched──────▶ OverlayTracker ──streams──▶ notifiers ──▶ panel UI
           ──onMutationStarted──▶                 ──history──▶
           ──onOptimisticUpdate──▶
```

`OverlayTracker` implements the `QoraTracker` interface from the core `qora` package.
It converts hook calls into typed `QueryEvent`, `MutationEvent`, and `TimelineEvent` objects
(defined in `qora_devtools_shared`) and fans them out to broadcast streams and ring-buffers.

## Features

- **Floating action button** — tap to open the panel; close button returns to the app
- **Queries tab** — live list of query keys with status badges and last-updated timestamps
- **Mutations tab** — pending and settled mutations with variable payload previews
- **Timeline tab** — chronological event stream: fetch · mutation · optimistic · cache clear
- **Zero-cost release** — `QoraInspector.build` returns `widget.child` when `!kDebugMode`
- **Bounded memory** — ring-buffer capped at 200 events per channel; FIFO eviction on overflow

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  qora_devtools_overlay: ^0.1.0
```

## Usage

```dart
import 'package:flutter/foundation.dart';
import 'package:qora/qora.dart';
import 'package:qora_devtools_overlay/qora_devtools_overlay.dart';

void main() {
  // 1. Create a shared tracker.
  final tracker = OverlayTracker();

  // 2. Connect it to QoraClient — pass null in release so the client uses
  //    NoOpTracker and no events are emitted.
  final client = QoraClient(tracker: kDebugMode ? tracker : null);

  // 3. Wrap your app — QoraInspector is a no-op in release builds.
  runApp(
    QoraInspector(
      tracker: tracker,
      child: MyApp(client: client),
    ),
  );
}
```

## Panel overview

| Tab           | What you see                                                                        |
|---------------|-------------------------------------------------------------------------------------|
| **Queries**   | Active query keys, status (loading · success · error), last-updated time            |
| **Mutations** | Pending and settled mutations with variable payload preview                         |
| **Timeline**  | `fetchStarted` · `mutationStarted` · `mutationSuccess` · `mutationError` · `optimisticUpdate` · `cacheCleared` |

## Memory safety

| Guarantee          | Detail                                                              |
|--------------------|---------------------------------------------------------------------|
| Ring-buffer cap    | 200 events per channel; oldest event evicted on overflow (FIFO)    |
| `dispose()`        | Closes all `StreamController`s and clears all buffers and caches   |
| Release overhead   | `QoraInspector.initState` is a no-op when `!kDebugMode`            |

## Additional information

- Source: [packages/devtools/overlay](https://github.com/meragix/qora/tree/main/packages/devtools/overlay)
- Issues: [github.com/meragix/qora/issues](https://github.com/meragix/qora/issues)
- Part of the Qora DevTools suite:
  [qora_devtools_extension](https://pub.dev/packages/qora_devtools_extension) ·
  [qora_devtools_shared](https://pub.dev/packages/qora_devtools_shared)

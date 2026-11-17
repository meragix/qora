# qora_devtools_overlay

<a href="https://pub.dev/packages/qora_devtools_overlay"><img src="https://img.shields.io/pub/v/qora_devtools_overlay.svg" alt="pub.dev"></a>
<a href="https://github.com/meragix/qora/actions/workflows/overlay.yml"><img src="https://img.shields.io/github/actions/workflow/status/meragix/qora/overlay.yml?branch=main&label=ci" alt="CI"></a>

In-app debug overlay for [Qora](https://pub.dev/packages/qora). Injects a floating button and a panel with Queries, Mutations, Queue and Timeline tabs into the running Flutter app.

Part of the [Qora monorepo](https://github.com/meragix/qora).

Zero overhead in release builds: `QoraInspector` returns its `child` unchanged and the overlay is tree-shaken by the Dart compiler.

## Features

- **Queries**: one row per query key with its status (fetching, success, error, stale, idle), observers and time left before it goes stale. Details show the cached data and the options reported by the last fetch, with Invalidate, Remove, Mark Stale and Simulate Error actions.
- **Mutations**: pending and settled mutations, with their variables, result or error, and duration.
- **Queue**: the calls waiting in `client.mutationQueue` (Qora 1.4): status (queued, sending, blocked, held, failed), attempts, scope, last error and variables. Read only: retrying or discarding stays in the app.
- **Timeline**: fetches, cancellations, invalidations, `setQueryData` writes, mutations and cache clears, in order.

## Getting started

```yaml
dependencies:
  qora_devtools_overlay: ^0.4.0
```

Add it to `dependencies`, not `dev_dependencies`: `main.dart` imports it. It costs nothing in release builds.

## Usage

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/qora_devtools_overlay.dart';
import 'package:qora_flutter/qora_flutter.dart';

void main() {
  final tracker = OverlayTracker();
  final client = QoraClient(tracker: kDebugMode ? tracker : null);

  runApp(
    QoraInspector(
      tracker: tracker,
      // Enables the query actions and the Queue tab.
      client: kDebugMode ? client : null,
      child: QoraScope.auto(client: client, child: const MyApp()),
    ),
  );
}
```

## How it works

`OverlayTracker` implements `QoraTracker` from `qora`. It turns hook calls into the `QueryEvent`, `MutationEvent` and `TimelineEvent` objects of `qora_devtools_shared`, keeps the last 200 of each in a ring buffer, and streams them to the panel. The Queue tab reads `client.mutationQueue` directly, so it also shows calls restored by `PersistQoraClient.hydrate()`.

The query list is rebuilt from tracker events, not read from the cache. Two writes the core does not report to the tracker create no row: hydration from `PersistQoraClient` and `initialData`. Reading the cache directly is planned for 0.5.0.

## Additional information

- Source: [packages/devtools/overlay](https://github.com/meragix/qora/tree/main/packages/devtools/overlay)
- Issues: [github.com/meragix/qora/issues](https://github.com/meragix/qora/issues)
- Part of the Qora DevTools suite:
  [qora_devtools_extension](https://pub.dev/packages/qora_devtools_extension) ·
  [qora_devtools_shared](https://pub.dev/packages/qora_devtools_shared)

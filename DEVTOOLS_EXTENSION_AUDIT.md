# Qora DevTools extension audit

Scope: the Flutter DevTools tab, made of three packages:

- `packages/devtools/extension` (`qora_devtools_extension` 0.2.0): the bridge in the app isolate (`VmTracker`, `ext.qora.*` handlers, lazy payload chunks);
- `packages/devtools/ui` (`qora_devtools_ui`): the Flutter web app shown in the DevTools tab;
- `packages/devtools/shared` (`qora_devtools_shared` 0.2.0): the protocol between them.

Companion document: [DEVTOOLS_AUDIT.md](DEVTOOLS_AUDIT.md) (the in-app overlay). Read it first: the core debug API and the redesign it proposes are the foundation of everything below.

**Status: later.** The overlay ships first. The DevTools tab is planned after the overlay redesign (overlay roadmap P2). Two things in this document still matter now, because they constrain the overlay work:

1. the core debug API (overlay audit, section 4.2) must be designed for both consumers, in-process and over the VM Service;
2. the overlay's UI components must be written so the web tab can reuse them (section 6).

Method: every file of `extension/lib` and the data, state and shell layers of `ui/lib` read; claims about the core checked in `packages/dart/lib/src/client/qora_client.dart`. Nothing below was run against a live DevTools session, because, as E1 shows, the tab cannot connect today.

---

## 1. Verdict

The extension package is the best-engineered part of the devtools module: bounded ring buffer (`ListQueue`), payload store with LRU, TTL and a 20 MB budget, a protocol version handshake, a `TrackingGateway` seam for tests. The web UI has ambitious screens (network activity, performance, dependency graph).

But **the DevTools tab does not work end to end**, and it is not distributable:

- the web UI never connects to the VM Service (E1), so it receives no events and every command throws;
- the package carrying the DevTools config is `publish_to: none`, and the compiled web app is not committed (E2);
- one of its four actions deletes the query it claims to roll back (E3).

The UI's only test checks static text, which is why this went unnoticed.

Recommendation: do not invest in the current web UI. Keep the extension's good parts (ring buffer, version handshake, gateway seam), rebuild the protocol on the core debug API proposed for the overlay, and render the tab with the overlay's components. One model, one UI, two transports.

| Area | Score | One line |
| --- | --- | --- |
| Works end to end | 0/10 | No VM Service connection (E1). |
| Distribution | 1/10 | Not on pub; web build not shipped (E2). |
| Extension (bridge) design | 6/10 | Solid buffers and seams; triple serialization; payload TTL breaks late inspection. |
| Protocol | 4/10 | Push-heavy, stringly-typed statuses, no replay, no paging of large data. |
| Web UI | 3/10 | Fork of the overlay, ALL CAPS tabs, screens built on an event feed that never arrives. |
| Tests | 1/10 | 3 extension tests, 1 UI smoke test. |

---

## 2. Verified defects

Each item was checked by reading the code at the cited location.

| Id | Defect | Evidence | Impact |
| --- | --- | --- | --- |
| E1 | The web UI never connects. `VmServiceClient.connect()` is defined but never called; `QoraIsolateManager` is unused; nothing reads `serviceManager` from `devtools_extensions`. | `grep -rn "connect" ui/lib` finds only the definition. | No event reaches the UI. `sendCommand` throws `StateError('VmServiceClient is not connected')`, so Refresh, Refetch and payload loading all fail. |
| E2 | Not distributable. `qora_devtools_extension` (which holds `extension/devtools/config.yaml`) is `publish_to: none`. The web build is produced by a workspace script into `extension/extension/devtools/build`, which `build/` in `.gitignore` excludes. | `extension/pubspec.yaml`, root `pubspec.yaml` scripts, `.gitignore`. | A user cannot enable the Qora tab in DevTools. |
| E3 | "Rollback optimistic" removes the query. `QoraClientTrackingGateway.rollbackOptimistic` calls `restoreQueryData(key, null)`, and the core documents and implements "if `snapshot` is null, the query is removed from cache entirely". The gateway comment claims it "reinstates the pre-optimistic snapshot"; the core keeps no such snapshot. | `qora_client_tracking_gateway.dart`, `qora_client.dart` `restoreQueryData`. | A debug action destroys app state. |
| E4 | "Refetch" is `invalidate()`, the same mislabel as the overlay. It returns whether a watcher exists, so the UI cannot tell "fetched" from "marked stale". | gateway `refetch`. | Inactive queries are never refetched from the tab. |
| E5 | `getCacheSnapshot` is lossy and fragile: `updatedAtMs` is "now" for every query; status has no `stale`, `fetching` or `paused`; `data` is the raw cached object, then `jsonEncode`d in `ExtensionHandlers._ok`, so one non-JSON model (a plain Dart class without `toJson`) makes the whole snapshot throw. | gateway `getCacheSnapshot`, `QuerySnapshot.toJson`, handlers `_ok`. | The snapshot, the only recovery path after a missed event, fails on typical apps. |
| E6 | Large payload chunks expire after 30 s. Data larger than one chunk is only stored at fetch time; selecting that query later returns `expired_or_not_found`. | `PayloadStore` TTL, `LazyPayloadManager.getChunk`. | The data of a query fetched a minute ago cannot be inspected. |
| E7 | Each fetch result is serialized three times: the core's `_serializeForTracker`, then `LazyPayloadManager.store` (`jsonEncode` then `jsonDecode` for inline data), then `_summarizeData` (`jsonEncode` again). This runs on every fetch, whether DevTools is open or not. | `vm_qora_tracker.dart`, `lazy_payload_manager.dart`. | Debug-mode jank proportional to payload size, with no one watching. |
| E8 | `onMutationSettled` emits `key: ''`. | `vm_qora_tracker.dart`. | Settled mutations cannot be matched to their key in the UI. |
| E9 | Same hook blind spots as the overlay: fetch failures are not reported by the core, and `onQueryFetching` only records a start time (no event). | core `_doFetch`, `VmTracker.onQueryFetching`. | No loading or error state over the wire. |
| E10 | No replay. `VmTracker.recentEvents` exists, but no extension method exposes it. Opening DevTools after startup shows nothing until the next event. | `extension_registrar.dart`. | The first minutes of a session, usually the interesting ones, are invisible. |
| E11 | `QoraDevtools.setup` is not idempotent: `developer.registerExtension` throws on a second registration in the same isolate, and `setup` asserts if the client already has a tracker, which is how the overlay README tells users to build their client. | `qora_devtools.dart`, `extension_registrar.dart`. | Overlay and DevTools tab cannot be combined by following the docs. |
| E12 | `auto_register.dart` is a design sketch in `lib/`: an empty `@pragma('vm:entry-point')` function, box-drawing diagrams, em dashes. | `extension/lib/src/auto_register.dart`. | Dead code in a package; the pragma keeps an empty symbol alive. |

Documentation: `docs/content/en/06.devtools/1.overview.md` promises "every mutation with its variables and rollback context". The overlay never populates the rollback context (overlay audit, 2.2). The docs no longer describe the DevTools tab, which is right until E1 and E2 are fixed.

---

## 3. How a Qora DevTools tab should work

### 3.1 Flutter DevTools extension mechanics

- DevTools discovers an extension from a package in the app's dependency graph that contains `extension/devtools/config.yaml` and a compiled web app in `extension/devtools/build`.
- The web app runs inside DevTools and gets the connected app's `VmService` and selected isolate through `serviceManager` (`package:devtools_extensions`). It listens to the `Extension` stream for `developer.postEvent` events and calls `ext.qora.*` service extensions.
- Hot restart creates a new isolate: the tab must re-attach and re-read the state. Hot reload keeps the isolate: nothing to do.

### 3.2 Target architecture

```
App isolate                                             DevTools (web)
-----------                                             --------------
QoraClient
  |-- debugCacheEvents  (core, proposed) --+
  |-- debugQuerySnapshot (core, proposed) -+--> QoraDebugBridge --postEvent--> VmDevtoolsSource --> shared UI
  |-- mutationEvents / activeMutations ----+     ext.qora.*   <--callExtension--      ^
  +-- tracker --> TimelineRecorder --------+                                          |
                                                                     same DevtoolsSource interface
                                                                     as the overlay's in-process source
```

Principles:

1. **Same source of truth as the overlay.** The bridge reads the cache through the core debug API. Tracker events feed the timeline only. This removes E5, E9 and most of E3/E4 in one move.
2. **Pull data, push signals.** Push small events (key, status, timestamps, observer count). Pull data on demand, paged. No serialization at fetch time.
3. **Silent until attached.** The bridge does nothing (no serialization, no `postEvent`) until the tab calls `ext.qora.attach`. That fixes E7 for every session where DevTools is not open.
4. **Replay on attach.** `attach` returns the current snapshot plus the recorder's recent events (E10). After a hot restart, the tab attaches again.

### 3.3 Protocol v2

Bump `QoraExtensionMethods.protocolVersion` to `2.0.0`; the existing major-version check in `VmServiceClient.isProtocolCompatible` already handles the mismatch.

| Method | Params | Returns |
| --- | --- | --- |
| `ext.qora.getVersion` | | `{version, qoraVersion}` |
| `ext.qora.attach` | | `{clients: [...], queries: [QuerySummary], mutations: [MutationSummary], recentEvents: [...]}` and starts pushing |
| `ext.qora.detach` | | stops pushing (also on tab close) |
| `ext.qora.getQuery` | `clientId, key` | `QueryDetails`: status, fetch status, observers, timestamps, effective options, data size |
| `ext.qora.getData` | `clientId, key, path, offset, limit` | one level of the JSON tree at `path`, paged, serialized now from the live object |
| `ext.qora.runAction` | `clientId, key, action` | `{ok, error?}` for `refetch`, `invalidate`, `reset`, `remove`, `triggerLoading`, `triggerError`, `restore` |
| `ext.qora.setData` | `clientId, key, path, value` | `{ok}`, through `setQueryData` |

Pushed events (`qora:event`): `query.added`, `query.updated` (summary only), `query.removed`, `mutation.updated`, `timeline.entry`, `cache.cleared`. No data in events.

What this removes: `LazyPayloadManager`, `PayloadStore`, `PayloadChunker`, chunk commands and their TTL (E6). `getData` paging replaces chunking: the tab asks for the level the user expands, so a 50 MB list costs one page.

Statuses travel as enum names that mirror the overlay's `QueryStatus` (`fresh`, `fetching`, `paused`, `stale`, `inactive`, `error`), defined once in `shared`.

### 3.4 Registration and packaging

Today users need three calls and a matching tracker setup. Target:

```dart
void main() {
  final client = QoraClient();
  if (kDebugMode) QoraDevtools.register(client); // idempotent, composes with the overlay
  runApp(QoraScope(client: client, child: const App()));
}
```

- `register` attaches the bridge through `client.addTracker` (proposed in the overlay audit), never `setTracker`, so the overlay and the tab coexist (E11). Calling it twice is a no-op; registering several clients exposes a client picker in the tab.
- Where the code lives is a decision (section 8): either keep `qora_devtools_extension` as a separate published package, or move the runtime bridge into `qora_flutter` (debug only, tree-shaken in release) and the web assets into the package users already depend on. The second gives TanStack's "it is just there" experience; the cost is a heavier pub archive for `qora_flutter` (compiled web assets, not shipped in apps) and a release coupling between the core and the tab.
- CI must build the web app and verify `extension/devtools/build` before publishing (`dart run devtools_extensions validate` is the tool for this).

---

## 4. Web UI audit

Structure: `data / domain (notifiers, entities, repositories, use cases) / ui (shell, screens, tabs, widgets, theme, state)`, about 5,100 lines.

| Topic | Finding |
| --- | --- |
| Duplication | `QueriesNotifier`, `TimelineNotifier`, `MutationsNotifier`, `MutationInspectorNotifier`, `MutationDetail`, `JsonTreeViewer` (334 lines, a diverged copy of the overlay's `JsonViewer`), `QueryRow`, `StatusDot`, `EmptyState`, `BreadcrumbKey`, the whole `theme/` folder and a "Widget Tree" stub tab all exist in both packages, with different bugs. |
| Layers | Clean Architecture use cases (`ObserveEventsUseCase`, `RefetchQueryUseCase`, `FetchLargePayloadUseCase`) wrap one-line repository calls. For a devtool with one data source, this is ceremony: keep a `DevtoolsSource` interface and drop the use-case layer. |
| Navigation | Six ALL CAPS tabs: QUERIES, MUTATIONS, INSPECTOR, NETWORK, PERFORMANCE, GRAPH. "Inspector" is a pane, not a destination; Network and Performance are views of the same fetch history. |
| Theme | Own zinc palette inside DevTools. A DevTools extension should follow the DevTools theme (light and dark, set by the user in DevTools) through `devtools_app_shared`, or it looks like a foreign page. |
| Connection UX | No connection, waiting, mismatch or hot-restart states. The empty state says "No queries yet. Press Refresh or wait for live updates", which is wrong in every case today (E1). |
| Data | Inline data in events plus chunk pulls (E6, E7). |
| Tests | One widget test checking that "Qora DevTools" and two tab labels render. |

The extra screens are a good product instinct and should come back, on solid data:

- **Network activity**: a waterfall of fetches over time (key, duration, result). In the target design this is a mode of the Timeline, not a separate tab.
- **Performance**: slowest queries, most refetched queries, largest payloads, cache size over time. Becomes an "Insights" tab.
- **Dependency graph**: queries linked by `dependsOn`. The core already passes `dependsOnKey` to the tracker. Useful but niche; ship it last, inside Insights.

---

## 5. Redesign of the DevTools tab

The tab is the overlay's desktop layout (overlay audit, 7.3) inside DevTools, plus what only a large, separate window allows. Same vocabulary, same status colors, same actions, same wording table (overlay audit, 7.10).

### 5.1 Layout

```
+----------------------------------------------------------------------------------------------+
| Qora   [client: main v]   Fresh 4  Fetching 2  Paused 0  Stale 3  Inactive 6  Error 1   ( ) Connected |
| Queries (16) | Mutations (3) | Timeline | Insights                                             |
+------------------------------+------------------------------------------+--------------------+
| [Search keys...] [Status v]  | ["todos", 42]                            | History            |
| [Sort: Status v] [asc]       | Fresh . 2 observers . updated 12:04:31   | 12:04:31 fetched   |
|                              | Refetch  Invalidate  Reset  Remove       |   230 ms, 4.1 KB   |
| (o) ["todos"]       2   3s   | Trigger loading  Trigger error           | 12:04:12 invalid.  |
| (o) ["todos", 42]   1   1m < | Data | Options                           | 12:03:58 fetched   |
| (o) ["user", "me"]  0 paused | > { id: 42, title: "Buy milk", ... }     |   180 ms           |
| ...                          |   (paged, editable JSON explorer)        |                    |
+------------------------------+------------------------------------------+--------------------+
```

- Three panes because DevTools has the width the phone overlay lacks: list, details, per-query history. Panes are resizable and collapsible; the history pane collapses first under 1,100 px.
- The header carries what only DevTools needs: the client picker (several `QoraClient`s) and the connection state.
- Keyboard first: `/` search, up/down to move in the list, `r` refetch, `i` invalidate, `Delete` remove (with undo), `Esc` clears selection.

### 5.2 Timeline and Insights

- **Timeline**: two modes, "List" (the overlay's timeline) and "Waterfall" (one bar per fetch on a time axis, colored by result, parallel fetches stacked). The waterfall replaces the Network tab and is where deduplication and refetch storms become visible at a glance.
- **Insights**: ranked tables, not charts first: slowest queries (p50, p95 over the session), most refetched, largest payloads, errors by key; a small cache-size-over-time chart; the dependency graph as the last section.

### 5.3 Connection states

These screens are most of the tab's first impression. Exact wording:

| State | Message | Action |
| --- | --- | --- |
| No app connected | Connect a running Flutter app to DevTools to inspect its Qora cache. | |
| App connected, Qora not registered | This app does not expose Qora. Call `QoraDevtools.register(client)` in debug builds. | Copy snippet |
| Protocol mismatch | This app uses Qora DevTools protocol 1.x; this tab needs 2.x. Update `qora_flutter` (or the tab) so both match. | |
| Hot restart | Reconnecting after hot restart... | (automatic) |
| Connected, empty cache | No queries in the cache yet. They appear as soon as the app fetches. | |
| Release or profile build without registration | Qora DevTools is disabled in this build. | |

### 5.4 Theme

Use the DevTools theme (`devtools_app_shared`) for surfaces, text and borders, so the tab follows the user's DevTools light or dark setting. Keep only Qora's status colors as product tokens, with a light and a dark value each. The shared components (section 6) take a token object, so the overlay passes its own palette and the tab passes the DevTools-derived one.

---

## 6. One UI for overlay and tab

The overlay audit (section 9) recommends this; here is the shape.

```
qora_devtools_shared     protocol only (DTOs, enums, method names), pure Dart
qora_devtools_ui_kit     (new) tokens, components, JSON explorer, list, details, timeline,
                         all driven by a DevtoolsSource interface; Flutter, no transport
qora_devtools_overlay    in-process DevtoolsSource + sheet/docked shell + launcher
qora_devtools_ui         VmDevtoolsSource + DevTools shell + Insights
```

```dart
abstract interface class DevtoolsSource {
  Stream<SourceState> get state;                 // connecting, ready, error
  Stream<List<QuerySummary>> get queries;
  Stream<List<MutationSummary>> get mutations;
  Stream<TimelineEntry> get timeline;
  Future<QueryDetails> query(String key);
  Future<JsonPage> data(String key, JsonPath path, {int offset, int limit});
  Future<ActionResult> run(String key, QueryAction action);
}
```

- The in-process source is synchronous underneath and pays no serialization until `data` is called; the VM source maps each call to `ext.qora.*`.
- `JsonPage` is the contract that makes both the virtualized explorer (overlay performance) and paged loading (tab protocol) work with one widget.
- A `FakeDevtoolsSource` makes every component testable and goldenable without a client or a VM.

Trade-off: one more package to version. It is internal (not published) if the overlay and the tab live in the same repo and depend on it by path; it must be published once the overlay depends on it from pub. That is a real cost; it is still cheaper than maintaining two forks of every widget, which is the situation today.

Order matters: build the kit while redesigning the overlay (overlay P2), with the overlay as its first consumer. The tab adopts it afterwards. Extracting it from today's two UIs would freeze their bugs.

---

## 7. Roadmap (after the overlay)

### X0: stop the damage (can be done anytime, small)

1. Remove or fix "Rollback optimistic" (E3): the safest fix is to remove the action until the core records a pre-optimistic snapshot.
2. Delete `auto_register.dart` (E12).
3. Make `QoraDevtools.setup` idempotent and compatible with an existing tracker (E11), or document the `MultiTracker` path in the overlay README.

### X1: bridge on the core debug API

Prerequisite: overlay P1 (core `debugCacheEvents`, `debugQuerySnapshot`, `addTracker`, refetch).

1. `QoraDebugBridge` with protocol v2 (section 3.3), silent until attached, replay on attach.
2. Remove the lazy payload machinery.
3. Core: failures reported to trackers (shared with overlay P0).
4. Tests: bridge handlers against a real `QoraClient` with in-memory fetchers, through a fake `developer` layer (the existing `VmEventPusher` seam).

### X2: the tab

Prerequisite: overlay P2 and the UI kit.

1. `VmDevtoolsSource` using `serviceManager`; connection states; hot-restart re-attach (fixes E1).
2. DevTools shell (5.1) on the UI kit, DevTools theme.
3. Timeline waterfall, then Insights.
4. Tests: source against a fake `VmService`; goldens in light and dark; one end-to-end test with `integration_test` driving a sample app and the extension in simulated mode.

### X3: ship it

1. Packaging decision (section 3.4) and publication; CI builds and validates `extension/devtools/build`.
2. Docs: a "DevTools tab" page in `docs/content/en/06.devtools/` and its FR mirror; correct the overview page's "rollback context" claim; update `docs/public/qora-rules.md` with the registration call.

---

## 8. Decisions needed

1. **Packaging** of the bridge and the web assets: separate published `qora_devtools_extension`, or bridge in `qora_flutter` and assets alongside (3.4).
2. **Protocol v2** as designed in 3.3, accepting a clean break with the unreleased v1.
3. **UI kit package** (section 6): internal by path first, published when the overlay needs it from pub.
4. **Scope of Insights**: keep Network, Performance and Graph as one later tab, or drop the graph.
5. **Rollback action** (E3): remove now, or add a core feature that records pre-optimistic snapshots.

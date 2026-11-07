# Qora DevTools audit

Scope: `packages/devtools/overlay` (`qora_devtools_overlay` 0.3.0) in depth, with a module-wide opinion on `shared`, `extension` and `ui`. Reference point: TanStack Query Devtools, adapted to Flutter (touch, small screens, no browser chrome, one widget tree).

Method: every file of `overlay/lib` read; core tracker call sites checked in `packages/dart`; the three behaviour bugs in section 2 reproduced by a throwaway probe test against the current `main` packages (output quoted).

---

## 1. Verdict

The overlay looks good in screenshots and shows real effort on layout (responsive 3 columns, resizable dividers, mobile slide stack, design tokens). It is not yet trustworthy as a debugging tool, for one structural reason:

**It rebuilds the cache from tracker events instead of reading the cache.** The tracker hooks were designed for the VM extension, and they do not cover every state transition. So the overlay shows what the events imply, not what the cache holds. A devtool that shows a wrong state is worse than no devtool: the developer debugs the inspector instead of the app.

Consequences, all verified:

- a failed fetch stays `loading` forever;
- a cancelled fetch stays `loading` forever;
- `setQueryData`, hydration and `prepopulate` create no row;
- selecting some rows crashes the panel;
- three mutation buttons do nothing;
- "Refetch" is an invalidate.

Recommendation, in one sentence: **make the overlay cache-backed** (read `QoraClient` state, subscribe to changes, use tracker events only for the timeline), then redesign the UI around TanStack's information model (status counts, sort, filter, query details with real actions), adapted to a bottom sheet on phones and a docked panel on tablets and desktop.

Scores (current state):

| Area | Score | One line |
| --- | --- | --- |
| File structure | 6/10 | Clear `data / domain / ui` split, but dead code, duplicates, a stub tab and French comments. |
| Architecture | 3/10 | Event-sourced shadow cache with heuristics; manual tracker wiring; conflicts with the IDE extension. |
| Correctness | 3/10 | Three reproducible state bugs, one crash, four buttons that lie. |
| Performance | 5/10 | Fine for 20 queries; degrades with payload size and query count (serialization when closed, 1 s full rebuilds, eager JSON tree). |
| Scalability | 4/10 | No virtualization of the JSON tree, unbounded notifier fan-out, no batching. |
| Visual design | 7/10 | Coherent dark palette and typography; inconsistent raw colors and casing. |
| UX / information design | 4/10 | Missing the core TanStack affordances: status counts, sort, real actions, data editing, options view. |
| Flutter fit | 5/10 | Release tree-shaking is correct; no SafeArea, no keyboard insets, 28 px hit targets, fixed FAB, dark only. |
| Tests | 2/10 | 6 tracker unit tests, no notifier, widget or golden tests. |

---

## 2. Verified defects

### 2.1 Behaviour bugs (reproduced)

Probe output against current `main`:

```
P1 status=loading activeCount=1 timeline=[queryCreated]
P2 status=loading activeCount=1
P3 after setQueryData: rows=0
P3 detail threw _TypeError
```

| Id | Symptom | Root cause | Fix |
| --- | --- | --- | --- |
| P1 | A fetch that fails after retries shows `loading` forever, the FAB badge counts it as active, the timeline never shows the error. | The core never calls the tracker on fetch failure: `onQueryFetched` is only called on success (`_doFetch`), from `updateInfiniteQueryState` and from `debugSetQueryError`. | Core: report failures to the tracker (`onQueryFetched(key, null, 'error')` or a new `onQueryFailed`). Overlay: read the state from the cache instead (section 4). |
| P2 | A cancelled fetch shows `loading` forever. | `OverlayTracker.onQueryCancelled` removes the key from `_cacheState` and logs a timeline event, but emits no `QueryEvent`, so `QueriesNotifier` keeps the last `loading` event. | Same as P1: derive the status from the cache. |
| P3a | `setQueryData` (and hydration, `prepopulate`, `initialData`) creates no row. | `setQueryData` calls `onOptimisticUpdate`, which the tracker treats as "the next mutation is optimistic" and which emits no query event. | Cache-backed list. Stop inferring "optimistic" from `setQueryData`. |
| P3b | After `invalidate()` on such a key, selecting the row throws `_TypeError`. | `QueryDetail.fromEvent` does `event.createdAtMs!.toNullOrDateTime()`; `createdAtMs` is null on events not produced by a fetch. | Drop the `!`; make `createdAt` nullable or source it from the cache entry. |

### 2.2 UI that lies

| Where | Problem |
| --- | --- |
| Query inspector, "Refetch" | Calls `client.invalidate(key)`. On an inactive query this only marks stale; nothing is fetched. The label promises a fetch. |
| Mutation inspector, "Retry", "Pause/Resume", "Cancel" | `MutationInspectorNotifier.retry()`, `pauseResume()`, `cancel()` are empty. The Pause button uses the play icon. |
| Mutation details | `rollbackContext` and `submittedAt` are never populated; `retryCount` is always 0, yet all three are rendered. |
| Query row, gc countdown | Computed from the fetch time. `gcTime` starts when the last observer leaves, so the countdown is wrong for every active query and for queries that were observed after their fetch. |
| "Is Invalidated" | A sticky flag in `QueryInspectorNotifier`, never reset by a refetch. |
| "Optimistic" badge on mutations | Heuristic: any `setQueryData` on the key before the mutation starts. False positives for any manual cache write. |
| "Large payload, pull via DevTools extension" | `hasLargePayload` is never true in the overlay, so dead UI (and the source string contains an em dash). |
| "Widget Tree" tab | "Coming soon" stub, shipped in 0.3.0. |
| "Data Diff" tab | Not a diff: shows mutation variables next to the result. |

### 2.3 Hygiene

- 51 em dashes in 17 files of `overlay/lib`, against the repo rule.
- French comments in `ui/panel/layout/panel_layout.dart` ("Contraintes des colonnes", "Barre de navigation mobile").
- `assets/logo.png` (91 KB) is declared in the pubspec and used nowhere. Assets declared by a dependency are bundled into the host app, release builds included.
- `README.md` tables are outdated; the `CHANGELOG.md` uses " : " separators.
- Dartdoc of `MutationInspector` says "DATA" tab; the tab is labelled "DETAILS".

---

## 3. File structure

Current tree (about 4,700 lines):

```
lib/
  qora_devtools_overlay.dart          exports OverlayTracker, QoraInspector
  src/data/overlay_tracker.dart       QoraTracker impl, streams, ring buffers
  src/domain/                         6 ChangeNotifiers + QueryDetail / MutationDetail
  src/ui/
    qora_inspector.dart               entry widget, creates notifiers, Provider tree
    fab/                              FAB + badge
    panel/layout/                     sheet, header, body, responsive layout
    panel/list/{queries,mutations}/   list tabs
    panel/inspector/{query,mutation}/ details
    panel/secondary/                  timeline, widget tree stub, data diff
    shared/                           json viewer, badges, breadcrumb, num_ext
    theme/                            colors, typography, spacing, shadows
```

What works: the `data / domain / ui` split is readable, the theme is centralized, and the public surface is two symbols.

Problems:

1. **Dead code**: `CacheNotifier` (no widget reads it), `OptimisticEvent`, `_cacheState` / `cacheSnapshot`, `WidgetTreeTab`, the no-op mutation actions, `rollbackContext`, `submittedAt`.
2. **Duplicates**: two `_StatusDot`s, status logic spread over `QueryRow`, `StatusBadge` and the FAB badge, two different empty states (queries vs mutations), and a `num_ext.dart` in `ui/shared` next to the one in `qora_devtools_shared`.
3. **Stringly-typed status** (`'loading'`, `'stale'`, `'error'`, `'success'`) compared in many widgets.
4. **Layout mixed with navigation**: `panel_layout.dart` (395 lines) holds column constraints, dividers, the mobile slide stack and the mobile nav bar.
5. **`domain/` is not a domain**: notifiers depend on the `QoraClient` and on DTOs from `shared`; there is no use case or model independent of transport. That is fine for a devtool, so do not add layers; just name it honestly.

Target tree (feature-first; each feature owns its state and widgets):

```
lib/
  qora_devtools_overlay.dart
  src/
    qora_devtools_overlay_widget.dart  public entry widget (renamed, see 4.3)
    source/
      cache_source.dart              reads QoraClient, emits QuerySnapshot list
      mutation_source.dart           client.mutationEvents + activeMutations
      timeline_recorder.dart         QoraTracker impl, timeline only
    model/
      query_status.dart              enum QueryStatus { fresh, fetching, paused, stale, inactive, error }
      query_view.dart                immutable row model (formatted key cached)
      mutation_view.dart
    features/
      queries/                       controller, list, row, filters, sort
      query_details/                 actions, data explorer, options explorer
      mutations/
      timeline/
      settings/                      position, theme, persisted prefs
    shell/
      devtools_shell.dart            sheet / docked panel, header, tabs
      launcher_button.dart           draggable FAB
      responsive.dart                breakpoints only
    design/
      tokens.dart                    color, spacing, radius, type tokens (light + dark)
      components/                    StatusDot, Chip, IconAction, EmptyState, Toolbar
      json_explorer/                 virtualized, editable tree
```

Rule to enforce in review: widgets import `design/` and their own `features/x/`, never another feature's internals; only `source/` imports `qora`.

---

## 4. Architecture

### 4.1 Current

```
QoraClient --(tracker hooks)--> OverlayTracker --(streams)--> 6 ChangeNotifiers --(Provider)--> widgets
                                     |                               |
                                     +-- 200-event ring buffers      +-- QueryInspectorNotifier --> client.invalidate / remove / ...
```

The overlay maintains a **shadow cache** keyed by the last event per key. Every gap in the hook coverage becomes a wrong row. The tracker hooks are the wrong abstraction for "what is in the cache now": they are a log, and they are lossy (failures and `setQueryData` are not logged as state).

Second issue: **wiring**. Users write:

```dart
final tracker = OverlayTracker();
final client = QoraClient(tracker: kDebugMode ? tracker : null);
QoraInspector(tracker: tracker, client: client, child: app);
```

- Three things to wire for one feature; forgetting the tracker gives an empty panel with no error.
- `setTracker` accepts one tracker. Running the overlay next to the IDE extension is only possible through `QoraDevtools.setup(client, additionalTrackers: [overlay])` in `qora_devtools_extension`, which wraps both in a `MultiTracker`. That package is `publish_to: none`, so users cannot reach this path today, and `setup` asserts if the client was built with `tracker:` (which is exactly what the overlay README tells users to do).

### 4.2 Target: cache-backed, events for history only

```
                       +--> CacheSource   (snapshot + change stream)  --> QueriesController --> list, details
QoraClient ------------+--> MutationSource (mutationEvents, activeMutations) --> MutationsController
   |                   +--> client actions (refetch, invalidate, reset, remove, setQueryData, debugSetQueryError)
   +-- tracker --> TimelineRecorder (ring buffer, timeline only)
```

What the core already offers (verified in `qora_client.dart`):

| Need | Existing API |
| --- | --- |
| List keys | `cachedKeys` |
| Read state | `getQueryState<T>(key)`, `getQueryData<T>(key)` |
| Watch one query | `watchState<T>(key)`, `watchFetchStatus(key)` |
| Global fetching count | `fetchingCountStream` |
| Mutations, typed | `mutationEvents`, `activeMutations` (`MutationUpdate`) |
| Snapshot | `debugInfo()` |
| Write | `setQueryData`, `restoreQueryData`, `invalidate`, `removeQuery`, `clear`, `debugSetQueryError` |

What is missing, and needs a decision because it is public API in `qora`:

1. **A cache change stream**: "entry added / removed / state changed", so the list does not poll `cachedKeys`. Proposal: `Stream<QueryCacheEvent> get debugCacheEvents` on `QoraClient`, emitted only when a listener exists (zero cost otherwise), mirroring TanStack's `queryCache.subscribe`.
2. **Per-entry metadata** the overlay cannot compute: observer count, `dataUpdatedAt`, `errorUpdatedAt`, fetch status, effective options (`staleTime`, `gcTime`, `networkMode`, tags), gc deadline (set when the last observer leaves). Proposal: `QueryDebugSnapshot? debugQuerySnapshot(Object key)`, an immutable value object.
3. **A real refetch**: there is no `refetch(key)` on the client today; the overlay needs one that fetches even an inactive query with its stored fetcher. Whether the entry keeps its fetcher is the first thing to check before promising this action; if it does not, the action is "Refetch (active queries only)" and is disabled otherwise.
4. **Failures reported to the tracker** (fixes P1 for the timeline and for `VmTracker`, independently of the overlay).

Those four are small, debug-oriented, and keep `qora` pure Dart. They follow the invariant "public API changes are deliberate": dartdoc, CHANGELOG, docs.

### 4.3 Entry point

Target usage, one widget, no manual tracker:

```dart
QoraDevtoolsOverlay(
  client: client,
  initialIsOpen: false,
  position: DevtoolsPosition.bottom,
  child: app,
)
```

The name is not `QoraDevtools`: `qora_devtools_extension` already exports `abstract final class QoraDevtools` (the `setup` helper), and an app using both packages would get an import conflict.

- The widget attaches its `TimelineRecorder` itself, composing with any existing tracker through `MultiTracker`. This needs a core hook such as `client.addTracker` / `removeTracker`, or the overlay keeps the current constructor parameter as an opt-in for the timeline. That choice is yours; I favour `addTracker` because it also unblocks overlay + IDE extension together.
- `!kDebugMode` returns `child` (already correct today; keep it, it lets the compiler tree-shake the overlay).
- Keep `QoraInspector` + `OverlayTracker` as deprecated aliases for one minor version.

### 4.4 State management

`provider` + six `ChangeNotifier`s created eagerly in `initState`.

- Drop `provider`: one `InheritedNotifier` (or passing controllers down) is enough for a closed widget tree. One less dependency imposed on every app that adds the overlay.
- Create the controllers **when the panel opens**, dispose them when it closes, except the timeline recorder, which must record while closed. When closed, the only live cost should be the recorder ring buffer and the FAB badge (fed by `fetchingCountStream`).
- Notify at most once per frame: coalesce changes with `SchedulerBinding.instance.scheduleFrameCallback` (or `addPostFrameCallback`) and a dirty flag. A refetch storm of 50 queries then costs one rebuild, not 50 sorts and 50 rebuilds.

---

## 5. Performance and scalability

Measured by reading the code; no profiling numbers yet (see 10.3 for the benchmark to add).

| Issue | Cost | Fix |
| --- | --- | --- |
| `needsSerialization => true` | The core JSON-serializes every fetch result in debug, **even while the panel is closed**, and the tracker keeps 200 payloads. On large lists this is visible jank in debug, and memory grows with payload size. | Cache-backed reads give the live object; serialize lazily, only for the selected query, on demand. Timeline events keep metadata only (key, status, duration, size estimate). |
| `QueriesNotifier.queries` sorts on every call and notifies on every event | O(n log n) per event, plus header and badge rebuilds. | Sort once per frame in the batched update; expose an unmodifiable list. |
| `Timer.periodic(1 s)` + `setState` in queries and mutations tabs | Rebuilds every row every second, with `jsonDecode` of the key per row. | One shared `ValueNotifier<DateTime>` clock; only the small "relative time" text listens to it. Cache the formatted key in the row model. |
| `fmtQueryKey` uses `jsonDecode` without try/catch, in row build and in the filter | CPU per row per tick, and a throw on a non-JSON key. | Keep the original `List<Object?>` key from the cache; format once. |
| `JsonViewer`: recursive `Column`s in nested `SingleChildScrollView`s, auto-expanded to depth 2 | A 1,000-item list builds 1,000+ widgets at once. | Flatten the visible tree into a `List<Node>` and render with `ListView.builder` (fixed `itemExtent`); expand on demand; cap string previews. |
| Timeline `List.removeAt(0)` and a reversed copy per build | O(n) per event, allocation per build. | `ListQueue` (as `VmTracker` already does) and `ListView.builder(reverse: true)`. |
| Every query row is a `Column` with a `Divider` | Extra layout per row. | `ListView.separated` or a bottom border in the row decoration. |
| Badge watches `QueriesNotifier` | Rebuilds the FAB on every event, including when only data changed. | Feed it from `fetchingCountStream` and the error count. |

Scalability targets to adopt as acceptance criteria:

- 500 cached queries: list scroll at 60 fps on a mid-range Android in profile mode.
- 5 MB JSON payload: details open in under 200 ms, scrolling stays smooth.
- Panel closed: no serialization, no timers, no rebuilds besides the FAB.

---

## 6. Flutter fit

What is right: overlay mounted only in debug; own `ThemeData`, `Localizations` and `Overlay` so it works above `MaterialApp`; responsive breakpoints.

What is missing:

| Topic | Today | Recommendation |
| --- | --- | --- |
| Safe areas | No `SafeArea`; the sheet and FAB can sit under the home indicator or a notch. | Respect `MediaQuery.paddingOf` in the shell and the launcher. |
| Keyboard | No `viewInsets` handling; the search field can be hidden by the keyboard. | Lift the sheet by `viewInsets.bottom`. |
| Launcher | Fixed bottom right, 44 px, letter "Q". Covers app FABs. | Draggable, snaps to edges, position persisted; logo glyph; long press opens settings. |
| Panel | Bottom sheet only, 60 % or 95 %, no drag. | Phone: draggable sheet with snap points (40 %, 70 %, full). Tablet and desktop: dock to bottom, left, right, or top, resizable by drag (TanStack-like). |
| Touch targets | 28 px header buttons, 5 px column dividers. | 44 px minimum on touch platforms (`MaterialTapTargetSize.padded`), 8 px divider hit zone with a visible 1 px line. |
| Theme | Dark only. | Light, dark, system. A devtool over a light app in dark mode reads as an error dialog. |
| Fonts | `'monospace'` family string; falls back unpredictably per platform. | `fontFamilyFallback: ['SF Mono', 'Menlo', 'Roboto Mono', 'monospace']` without bundling a font. |
| Accessibility | No `Semantics`. | Labels on icon buttons, status announced in row semantics, focus traversal on desktop, keyboard shortcuts (`Esc` closes, `/` focuses search). |
| Gesture conflicts | Panel gestures can compete with the app. | Absorb pointers only inside the panel; leave the app interactive in docked mode. |
| Bundle | `lucide_icons_flutter` and an unused 91 KB PNG. | Remove the PNG; the icon font is tree-shaken in release only if all `IconData` are const, which is the case today, so keep Lucide if you like the look. |

---

## 7. UI/UX redesign

### 7.1 Principles

1. **Truth first**: every value on screen comes from the cache or is labelled as history.
2. **One glance**: the header answers "is anything fetching, failing, paused, stale?" without opening anything.
3. **Same vocabulary as Qora**: `QoraState`, `FetchStatus`, `staleTime`, `gcTime`, `networkMode`, tags. No invented terms ("Mark Stale", "Simulate Error", "Data Diff").
4. **Flutter-native ergonomics**: sheet on phones, docked panel on large screens, touch-first targets, keyboard shortcuts on desktop.
5. **Fewer, real actions**: every button does exactly what its label says, or it is not shown.

### 7.2 Status model

Mirror TanStack's five buckets, plus error, derived from `QoraState` and `FetchStatus`:

| Status | Rule | Color token |
| --- | --- | --- |
| Fetching | `FetchStatus.fetching` | `status.fetching` (blue) |
| Paused | `FetchStatus.paused` (offline in `NetworkMode.online`) | `status.paused` (violet) |
| Error | `Failure` | `status.error` (red) |
| Stale | `Success`, older than `staleTime`, has observers | `status.stale` (amber) |
| Fresh | `Success`, within `staleTime`, has observers | `status.fresh` (green) |
| Inactive | no observers (any data state) | `status.inactive` (grey) |

Priority when several apply: fetching > paused > error > inactive > stale > fresh. Paused gets its own color because "offline, waiting" is the most Qora-specific state and the one developers misread most.

### 7.3 Layout

**Phone (< 600 dp)**: draggable sheet, one pane at a time, push navigation.

```
+--------------------------------------------+
| [Q] Qora          [2 Fetching][1 Error] [x] |   header: logo, status chips (tap = filter), close
|  Queries | Mutations | Timeline            |   tabs
+--------------------------------------------+
| [ Search keys...          ] [Sort v] [...] |   toolbar: search, sort, overflow (clear cache, settings)
| (o) ["todos"]                     2 obs  3s |   row: status dot, key, observers, updated ago
| (o) ["todos", 42]                 1 obs  1m |
| (o) ["user", "me"]          paused  0 obs   |
| (o) ["settings"]               inactive 5m |
+--------------------------------------------+
           tap a row: details slide in
+--------------------------------------------+
| <  ["todos", 42]                      [...] |
| Fresh . 2 observers . updated 3 s ago        |
| [Refetch] [Invalidate] [Reset] [Remove]     |   primary actions, 44 dp
| [Trigger loading] [Trigger error]           |   debug actions, outlined
| Data       Options       History            |   sub-tabs
| > { id: 42, title: "Buy milk", done: false }|   data explorer (virtualized, editable)
+--------------------------------------------+
```

**Tablet and desktop (>= 600 dp)**: docked panel, two panes plus an optional third.

```
+---------------------------------------------------------------------------------+
| [Q] Qora  Fresh 4  Fetching 2  Paused 0  Stale 3  Inactive 6  Error 1   [gear][x] |
| Queries (16) | Mutations (3) | Timeline                                           |
+---------------------------------+-----------------------------------------------+
| [Search...] [Status v] [Sort v] | ["todos", 42]                                 |
| (o) ["todos"]        2   3s     | Fresh . 2 observers . updated 12:04:31        |
| (o) ["todos", 42]    1   1m  <  | Refetch  Invalidate  Reset  Remove            |
| (o) ["user", "me"]   0  paused  | Trigger loading  Trigger error                |
| ...                             | Data | Options | History                      |
|                                 | (data explorer)                               |
+---------------------------------+-----------------------------------------------+
```

The timeline is a tab, not a permanent third column: on a 1,000 px wide panel three columns leave the data explorer about 300 px, which is the pane that needs width. A "History" sub-tab in details shows the timeline filtered to the selected key, which is what developers actually want 90 % of the time.

### 7.4 Header

- Logo glyph + "Qora". No "Devtools" word in the header; the context is obvious.
- Status chips with counts, each a toggle filter. Zero-count chips are dimmed, not hidden, so the layout does not jump.
- Right: settings, dock position (desktop), close. Online/offline indicator when a `ConnectivityManager` is attached ("Offline: 2 queries paused"), because that is a frequent Qora question.

### 7.5 Query list

- Row: status dot, formatted key (monospace, middle-ellipsis for long keys), observer count, relative "updated" time. Secondary line only when relevant: `paused`, `error: <type>`, `gc in 4:12`.
- Sort: Status (default), Last updated, Key. Ascending/descending toggle. Persist the choice.
- Filter: text on the formatted key, plus the status chips. "Hide inactive" toggle in the overflow menu.
- Selection persists across tab switches and survives the row being refetched; a removed query shows "This query was removed from the cache" in details instead of an empty pane.

### 7.6 Query details

Summary line: status, observers, `dataUpdatedAt`, `errorUpdatedAt` when relevant.

Actions (exact labels and behaviour):

| Label | Behaviour | Enabled when |
| --- | --- | --- |
| Refetch | Fetch now, ignoring `staleTime`. | the query has a fetcher (see 4.2 point 3) |
| Invalidate | `client.invalidate(key)`: mark stale, refetch if observed. | always |
| Reset | Back to `initialData` or `Initial`. | always |
| Remove | `client.removeQuery(key)`, with an undo snackbar. | always |
| Trigger loading / Restore | Force `Loading` until restored, to test loading UIs. | debug only |
| Trigger error / Restore | `debugSetQueryError`, then restore the previous state. | debug only |

"Mark stale" goes away: it is "Invalidate" without the refetch, and TanStack users do not miss it. "Simulate error" becomes "Trigger error" with a matching "Restore", because a one-way error injection leaves the app in a state the developer then has to undo by hand.

Sub-tabs:

- **Data**: virtualized JSON explorer. Expand and collapse, copy value, copy path, search inside the data. Editing a leaf calls `setQueryData` (TanStack's Data Editor), with a confirmation that the edit is local to the cache. Non-JSON objects show `toString()` and the runtime type, with a hint to add `toJson`.
- **Options**: effective options after merge with `defaultOptions`: `staleTime`, `gcTime`, `retryCount`, `retryDelay`, `networkMode`, `refetchOnWindowFocus`, `refetchOnReconnect`, `keepPreviousData`, `structuralSharing`, `providesTags`. Inherited values are greyed with "default". This is TanStack's Query Explorer adapted to Qora, and it would have caught the `merge` bug of #65 on day one.
- **History**: timeline filtered to this key.

### 7.7 Mutations

- Same shell: header chips (Pending, Success, Error, Idle), list, details.
- Row: status dot, mutation key or id, relative time, duration when settled.
- Details: variables, result or error, `invalidates` keys and tags it triggered, timestamps.
- Actions: only what the core supports. Today that is none, so no buttons. Remove Retry, Pause/Resume, Cancel until `MutationController` exposes them.
- "Optimistic" label: only if the core reports it explicitly (a flag on `MutationUpdate`), never by inference.

### 7.8 Timeline

- Toolbar: search, event type filter (multi-select chips), record/pause, clear.
- Pause **buffers** events instead of dropping them, with a "12 new events" pill to resume. Dropping events while paused is the opposite of what a developer expects from a recorder.
- Rows: time (`12:04:31.204`), event type, key, duration for fetches. Tap selects the query in the Queries tab.
- Case-insensitive filter on keys and types (today keys are case-sensitive and types are not).

### 7.9 Settings

Persisted in memory per session, optionally through the app's `StorageAdapter` under a reserved key prefix (respect the "Qora owns only the keys it wrote" invariant):

- Position: bottom, top, left, right (large screens); sheet (phones).
- Theme: system, light, dark.
- Launcher: show, hide (open by shortcut or `QoraDevtools.of(context).open()`).
- Hide inactive queries by default.

### 7.10 Wording

Rules: sentence case everywhere (no ALL CAPS tabs), Qora vocabulary, verbs on buttons, nouns on tabs, numbers before units.

| Today | Proposed | Why |
| --- | --- | --- |
| Qora Devtools | Qora | Context is obvious; saves header width. If kept: "Qora DevTools". |
| N queries active | Fetching 2 (chip) | "Active" is ambiguous (observed vs fetching). |
| QUERIES / MUTATIONS | Queries (16) / Mutations (3) | Sentence case; counts help. |
| OVERVIEW / DATA / DETAILS | Data / Options / History | Describe content, consistent across queries and mutations. |
| QUERY KEY, ACTIONS, METADATA, STATE MACHINE | (sections removed) | Summary line + actions + sub-tabs replace them. |
| Refetch (invalidates) | Refetch (fetches) / Invalidate | Label matches behaviour. |
| Mark Stale | (removed) | Covered by Invalidate. |
| Simulate Error | Trigger error / Restore | TanStack term, reversible. |
| Is Fetching / Is Invalidated / Is Stale | Status chip + "Stale since 12:03" | One status, not three booleans that can contradict each other. |
| TIMELINE / WIDGET TREE / DATA DIFF | Timeline | Remove the stub; "Data diff" is not a diff. |
| Retries | Attempts | Counts the first try too, once the core reports it. |
| Back | (back chevron with the query key as title) | Shows where you are. |
| Large payload, pull via DevTools extension | (removed) | Unreachable in the overlay. |
| No queries yet | No queries in the cache. Queries appear here when a widget or `fetchQuery` creates them. | Empty states should teach. |

### 7.11 Visual design

- Keep the zinc palette and the dense 12-13 px type scale; they suit a devtool.
- Define tokens for both themes in one place, and enforce "widgets use tokens only" with a test that greps `Color(0x` outside `design/tokens.dart`.
- Status colors: one token per status (7.2), used for the dot, the chip and the summary line. Today actions have one hard-coded color each, which makes the action bar look like a status legend.
- Actions: neutral buttons; destructive ones (Remove) in the error color on hover/press only; debug triggers outlined.
- Radius 6, spacing on a 4 dp grid, 1 px separators, no shadows inside the panel (one elevation for the panel itself).
- Monospace only for keys, data and timestamps; UI text in the platform font.

---

## 8. TanStack Query Devtools parity

| TanStack feature | Overlay today | Target |
| --- | --- | --- |
| Status counts (fresh, fetching, paused, stale, inactive) | Badge "N active" only | Chips with counts, toggle filters, plus error |
| Sort (status, last updated, hash) + direction | No | Yes |
| Filter by key | Yes (case-sensitive, decodes JSON per row) | Yes, on cached formatted keys |
| Panel position + resize | Bottom only, 2 fixed heights | Sheet on phones, docked 4 sides on large screens, drag resize |
| Theme light / dark / system | Dark only | Yes |
| Refetch | Mislabelled invalidate | Real refetch |
| Invalidate | Yes | Yes |
| Reset | No | Yes |
| Remove | Yes | Yes, with undo |
| Trigger loading | No | Yes |
| Trigger error | One-way "Simulate error" | Trigger / Restore |
| Data explorer | Read-only, eager | Virtualized, editable (`setQueryData`) |
| Query explorer (options) | No | Effective options with inherited markers |
| Mutations tab | Yes, with fake actions | Yes, read-only until the core supports actions |
| Clear cache | No | Overflow menu, with confirmation |
| Offline indicator | No | Yes (Qora-specific, paused queries) |
| Timeline | Yes | Yes, buffered pause, per-query history |

Beyond TanStack, worth keeping because they are Flutter or Qora specific: the per-query history, the offline indicator, and tags in the options view.

---

## 9. The whole devtools module

Summary only. The full audit of the VM extension and the DevTools web UI, with their redesign, is in [DEVTOOLS_EXTENSION_AUDIT.md](DEVTOOLS_EXTENSION_AUDIT.md). That work is scheduled after the overlay, but the overlay must be built so the extension can reuse it (shared core debug API, shared UI components).

| Package | Lines | Opinion |
| --- | --- | --- |
| `shared` (0.2.0) | about 1,900 | Protocol DTOs, codecs, chunked payloads. Right idea for the VM extension. The overlay should not depend on the transport DTOs for its own model; it lives in the same isolate and can read typed objects. Keep `shared` for the extension protocol only. `fmtQueryKey` needs a try/catch. |
| `extension` | about 1,400 | `VmTracker` uses a `ListQueue` ring buffer and lazy chunked payloads: better engineered than the overlay tracker. Same blind spots, since it depends on the same hooks (failures not reported). |
| `ui` (DevTools web app) | about 5,100 | A fork of the overlay: its own `QueriesNotifier`, `TimelineNotifier`, `JsonTreeViewer` (same 334 lines as the overlay `JsonViewer`, 416 diff lines apart), `QueryRow`. Plus screens the overlay lacks (dependency graph, network activity, performance). Two UIs drifting apart. |

Recommendation:

1. **One UI codebase.** Extract the presentational layer (tokens, components, JSON explorer, list, details) into a package both shells use, fed by an interface:

   ```dart
   abstract interface class DevtoolsSource {
     Stream<List<QueryView>> get queries;
     Stream<List<MutationView>> get mutations;
     Stream<TimelineEntry> get timeline;
     Future<Object?> loadData(String key);
     Future<void> run(QueryAction action, String key);
   }
   ```

   The overlay implements it in-process (cache-backed); the web UI implements it over the VM Service. This is the main scalability lever for the module: every feature is built once.

2. **Do it after the overlay is fixed**, not before. Extracting a shared UI from two buggy UIs freezes the bugs into the shared one. Order: fix the overlay model (section 4), redesign the overlay, then make `ui` consume the same components.

3. Decide the fate of the extension-only screens (dependency graph, network, performance) explicitly: either port them behind the same `DevtoolsSource`, or mark them experimental. Do not let them be the reason the two UIs stay forked.

Trade-off to accept: a shared UI package constrains the web DevTools to Flutter widgets that also work on a phone, and the other way round. For a devtool this is cheap; the alternative is two teams' worth of maintenance for one maintainer.

---

## 10. Tests

### 10.1 Today

`overlay/test/qora_devtools_overlay_test.dart`: 6 tracker unit tests. Nothing on notifiers, widgets, layout or actions; P1 to P3 would have been caught by a single integration test.

### 10.2 To add

| Level | Tests |
| --- | --- |
| Source (unit, `package:test`) | Status derivation for every `QoraState` x `FetchStatus` x observers combination; failure, cancellation, `setQueryData`, hydration and removal each produce the right row; batching coalesces N changes into one notification. |
| Controllers | Sort and filter; selection survives refetch; removed query handling; timeline pause buffers. |
| Widgets (`flutter_test`) | Each action calls the right client method (fake client); disabled states; empty states; phone vs tablet layout at 390 and 1024 dp; keyboard insets lift the sheet; tap targets at least 44 dp (`meetsGuideline(androidTapTargetGuideline)`). |
| Golden | Header, row, details, light and dark, phone and tablet. |
| Integration | Real `QoraClient` with in-memory fetchers and a fake `ConnectivityManager`: fetch, fail, go offline (paused), reconnect, remove; assert the overlay at each step. |
| Hygiene | No `Color(0x` outside tokens; no em dash in `lib/`. |

### 10.3 Benchmark

A `flutter_driver` or `integration_test` profile-mode benchmark: 500 queries, 5 MB payload, panel open and closed. Record frame build times so the targets in section 5 are measured, not asserted.

---

## 11. Roadmap

### P0: make it truthful (overlay 0.4.0, plus small core changes)

1. Core: report fetch failures to the tracker. One test, no public API change. Fixes P1 for the overlay and `VmTracker`.
2. Overlay: fix the `createdAtMs!` crash (P3b). Bug-fix test first.
3. Overlay: remove the lying UI: no-op mutation buttons, "Refetch" relabelled "Invalidate" until a real refetch exists, Widget Tree stub, Data Diff tab, unreachable large-payload text, fake `rollbackContext` / `submittedAt` / `retryCount`.
4. Overlay: emit a query event on cancellation (P2) and treat `setQueryData` as a data update, not an optimistic marker (P3a). Stopgap until P1 item 1 below lands.
5. Hygiene: em dashes, French comments, unused PNG, README, CHANGELOG.

### P1: cache-backed model and performance (overlay 0.5.0, `qora` 1.5.0)

1. Core debug API (needs your decision, section 4.2): `debugCacheEvents`, `debugQuerySnapshot`, `addTracker` / `removeTracker`, and a refetch for the overlay.
2. Overlay `CacheSource`, `MutationSource` (on `mutationEvents`), `TimelineRecorder`; delete `OverlayTracker` state mirroring, `CacheNotifier`, `OptimisticEvent`.
3. `QoraDevtoolsOverlay(client:)` entry point; `QoraInspector` / `OverlayTracker` deprecated.
4. Lazy controllers, per-frame batching, shared clock, cached key formatting, virtualized JSON explorer, `ListQueue` timeline, no serialization while closed.
5. Tests from 10.2 (source, controllers, integration).

### P2: redesign (overlay 0.6.0)

1. Shell: draggable sheet on phones, docked and resizable panel on large screens, SafeArea, keyboard insets, draggable launcher.
2. Header status chips, sort, filters, settings, light theme.
3. Query details: actions table of 7.6, Data / Options / History, editable data.
4. Timeline with buffered pause and per-query history.
5. Wording table of 7.10, tokens only, accessibility, goldens.

### P3: one UI for the module

1. Extract shared presentational package and `DevtoolsSource`.
2. Port the DevTools web UI onto it; decide on dependency graph, network and performance screens.

---

## 12. Decisions needed

1. **Core debug API** (4.2): add `debugCacheEvents`, `debugQuerySnapshot`, `addTracker` / `removeTracker` and a refetch to `qora`'s public surface? They are additive, but public.
2. **Refetch semantics**: can an inactive entry be refetched (does it keep its fetcher)? If not, Refetch is enabled for observed queries only.
3. **Entry point rename** to `QoraDevtoolsOverlay` with a deprecation period, or keep `QoraInspector`.
4. **Drop `provider`** from the overlay dependencies (recommended).
5. **Shared UI package** (section 9) and its timing: after P2, not before.
6. **Persisting settings** through the app's `StorageAdapter`, or in memory only (recommended to start: in memory).

# Qora DevTools Overlay - Architecture Alignee au Code Actuel

## Objectif

Ajouter un second front DevTools in-app (overlay style TanStack) **sans casser**:

- la separation core (`qora`) / tooling,
- le protocole partage (`qora_devtools_shared`),
- l'integration VM Service existante (`qora_devtools_extension`).

L'overlay est debug-only et tourne dans le meme isolate que l'app.

## 1) Positionnement dans le monorepo

```text
packages/
├── qora                      # Core runtime
├── qora_devtools_shared      # Contrats protocole (events/commands/codecs)
├── qora_devtools_extension   # Bridge VM service (IDE DevTools)
├── qora_devtools_ui          # DevTools extension Flutter Web (IDE)
└── qora_devtools_overlay     # Nouveau: overlay in-app (debug)
```

Regle de dependances:

- `qora_devtools_overlay` depend de `qora` + `qora_devtools_shared`.
- `qora_devtools_overlay` ne depend ni de `qora_devtools_ui` ni de `qora_devtools_extension`.

## 2) Pourquoi un package overlay separe

- Evite de melanger UI in-app et transport VM Service.
- Permet de garder `qora_devtools_extension` Dart-only runtime bridge.
- Permet d'evoluer l'UX overlay independamment de l'UI IDE.

## 3) Contrat technique avec l'etat actuel du code

Etat actuel a respecter:

- Tracking core via `QoraTracker`.
- Signature actuelle de tracking:
  - `onQueryFetched(String key, Object? data, dynamic status)`
  - `onQueryInvalidated(String key)`
  - `onMutationStarted(String id, String key, Object? variables)`
  - `onMutationSettled(String id, bool success, Object? result)`
  - `onOptimisticUpdate(String key, Object? optimisticData)`
  - `onCacheCleared()`

Donc overlay doit partir de ces callbacks, pas de `QueryStatus` strict ni API `QueryClient` fictive.

## 4) Architecture overlay recommandee

```text
qora_devtools_overlay/lib/src/
├── data/
│   ├── overlay_tracker.dart          # impl QoraTracker + fan-out streams
│   └── overlay_event_store.dart      # ring buffers + snapshots volatiles
├── domain/
│   ├── entities/
│   │   ├── overlay_timeline_item.dart
│   │   └── overlay_cache_item.dart
│   ├── notifiers/
│   │   ├── timeline_notifier.dart
│   │   ├── cache_notifier.dart
│   │   └── optimistic_notifier.dart
│   └── mappers/
│       └── event_mapper.dart         # QoraEvent -> entities UI overlay
└── ui/
    ├── qora_overlay.dart             # widget public
    ├── shell/
    │   ├── overlay_fab.dart
    │   └── overlay_panel.dart
    └── panels/
        ├── cache_panel.dart
        ├── timeline_panel.dart
        └── optimistic_panel.dart
```

## 5) Strategie evenementielle (simple et fiable)

Option recommandee: standardiser tout en `QoraEvent` via `qora_devtools_shared`.

- `overlay_tracker.dart` cree des `QueryEvent`, `MutationEvent`, `GenericQoraEvent`.
- Les notifiers ecoutent un seul `Stream<QoraEvent>`.
- Les ecrans filtrent par `kind`:
  - `query.*`
  - `mutation.*`
  - `optimistic.*`
  - `cache.*`

Avantage:

- parity avec le front IDE,
- reutilisation des memes mappers/composants,
- pas besoin d'inventer des types `OptimisticEvent` / `CacheEvent` hors protocole.

## 6) Event store anti-fuite memoire

`overlay_event_store.dart`:

- Ring buffer borne (ex: 500 events max).
- Eviction FIFO.
- `dispose()` ferme tous les streams et clear les buffers.
- Pas de retention de payload brut volumineux.

Politique payload:

- overlay affiche un preview tronque (`toString` + limite de chars),
- jamais de persistance longue d'objets volumineux.

## 7) Integration dans app Flutter

Public API proposee:

```dart
class QoraDevtoolsOverlay extends StatelessWidget {
  const QoraDevtoolsOverlay({
    super.key,
    required this.child,
    required this.tracker,
  });

  final Widget child;
  final QoraTracker tracker;
}
```

Bootstrap debug:

```dart
void main() {
  final tracker = VmTracker(); // ou OverlayTracker selon mode choisi

  // Le point critique: injecter tracker dans QoraClient au moment de creation.
  // Si QoraClient n'expose pas encore cette injection, il faut l'ajouter cote core.

  runApp(
    QoraDevtoolsOverlay(
      tracker: tracker,
      child: const MyApp(),
    ),
  );
}
```

Important:

- Guard debug strict (`kDebugMode`) autour du montage overlay.
- Aucun import overlay dans les targets release si possible (dart-define / asserts / flavor).

## 8) Deux modes overlay possibles

### Mode A (recommande court terme): OverlayTracker direct

- `OverlayTracker` implemente `QoraTracker`.
- Passe les events en memoire locale a l'overlay.
- Zero dependance VM.

### Mode B (parite IDE): Reuse `VmTracker`

- Reutiliser `VmTracker` comme source tracking,
- l'overlay ecoute un adaptateur local du meme flux.

Decision pragmatique:

- demarrer Mode A (plus rapide),
- garder un adaptateur pour converger vers un bus unique ensuite.

## 9) Gaps a corriger dans core avant implementation complete

1. Injection tracker claire dans `qora`

- Aujourd'hui le contrat existe, mais il faut un point d'injection explicite et stable dans le client runtime utilise par l'app.

1. Commandes overlay -> runtime

- Pour actions UI (`refetch`, `invalidate`, rollback), definir une interface locale similaire a `TrackingGateway`.

1. Event richness

- Si besoin d'un panel cache plus riche, ajouter metadonnees dans `qora_devtools_shared` au lieu de types paralleles overlay-only.

## 10) Plan d'implementation (ordre conseille)

1. Creer package `qora_devtools_overlay` + pubspec + exports.
2. Implementer `OverlayEventStore` (ring buffer borne).
3. Implementer `OverlayTracker implements QoraTracker` avec `QoraEvent` partages.
4. Implementer notifiers (`timeline`, `cache`, `optimistic`).
5. Implementer shell UI (`FAB` + panel tabs).
6. Brancher dans une app example debug.
7. Ajouter tests:
   - buffer eviction,
   - dispose cleanup,
   - mapping event -> view model.

## 11) Verdict sur ta proposition initiale

Ce qui est tres bon:

- package dedie,
- separation data/domain/ui,
- ring buffers,
- guard debug,
- UX FAB + panel.

Ce qui doit etre ajuste:

- enlever types/API non existants (`QueryClient`, `QueryStatus` strict, `CacheEvent`, `OptimisticEvent` custom),
- se caler sur le protocole `qora_devtools_shared` existant,
- officialiser l'injection tracker cote core.

Avec ces ajustements, l'architecture est solide et evolutive.

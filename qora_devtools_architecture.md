# Qora DevTools - Architecture Monorepo

## 1) Structure de fichiers proposee

```text
qora/
├── melos.yaml
├── pubspec.yaml
├── docs/
│   └── qora_devtools_architecture.md
└── packages/
    ├── qora/                                  # Core state-management (agnostique DevTools)
    │   ├── lib/
    │   │   ├── qora.dart
    │   │   └── src/
    │   │       ├── core/
    │   │       │   ├── query_client.dart
    │   │       │   ├── query_cache.dart
    │   │       │   ├── mutation_store.dart
    │   │       │   └── optimistic_engine.dart
    │   │       └── tracking/
    │   │           ├── qora_tracker.dart      # Interface DIP
    │   │           └── no_op_tracker.dart     # Impl par defaut (prod)
    │   └── pubspec.yaml
    │
    ├── qora_devtools_shared/                  # Contrat/protocole commun (pur Dart)
    │   ├── lib/
    │   │   ├── qora_devtools_shared.dart
    │   │   └── src/
    │   │       ├── events/
    │   │       │   ├── qora_event.dart
    │   │       │   ├── query_event.dart
    │   │       │   ├── mutation_event.dart
    │   │       │   └── optimistic_event.dart
    │   │       ├── commands/
    │   │       │   ├── qora_command.dart
    │   │       │   ├── refetch_command.dart
    │   │       │   └── invalidate_command.dart
    │   │       ├── models/
    │   │       │   ├── cache_snapshot.dart
    │   │       │   ├── query_snapshot.dart
    │   │       │   └── mutation_snapshot.dart
    │   │       ├── codec/
    │   │       │   ├── event_codec.dart
    │   │       │   └── command_codec.dart
    │   │       └── protocol/
    │   │           └── extension_methods.dart # ext.qora.* centralisees
    │   └── pubspec.yaml
    │
    ├── qora_devtools_extension/               # Bridge VM Service cote app (server)
    │   ├── lib/
    │   │   ├── qora_devtools_extension.dart
    │   │   └── src/
    │   │       ├── tracker/
    │   │       │   ├── vm_qora_tracker.dart   # implemente QoraTracker
    │   │       │   └── tracking_gateway.dart  # interface anti-circular imports
    │   │       ├── vm/
    │   │       │   ├── extension_registrar.dart
    │   │       │   ├── extension_handlers.dart
    │   │       │   └── vm_event_publisher.dart
    │   │       ├── bus/
    │   │       │   ├── bounded_event_bus.dart
    │   │       │   └── event_subscription.dart
    │   │       └── lazy/
    │   │           ├── payload_store.dart
    │   │           └── payload_chunker.dart
    │   └── pubspec.yaml
    │
    └── qora_devtools_ui/                      # Flutter Web DevTools extension (client)
        ├── lib/
        │   ├── main.dart
        │   └── src/
        │       ├── data/
        │       │   ├── vm_service_client.dart
        │       │   ├── event_repository_impl.dart
        │       │   └── payload_repository_impl.dart
        │       ├── domain/
        │       │   ├── entities/
        │       │   │   ├── timeline_item.dart
        │       │   │   └── cache_node.dart
        │       │   ├── repositories/
        │       │   │   ├── event_repository.dart
        │       │   │   └── payload_repository.dart
        │       │   └── usecases/
        │       │       ├── observe_events.dart
        │       │       ├── refetch_query.dart
        │       │       └── fetch_large_payload.dart
        │       └── ui/
        │           ├── app.dart
        │           ├── screens/
        │           │   ├── cache_inspector_screen.dart
        │           │   ├── mutation_timeline_screen.dart
        │           │   └── optimistic_updates_screen.dart
        │           └── state/
        │               ├── cache_controller.dart
        │               └── timeline_controller.dart
        ├── devtools_options.yaml
        └── pubspec.yaml
```

## 2) Responsabilites par package

- `qora`
  - Domaine principal (queries, cache, mutations, optimistic updates).
  - Ne connait pas l'UI ni VM Service.
  - Expose seulement `QoraTracker` (abstraction) + `NoOpTracker`.

- `qora_devtools_shared`
  - Contrat de communication agnostique: evenements, commandes, codecs, noms d'extensions.
  - Zero dependance Flutter.
  - Versionne strictement le protocole (`semver`).

- `qora_devtools_extension`
  - Adaptateur runtime debug cote app mobile/desktop.
  - Recoit les hooks du core via `QoraTracker`, publie vers VM Service (`postEvent`), expose des endpoints (`registerExtension`).
  - Gere backpressure + lazy payload + lifecycle (`dispose`).

- `qora_devtools_ui`
  - Application Flutter Web executee comme extension DevTools officielle IDE.
  - Data layer: VM client + repositories.
  - Domain layer: use-cases (observer flux, refetch, pull payload).
  - UI layer: ecrans inspection cache/timeline/optimistic.

## 3) Couches Data / Domain / UI

- Data
  - Parle au VM Service (`vm_service`) et decode/encode via `qora_devtools_shared`.
  - Gere retry, timeout, dedup des requetes chunk.

- Domain
  - Contient les regles metier DevTools: correlation event->timeline, tri, filtres, regroupement par query key, orchestration des commandes.
  - Ne depend pas de Flutter Widgets.

- UI
  - Consomme uniquement des view-models/domain models.
  - Aucun appel direct `callServiceExtension` depuis widgets.

## 4) Schema de communication (Event Bus) sans fuite memoire

### Flux general

```text
App (qora + qora_devtools_extension)                         DevTools UI (Flutter Web)

QueryClient/MutationStore
      │
      ▼
QoraTracker (interface)
      │
      ▼
VmQoraTracker -> BoundedEventBus -> developer.postEvent('qora:event', metadata)
                                               │
                                               └─ stocke payloads lourds (TTL + LRU)

UI: streamListen('Extension') -> onExtensionEvent -> EventRepository -> Domain -> UI
UI command: callServiceExtension('ext.qora.refetch', args)
```

### Anti-fuite memoire

- Bus borne (`ListQueue`) avec capacite max (ex: 1000 events).
- `StreamController.broadcast` ferme dans `dispose()`.
- `VmQoraTracker` garde une reference faible ou callback abstrait vers `QueryClient` (pas de retention forte).
- `payload_store` avec TTL (ex: 30s) + eviction LRU + taille globale max (ex: 20 MB).
- Unsubscribe explicite des listeners VM dans l'UI quand l'onglet est detruit.
- Event payload push limite a metadata; le brut JSON est pull a la demande.

## 5) Protocole agnostique (`qora_devtools_shared`)

### Evenements (App -> UI)

- `query.added`, `query.updated`, `query.removed`
- `mutation.started`, `mutation.updated`, `mutation.settled`
- `optimistic.applied`, `optimistic.rolled_back`

Payload minimal recommande:

```json
{
  "eventId": "evt_17250123",
  "kind": "query.updated",
  "timestamp": 1725012345678,
  "queryKey": "todos?page=1",
  "status": "success",
  "hasLargePayload": true,
  "payloadId": "pl_8f9a",
  "totalChunks": 4,
  "summary": {
    "itemCount": 2500,
    "approxBytes": 412398
  }
}
```

### Commandes (UI -> App)

- `ext.qora.refetch`
- `ext.qora.invalidate`
- `ext.qora.rollbackOptimistic`
- `ext.qora.getCacheSnapshot`
- `ext.qora.getPayloadChunk`

Tous les noms sont centralises dans `extension_methods.dart` pour eviter la divergence.

## 6) Lazy Loading des gros JSON

### Strategie

- Push initial: metadata seulement.
- Pull secondaire: chunk par chunk via `ext.qora.getPayloadChunk`.
- Chunk size fixe (ex: 64-128 KB) pour limiter la pression memoire et la latence.

### Contrat chunk

```json
{
  "payloadId": "pl_8f9a",
  "chunkIndex": 2,
  "totalChunks": 4,
  "encoding": "base64",
  "data": "...",
  "sha256": "...",
  "isLast": false
}
```

### Cote UI

- Reconstitution en buffer incremental.
- Verification d'integrite optionnelle (`sha256`) avant `jsonDecode`.
- Memoization courte (ex: 10s) pour navigation entre panels.

## 7) VM Service Extensions (`developer.registerExtension`)

Exemple d'enregistrement dans `qora_devtools_extension`:

```dart
import 'dart:convert';
import 'dart:developer' as developer;

class ExtensionRegistrar {
  ExtensionRegistrar(this.handlers);

  final ExtensionHandlers handlers;

  void registerAll() {
    developer.registerExtension('ext.qora.refetch', _refetch);
    developer.registerExtension('ext.qora.invalidate', _invalidate);
    developer.registerExtension('ext.qora.rollbackOptimistic', _rollback);
    developer.registerExtension('ext.qora.getCacheSnapshot', _snapshot);
    developer.registerExtension('ext.qora.getPayloadChunk', _payloadChunk);
  }

  Future<developer.ServiceExtensionResponse> _refetch(
    String method,
    Map<String, String> params,
  ) async {
    final ok = await handlers.refetch(params['queryKey']);
    return developer.ServiceExtensionResponse.result(
      jsonEncode({'ok': ok}),
    );
  }

  Future<developer.ServiceExtensionResponse> _payloadChunk(
    String method,
    Map<String, String> params,
  ) async {
    final result = await handlers.getPayloadChunk(
      payloadId: params['payloadId']!,
      chunkIndex: int.parse(params['chunkIndex'] ?? '0'),
    );
    return developer.ServiceExtensionResponse.result(jsonEncode(result));
  }

  Future<developer.ServiceExtensionResponse> _invalidate(
    String m,
    Map<String, String> p,
  ) => handlers.invalidateResponse(p);

  Future<developer.ServiceExtensionResponse> _rollback(
    String m,
    Map<String, String> p,
  ) => handlers.rollbackResponse(p);

  Future<developer.ServiceExtensionResponse> _snapshot(
    String m,
    Map<String, String> p,
  ) => handlers.snapshotResponse(p);
}
```

## 8) Flux de donnees detaille (Server -> Client)

- Server (app mobile)
  - `VmQoraTracker` transforme les hooks core en `QoraEvent`.
  - Publie `developer.postEvent('qora:event', event.toJson())`.

- Client (DevTools UI)
  - Ouvre VM service websocket, `streamListen('Extension')`.
  - Filtre `extensionKind == 'qora:event'`.
  - Decode via `EventCodec` et hydrate timeline/cache panel.

- Commandes retour (Client -> Server)
  - UI appelle `callServiceExtension('ext.qora.refetch', args)`.
  - Server execute l'action sur `QueryClient` via `TrackingGateway`.
  - Repond `ServiceExtensionResponse.result(...)`.

## 9) Prevention imports circulaires (SOLID)

- DIP
  - `qora` depend de `QoraTracker` uniquement.
  - `qora_devtools_extension` fournit l'implementation concrete.

- Interface de tracking
  - `TrackingGateway` definit les operations actionnables (`refetch`, `invalidate`, `rollback`) sans exposer `QueryClient` complet.
  - Evite les references transverses core <-> extension.

- Regle stricte des dependances
  - `qora` -> rien
  - `qora_devtools_shared` -> rien runtime UI/core
  - `qora_devtools_extension` -> `qora` + `qora_devtools_shared`
  - `qora_devtools_ui` -> `qora_devtools_shared`

## 10) Integration DevTools officielle (VS Code / IntelliJ)

`qora_devtools_ui/devtools_options.yaml`:

```yaml
name: Qora DevTools
version: 0.1.0
materialIconCodePoint: "0xe1b0"
requiresConnection: true
```

`qora/lib/devtools_options.yaml` (package expose):

```yaml
extensions:
  - name: qora_devtools_ui
    path: ../qora_devtools_ui
```

`qora_devtools_ui/lib/main.dart`:

```dart
import 'package:devtools_extensions/devtools_extensions.dart';
import 'src/ui/app.dart';

void main() {
  runApp(const DevToolsExtension(child: QoraDevToolsApp()));
}
```

Ainsi, l'extension devient discoverable dans Flutter DevTools (integre a VS Code/IntelliJ) des qu'elle est presente dans le workspace/package.

## 11) Avantages / Inconvenients de cette modularite

### Avantages

- Isolation complete du noyau: zero cout DevTools en production (`NoOpTracker`).
- Scalabilite: ajout de nouveaux events/commandes sans toucher l'UI ou le core globalement.
- Testabilite: protocole et extension testables en pur Dart (sans Widget tests).
- Evolutivite IDE: UI embarquable comme extension officielle sans coupler au runtime app.
- Robustesse memoire: bus borne + lazy payload + TTL/LRU.

### Inconvenients

- Plus de packages a versionner et publier.
- Necessite une discipline stricte de compatibilite protocolaire (`shared`).
- Complexite initiale superieure a un package unique.

### Mitigations

- CI avec tests de compatibilite croisee (`shared` x `ui` x `extension`).
- Contrats JSON figes + tests golden de schema.
- Scripts melos pour bootstrap/build/publish end-to-end.

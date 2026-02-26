# Qora DevTools — Architecture Monorepo

> **Stack** : Flutter · Dart | **Pattern** : Monorepo · SOLID | **Transport** : Dart VM Service Extensions

---

## Sommaire

1. [Vue d'ensemble & Philosophie](#1-vue-densemble--philosophie)
2. [Arborescence du Monorepo](#2-arborescence-du-monorepo)
3. [Responsabilité de chaque Package](#3-responsabilité-de-chaque-package)
4. [Schéma de Communication — Event Bus](#4-schéma-de-communication--event-bus)
5. [Dart VM Service Extensions](#5-dart-vm-service-extensions)
6. [Lazy Loading des Gros Payloads JSON](#6-lazy-loading-des-gros-payloads-json)
7. [Extension IDE Officielle (VS Code / IntelliJ)](#7-extension-ide-officielle-vs-code--intellij)
8. [Principes SOLID & Analyse](#8-principes-solid--analyse)
9. [Configuration Melos](#9-configuration-melos)

---

## 1. Vue d'ensemble & Philosophie

Qora adopte une architecture monorepo structurée en packages autonomes, chacun respectant le principe de responsabilité unique (SRP). Le flux de données est unidirectionnel : l'application mobile **produit** des événements, le protocole partagé les **normalise**, et l'UI DevTools les **consomme**. Aucun package supérieur ne dépend d'un package inférieur, ce qui garantit l'absence d'imports circulaires.

### Hiérarchie des dépendances

```
  qora_devtools_ui  (Flutter Web)
         │ dépend de
  qora_devtools_shared  (protocole)
         │ dépend de
  qora_devtools_extension  (VM bridge)
         │ dépend de
  qora  (noyau — aucune dep DevTools)
```

> 🔵 **RÈGLE #1** — `qora` (noyau) ne connaît **pas** l'existence des DevTools. Il expose uniquement une interface `QoraTracker` abstraite.

> 🟢 **RÈGLE #2** — `qora_devtools_shared` ne contient que des PODOs (Plain Old Dart Objects) + sérialisation JSON. **Zéro dépendance Flutter.**

> 🟣 **RÈGLE #3** — Les imports circulaires sont impossibles par construction : chaque couche ne peut importer que les couches inférieures.

---

## 2. Arborescence du Monorepo

```
qora/                                    ← racine du monorepo
├── melos.yaml                           ← orchestration multi-packages
├── pubspec.yaml                         ← workspace root
├── packages/
│   │
│   ├── qora/                            ← NOYAU
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── core/
│   │   │   │   │   ├── query_client.dart
│   │   │   │   │   ├── query_cache.dart
│   │   │   │   │   ├── mutation.dart
│   │   │   │   │   └── optimistic_update.dart
│   │   │   │   ├── tracking/
│   │   │   │   │   └── qora_tracker.dart       ← interface abstraite
│   │   │   │   └── no_op_tracker.dart          ← impl prod (silence)
│   │   │   └── qora.dart                       ← barrel export
│   │   ├── extension/
│   │   │   └── devtools/
│   │   │       └── build/                      ← UI compilée (copie auto)
│   │   ├── devtools_options.yaml               ← déclaration extension
│   │   └── pubspec.yaml
│   │
│   ├── qora_devtools_shared/            ← PROTOCOLE
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── events/             ← PODOs des événements
│   │   │   │   │   ├── qora_event.dart
│   │   │   │   │   ├── query_event.dart
│   │   │   │   │   └── mutation_event.dart
│   │   │   │   ├── models/             ← DTOs de payload
│   │   │   │   │   ├── query_snapshot.dart
│   │   │   │   │   ├── mutation_snapshot.dart
│   │   │   │   │   └── cache_entry.dart
│   │   │   │   ├── commands/           ← commandes UI → App
│   │   │   │   │   ├── qora_command.dart
│   │   │   │   │   └── refetch_command.dart
│   │   │   │   └── serialization/
│   │   │   │       └── event_codec.dart
│   │   │   └── qora_devtools_shared.dart
│   │   └── pubspec.yaml
│   │
│   ├── qora_devtools_extension/         ← BRIDGE VM SERVICE
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── tracker/
│   │   │   │   │   └── vm_tracker.dart          ← implémente QoraTracker
│   │   │   │   ├── vm/
│   │   │   │   │   ├── extension_registrar.dart ← registerExtension
│   │   │   │   │   └── vm_event_pusher.dart
│   │   │   │   └── lazy/
│   │   │   │       └── lazy_payload_manager.dart
│   │   │   └── qora_devtools_extension.dart
│   │   └── pubspec.yaml
│   │
│   └── qora_devtools_ui/               ← UI FLUTTER WEB
│       ├── lib/
│       │   ├── src/
│       │   │   ├── data/               ← couche Data
│       │   │   │   ├── event_repository.dart
│       │   │   │   └── vm_service_client.dart
│       │   │   ├── domain/             ← couche Domain
│       │   │   │   ├── event_notifier.dart
│       │   │   │   └── timeline_service.dart
│       │   │   └── ui/                 ← couche UI
│       │   │       ├── app.dart
│       │   │       ├── screens/
│       │   │       │   ├── cache_inspector.dart
│       │   │       │   ├── mutation_timeline.dart
│       │   │       │   └── optimistic_panel.dart
│       │   │       └── widgets/
│       │   └── main.dart
│       ├── devtools_options.yaml       ← déclaration extension IDE
│       └── pubspec.yaml
│
└── tools/
    └── melos_scripts.yaml
```

---

## 3. Responsabilité de chaque Package

| Package | Responsabilité | Dépendances |
|---|---|---|
| `qora` | QueryClient, Cache, Mutations, Optimistic Updates. Interface `QoraTracker` abstraite (DIP). `NoOpTracker` en prod. | — aucune — |
| `qora_devtools_shared` | PODOs événements + DTOs + commands + JSON codecs. Pur Dart, testable sans Flutter. | `dart:convert` |
| `qora_devtools_extension` | `VmTracker` implémente `QoraTracker`. Enregistre les VM Service Extensions. Lazy payload chunking. | `qora`, `shared` |
| `qora_devtools_ui` | Flutter Web app. Consomme VM events. Timeline, Cache Inspector, Optimistic Panel. Extension IDE officielle. | `shared`, `devtools_extensions` |

### Interface QoraTracker — Dependency Inversion

Le noyau `qora` définit une interface abstraite `QoraTracker`. En production, `NoOpTracker` est injecté (aucun overhead). En mode debug, `VmTracker` (du package extension) est injecté via DI — **le noyau n'a aucune connaissance de l'implémentation**.

```dart
// packages/qora/lib/src/tracking/qora_tracker.dart
abstract interface class QoraTracker {
  void onQueryFetched(String key, Object? data, QueryStatus status);
  void onQueryInvalidated(String key);
  void onMutationStarted(String id, String key, Object? variables);
  void onMutationSettled(String id, bool success, Object? result);
  void onOptimisticUpdate(String key, Object? optimisticData);
  void onCacheCleared();
  void dispose();
}

// Injection dans QueryClient :
class QueryClient {
  final QoraTracker _tracker;

  QueryClient({QoraTracker? tracker})
    : _tracker = tracker ?? const NoOpTracker();
}

// En mode debug (main_debug.dart) :
final client = QueryClient(tracker: VmTracker());
```

---

## 4. Schéma de Communication — Event Bus

### Architecture du flux

```
┌─────────────────────┐        Dart VM Service Extension
│   App Mobile        │  ──────────────────────────────►  ┌──────────────────┐
│  (qora noyau)       │  ext:qora.onEvent (push)           │  DevTools UI     │
│                     │  ◄──────────────────────────────   │  (Flutter Web)   │
│  VmTracker.track()  │  ext:qora.refetch (command)        │                  │
└─────────────────────┘                                    └──────────────────┘
```

L'app mobile **pousse** les événements via `developer.postEvent`. Le DevTools **tire** les payloads lourds via `callServiceExtension`. C'est un modèle hybride **push/pull** selon la taille des données.

### VmTracker — implémentation sans fuite mémoire

```dart
// packages/qora_devtools_extension/lib/src/tracker/vm_tracker.dart
import 'dart:developer' as developer;
import 'dart:collection' show ListQueue;

class VmTracker implements QoraTracker {
  static const int _kMaxBuffer = 500;

  // Ring-buffer borné — garantit une mémoire O(1)
  final _buffer = ListQueue<QoraEvent>(_kMaxBuffer);
  var _disposed = false;

  void _emit(QoraEvent event) {
    if (_disposed) return;                          // guard post-dispose
    if (_buffer.length >= _kMaxBuffer) {
      _buffer.removeFirst();                        // éviction FIFO
    }
    _buffer.addLast(event);
    developer.postEvent(
      'qora:event',
      event.toJson(),                               // Map<String, Object?>
    );
  }

  @override
  void onQueryFetched(String key, Object? data, QueryStatus status) =>
      _emit(QueryEvent.fetched(key: key, data: data, status: status));

  @override
  void onMutationStarted(String id, String key, Object? variables) =>
      _emit(MutationEvent.started(id: id, key: key, variables: variables));

  @override
  void dispose() {
    _disposed = true;
    _buffer.clear();
  }
}
```

### Checklist anti-fuite mémoire

| Mécanisme | Garanti par |
|---|---|
| Ring-buffer borné à 500 events max (`ListQueue`) | `VmTracker` |
| `dispose()` vérifié avant chaque `_emit()` | `VmTracker` |
| `WeakReference` sur `QueryClient` dans `VmTracker` | `VmTracker` |
| `StreamController.broadcast()` avec `onCancel` cleanup | `EventRepository` |
| Lazy payload : seules les métadonnées sont pushées | `LazyPayloadManager` |
| TTL de 30s sur les payloads lazy en cache | `LazyPayloadManager` |

---

## 5. Dart VM Service Extensions

### 5.1 Enregistrement des extensions (App Mobile → DevTools)

Le package `qora_devtools_extension` enregistre les méthodes VM via `developer.registerExtension` dans `ExtensionRegistrar`. Ces méthodes sont découvertes et appelées par l'UI Flutter Web via le Dart VM Service Protocol (WebSocket).

```dart
// packages/qora_devtools_extension/lib/src/vm/extension_registrar.dart
import 'dart:developer' as developer;
import 'dart:convert' show jsonEncode;

class ExtensionRegistrar {
  final QoraTracker _tracker;
  final LazyPayloadManager _lazy;

  ExtensionRegistrar(this._tracker, this._lazy);

  void register() {
    // ① Commande : refetch une query
    developer.registerExtension('ext.qora.refetch', _handleRefetch);

    // ② Commande : invalider une query
    developer.registerExtension('ext.qora.invalidate', _handleInvalidate);

    // ③ Commande : annuler un optimistic update
    developer.registerExtension('ext.qora.rollbackOptimistic', _handleRollback);

    // ④ Pull : récupérer le payload complet (lazy loading)
    developer.registerExtension('ext.qora.getPayload', _handleGetPayload);

    // ⑤ Pull : snapshot complet du cache
    developer.registerExtension('ext.qora.getCacheSnapshot', _handleCacheSnapshot);
  }

  Future<developer.ServiceExtensionResponse> _handleRefetch(
    String method,
    Map<String, String> params,
  ) async {
    final key = params['key'];
    if (key == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionErrorMin,
        'Missing required param: key',
      );
    }
    // Déléguer au QueryClient (via WeakRef pour éviter fuite)
    _tracker.requestRefetch(key);
    return developer.ServiceExtensionResponse.result(
      jsonEncode({'success': true, 'key': key}),
    );
  }

  Future<developer.ServiceExtensionResponse> _handleGetPayload(
    String method,
    Map<String, String> params,
  ) async {
    final id = params['payloadId']!;
    final chunk = int.tryParse(params['chunk'] ?? '0') ?? 0;
    final result = _lazy.getChunk(id, chunk);
    return developer.ServiceExtensionResponse.result(jsonEncode(result));
  }
}
```

### 5.2 Push d'événements : App Mobile (Server) → DevTools (Client)

L'app mobile pousse les événements de manière **proactive** via `developer.postEvent`. Le DevTools écoute ces événements en souscrivant au stream `"Extension"` du VM Service Protocol. C'est un modèle **Push** sans polling.

```dart
// ─── Côté App Mobile (Server) ───────────────────────────────────────
// Push automatique à chaque changement d'état
void _emit(QoraEvent event) {
  developer.postEvent(
    'qora:event',    // ← stream name (préfixe libre)
    event.toJson(),  // ← payload Map<String, Object?>
  );
}

// ─── Côté DevTools UI (Client) ──────────────────────────────────────
// packages/qora_devtools_ui/lib/src/data/vm_service_client.dart
class VmServiceClient {
  late final VmService _service;
  final _eventController = StreamController<QoraEvent>.broadcast();

  Stream<QoraEvent> get events => _eventController.stream;

  Future<void> connect(Uri wsUri) async {
    final channel = WebSocketChannel.connect(wsUri);
    _service = VmService(
      channel.stream.cast<String>(),
      channel.sink.add,
    );
    // Activer le stream "Extension" pour recevoir postEvent
    await _service.streamListen(EventStreams.kExtension);
    _service.onExtensionEvent.listen(_onExtensionEvent);
  }

  void _onExtensionEvent(Event event) {
    if (event.extensionKind == 'qora:event') {
      final raw = event.extensionData?.data ?? {};
      final qoraEvent = EventCodec.decode(raw);
      _eventController.add(qoraEvent);
    }
  }

  // Envoyer une commande vers l'app mobile (pull ou action)
  Future<Map<String, dynamic>> sendCommand(
    String isolateId,
    QoraCommand command,
  ) async {
    final response = await _service.callServiceExtension(
      'ext.qora.${command.method}',
      isolateId: isolateId,
      args: command.params,
    );
    return response.json ?? {};
  }

  void dispose() {
    _eventController.close();
    _service.dispose();
  }
}
```

---

## 6. Lazy Loading des Gros Payloads JSON

Les VM Service Extensions ont une limite de payload (typiquement ~10 MB). Pour les réponses volumineuses (ex : liste de 10 000 produits), Qora utilise un système de **chunking** : seules les métadonnées sont pushées automatiquement, le payload complet est demandé par le DevTools en segments.

### Flux complet

```
① App push un event léger (métadonnées uniquement)
   developer.postEvent('qora:event', {
     'type': 'query.fetched',
     'key': 'products',
     'status': 'success',
     'dataSize': 245000,        // taille en bytes
     'payloadId': 'payload_xyz',  // ID pour pull
     'hasLargePayload': true,    // flag lazy
     'totalChunks': 3,           // 3 chunks de ~80 KB
   });

② DevTools UI détecte hasLargePayload == true
③ DevTools pull les chunks on-demand :
   ext.qora.getPayload?payloadId=payload_xyz&chunk=0  →  80 KB (base64)
   ext.qora.getPayload?payloadId=payload_xyz&chunk=1  →  80 KB (base64)
   ext.qora.getPayload?payloadId=payload_xyz&chunk=2  →  reste
④ UI reconstitue le JSON complet
```

### LazyPayloadManager (côté App Mobile)

```dart
// packages/qora_devtools_extension/lib/src/lazy/lazy_payload_manager.dart
class LazyPayloadManager {
  static const int _kChunkSize = 80 * 1024;           // 80 KB par chunk
  static const Duration _kTtl = Duration(seconds: 30); // TTL anti-fuite

  final _store = <String, _PayloadEntry>{};

  /// Stocke un payload et retourne son ID + nombre de chunks
  ({String payloadId, int totalChunks, bool hasLargePayload}) store(
    Object? data,
  ) {
    final json = jsonEncode(data);
    final bytes = utf8.encode(json);

    if (bytes.length <= _kChunkSize) {
      // Payload léger : pas de lazy loading
      return (payloadId: '', totalChunks: 0, hasLargePayload: false);
    }

    final id = _generateId();
    final chunks = _splitBytes(bytes, _kChunkSize);
    _store[id] = _PayloadEntry(chunks: chunks, createdAt: DateTime.now());
    _scheduleExpiry(id);

    return (payloadId: id, totalChunks: chunks.length, hasLargePayload: true);
  }

  /// Retourne un chunk encodé en base64
  Map<String, Object?> getChunk(String payloadId, int chunkIndex) {
    final entry = _store[payloadId];
    if (entry == null) return {'error': 'expired_or_not_found'};

    final chunk = entry.chunks[chunkIndex];
    return {
      'payloadId': payloadId,
      'chunk': chunkIndex,
      'totalChunks': entry.chunks.length,
      'data': base64.encode(chunk),                // binaire → base64
      'isLast': chunkIndex == entry.chunks.length - 1,
    };
  }

  void _scheduleExpiry(String id) {
    Future.delayed(_kTtl, () => _store.remove(id)); // TTL auto-cleanup
  }

  String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}';
}
```

### Reconstitution côté DevTools UI

```dart
// packages/qora_devtools_ui/lib/src/data/event_repository.dart
Future<Object?> fetchFullPayload(String payloadId, int totalChunks) async {
  final chunks = <Uint8List>[];

  for (var i = 0; i < totalChunks; i++) {
    final resp = await _vmClient.sendCommand(
      _isolateId,
      GetPayloadCommand(payloadId: payloadId, chunk: i),
    );
    chunks.add(base64.decode(resp['data'] as String));
  }

  final fullBytes = Uint8List.fromList(
    chunks.expand((c) => c).toList(),
  );
  return jsonDecode(utf8.decode(fullBytes));
}
```

---

## 7. Extension IDE Officielle (VS Code / IntelliJ)

### devtools_options.yaml

Le package `devtools_extensions` du Flutter SDK permet d'intégrer `qora_devtools_ui` comme un onglet natif dans Flutter DevTools (VS Code, IntelliJ, navigateur).

```yaml
# packages/qora/devtools_options.yaml  (dans le package noyau)
extensions:
  - name: qora
    path: ../../qora_devtools_ui   # chemin relatif vers l'UI
```

```yaml
# packages/qora_devtools_ui/devtools_options.yaml
name: Qora DevTools
issueTracker: https://github.com/yourorg/qora/issues
extensions:
  - name: qora
    description: Inspect queries, mutations, cache & optimistic updates
    icon: qora_logo.png
```

### pubspec.yaml du package UI

```yaml
# packages/qora_devtools_ui/pubspec.yaml
name: qora_devtools_ui
description: DevTools extension for the Qora state management library

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter
  devtools_extensions: ^0.0.8        # SDK officiel extension
  devtools_app_shared: ^0.0.8        # thème DevTools natif
  vm_service: ^14.0.0                # Dart VM Service Protocol
  qora_devtools_shared:
    path: ../qora_devtools_shared
```

### Point d'entrée Flutter Web (main.dart)

```dart
// packages/qora_devtools_ui/lib/main.dart
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:devtools_app_shared/ui.dart';

void main() {
  // OBLIGATOIRE : initialise le bridge avec l'IDE hôte
  runApp(const DevToolsExtension(child: QoraDevToolsApp()));
}

class QoraDevToolsApp extends StatelessWidget {
  const QoraDevToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Cohérence visuelle avec le thème de l'IDE
      theme: DevToolsColorScheme.light.materialTheme,
      darkTheme: DevToolsColorScheme.dark.materialTheme,
      home: const QoraMainScreen(),
    );
  }
}

// serviceManager est fourni automatiquement par devtools_extensions :
// final vmService = serviceManager.service!;
// final isolateId = serviceManager.isolateManager.mainIsolate.value!.id!;
```

### Pipeline de publication

| Étape | Commande |
|---|---|
| Build Web | `cd packages/qora_devtools_ui && flutter build web --output build/devtools_extension` |
| Copie | `cp -r build/devtools_extension ../qora/extension/devtools/build` |
| Publication | `cd packages/qora && dart pub publish` |
| Activation IDE | VS Code détecte automatiquement `devtools_options.yaml` dans les packages publiés |

---

## 8. Principes SOLID & Analyse

### Application des principes SOLID

| | Principe | Application dans Qora | Localisation |
|---|---|---|---|
| **S** | Single Responsibility | `QoraTracker` ne fait que du tracking. `QueryClient` ne fait que du fetching. Séparation stricte par package. | Tous les packages |
| **O** | Open/Closed | Nouveaux événements ajoutés en créant une sous-classe de `QoraEvent` sans modifier `EventCodec` existant. | `qora_devtools_shared/events/` |
| **L** | Liskov Substitution | `VmTracker` et `NoOpTracker` sont substituables sans changer le comportement de `QueryClient`. | `qora/src/tracking/` |
| **I** | Interface Segregation | `QoraTracker` est une interface fine. Pas de méthode non pertinente pour `NoOpTracker`. | `qora/src/tracking/` |
| **D** | Dependency Inversion | `QueryClient` dépend de `QoraTracker` (abstraction), jamais de `VmTracker` (concret). | `qora/src/core/query_client.dart` |

### ✅ Avantages de cette modularité

| | Avantage |
|---|---|
| ✅ | **Isolation parfaite** : les DevTools peuvent être retirés du bundle de prod sans changer une ligne du noyau `qora`. |
| ✅ | **Testabilité maximale** : `qora_devtools_shared` (pur Dart) se teste sans Flutter, sans VM, sans setup complexe. |
| ✅ | **Scalabilité** : ajouter un nouveau type d'événement = 1 classe dans `shared` + 1 méthode dans l'interface. |
| ✅ | **Zéro overhead en prod** : `NoOpTracker` est un objet vide, ses méthodes sont des no-ops inlinables par le compilateur. |
| ✅ | **Extension IDE officielle** : intégration native VS Code/IntelliJ via le mécanisme `devtools_extensions` officiel. |
| ✅ | **Communication robuste** : VM Service Extensions fonctionnent même sur device physique via USB debugging. |

### ⚠️ Inconvénients et mitigations

| Inconvénient | Mitigation |
|---|---|
| Complexité initiale : 4 packages à maintenir au lieu d'1. | Melos automatise bootstrap, tests, publication. ROI positif dès la 2ème feature. |
| Versioning : garder `shared` compatible entre `extension` et `ui`. | Semantic versioning strict + tests d'intégration cross-package dans CI. |
| Latence VM extensions : ~1–5 ms overhead par event. | Acceptable en debug. Batching configurable si volume > 100 events/s. |
| Build Web obligatoire avant publication. | Script Melos automatise `flutter build web` + copie dans `extension/devtools/build`. |

---

## 9. Configuration Melos (Orchestration Monorepo)

```yaml
# melos.yaml
name: qora_workspace

packages:
  - packages/**

scripts:
  # Tests unitaires tous packages
  test:
    run: melos exec -- flutter test
    description: Run all tests

  # Analyse statique
  analyze:
    run: melos exec -- flutter analyze

  # Build l'UI DevTools Web + copie vers le package noyau
  build:devtools:
    run: |
      cd packages/qora_devtools_ui && flutter build web \
        --output build/devtools_extension &&
      cp -r build/devtools_extension \
        ../qora/extension/devtools/build
    description: Build DevTools Web UI and copy to qora package

  # Publication dans l'ordre correct des dépendances
  publish:
    run: melos exec --depends-on="qora_devtools_shared" -- dart pub publish

  # Vérification des imports circulaires
  check:imports:
    run: dart run import_lint:main
```

---

*Qora DevTools Architecture — Senior Flutter Architect Guide*

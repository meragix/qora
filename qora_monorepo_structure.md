# Qora — Structure Monorepo Melos (Scaling)

> Organisation en 3 domaines : `dart/` · `flutter/` · `devtools/`

---

## Sommaire

1. [Arborescence complète](#1-arborescence-complète)
2. [Logique de la séparation en domaines](#2-logique-de-la-séparation-en-domaines)
3. [melos.yaml — configuration complète](#3-melosyaml--configuration-complète)
4. [pubspec.yaml de chaque package](#4-pubspecyaml-de-chaque-package)
5. [Graphe de dépendances final](#5-graphe-de-dépendances-final)
6. [Scripts Melos utiles](#6-scripts-melos-utiles)
7. [Conventions de versioning](#7-conventions-de-versioning)
8. [Ce que Melos te donne gratuitement](#8-ce-que-melos-te-donne-gratuitement)

---

## 1. Arborescence complète

```
qora/                                      ← racine du workspace
│
├── melos.yaml                             ← orchestrateur central
├── pubspec.yaml                           ← workspace root (pas de code)
├── .github/
│   └── workflows/
│       ├── ci.yaml                        ← lint + test tous packages
│       └── publish.yaml                   ← publication ordonnée
│
└── packages/
    │
    ├── dart/                              ← DOMAINE 1 : pur Dart, 0 Flutter
    │   │
    │   └── qora_core/                     ← noyau state management
    │       ├── lib/
    │       │   ├── src/
    │       │   │   ├── client/
    │       │   │   │   └── query_client.dart
    │       │   │   ├── cache/
    │       │   │   │   └── query_cache.dart
    │       │   │   ├── query/
    │       │   │   │   ├── query.dart
    │       │   │   │   └── query_options.dart
    │       │   │   ├── mutation/
    │       │   │   │   ├── mutation.dart
    │       │   │   │   └── mutation_options.dart
    │       │   │   ├── optimistic/
    │       │   │   │   └── optimistic_update.dart
    │       │   │   └── tracking/
    │       │   │       ├── qora_tracker.dart      ← interface abstraite (DIP)
    │       │   │       └── no_op_tracker.dart     ← impl prod
    │       │   └── qora_core.dart                 ← barrel
    │       └── pubspec.yaml
    │
    ├── flutter/                           ← DOMAINE 2 : Flutter widgets
    │   │
    │   └── qora/                          ← package public Flutter
    │       ├── lib/
    │       │   ├── src/
    │       │   │   ├── widgets/
    │       │   │   │   ├── query_builder.dart     ← QueryBuilder<T>
    │       │   │   │   ├── mutation_builder.dart  ← MutationBuilder<T>
    │       │   │   │   └── qora_provider.dart     ← InheritedWidget
    │       │   │   └── hooks/                     ← si flutter_hooks
    │       │   │       ├── use_query.dart
    │       │   │       └── use_mutation.dart
    │       │   └── qora.dart                      ← barrel
    │       └── pubspec.yaml
    │
    └── devtools/                          ← DOMAINE 3 : outillage debug
        │
        ├── qora_devtools_shared/          ← protocole commun (pur Dart)
        │   ├── lib/
        │   │   ├── src/
        │   │   │   ├── events/
        │   │   │   │   ├── qora_event.dart
        │   │   │   │   ├── query_event.dart
        │   │   │   │   ├── mutation_event.dart
        │   │   │   │   └── timeline_event.dart
        │   │   │   ├── models/
        │   │   │   │   ├── query_snapshot.dart
        │   │   │   │   ├── mutation_snapshot.dart
        │   │   │   │   └── cache_entry.dart
        │   │   │   ├── commands/
        │   │   │   │   ├── qora_command.dart
        │   │   │   │   └── refetch_command.dart
        │   │   │   ├── serialization/
        │   │   │   │   └── event_codec.dart
        │   │   │   └── presentation/          ← helpers visuels SANS widgets
        │   │   │       └── event_presentation.dart
        │   │   └── qora_devtools_shared.dart
        │   └── pubspec.yaml
        │
        ├── qora_devtools_extension/       ← bridge VM Service (pur Dart)
        │   ├── lib/
        │   │   ├── src/
        │   │   │   ├── tracker/
        │   │   │   │   └── vm_tracker.dart
        │   │   │   ├── vm/
        │   │   │   │   ├── extension_registrar.dart
        │   │   │   │   └── vm_event_pusher.dart
        │   │   │   └── lazy/
        │   │   │       └── lazy_payload_manager.dart
        │   │   └── qora_devtools_extension.dart
        │   └── pubspec.yaml
        │
        ├── qora_devtools_ui/              ← IDE extension Flutter Web
        │   ├── lib/
        │   │   ├── src/
        │   │   │   ├── data/
        │   │   │   │   ├── vm_service_client.dart
        │   │   │   │   └── event_repository.dart
        │   │   │   ├── domain/
        │   │   │   │   ├── mutations_notifier.dart
        │   │   │   │   ├── timeline_notifier.dart
        │   │   │   │   └── cache_notifier.dart
        │   │   │   └── ui/
        │   │   │       ├── app.dart
        │   │   │       ├── screens/
        │   │   │       └── widgets/
        │   │   └── main.dart
        │   ├── devtools_options.yaml
        │   └── pubspec.yaml
        │
        └── qora_devtools_overlay/         ← in-app Flutter (debug only)
            ├── lib/
            │   ├── src/
            │   │   ├── data/
            │   │   │   └── overlay_tracker.dart
            │   │   ├── domain/
            │   │   │   ├── mutations_notifier.dart
            │   │   │   ├── mutation_inspector_notifier.dart
            │   │   │   ├── timeline_notifier.dart
            │   │   │   └── cache_notifier.dart
            │   │   └── ui/
            │   │       ├── qora_inspector.dart    ← point d'entrée public
            │   │       ├── fab/
            │   │       ├── panel/
            │   │       │   └── responsive_panel_layout.dart
            │   │       └── panels/
            │   └── qora_devtools_overlay.dart
            └── pubspec.yaml
```

---

## 2. Logique de la séparation en domaines

### Pourquoi 3 domaines et pas un `packages/` plat ?

Un `packages/` plat avec 6 packages côte à côte fonctionne en early stage. Mais quand tu ajoutes `qora_offline`, `qora_persist`, `qora_devtools_profiler`… tu ne sais plus ce qui dépend de quoi juste en lisant l'arborescence. La séparation en domaines est **de la documentation structurelle** — elle communique les frontières sans lire un seul fichier.

```
dart/     → "si t'as pas Flutter installé, tu peux quand même utiliser ça"
flutter/  → "widgets, tout ce qui touche BuildContext"
devtools/ → "debug only, jamais en prod"
```

### Règles de dépendances entre domaines

```
dart/         →  aucune dépendance externe Dart/Flutter
flutter/      →  peut dépendre de dart/
              →  jamais de devtools/
devtools/     →  peut dépendre de dart/ et flutter/
              →  jamais l'inverse (dart/ et flutter/ aveugles aux devtools/)
```

Ce n'est pas qu'une convention — Melos peut l'**enforcer** via `import_lint` ou un script CI custom qui vérifie les dépendances dans les pubspecs.

### Scalabilité : comment ça évolue

```
# Dans 6 mois tu ajoutes :
packages/dart/qora_core_persist/     ← persistence layer (pur Dart)
packages/dart/qora_core_offline/     ← offline queue (pur Dart)
packages/flutter/qora_hooks/         ← flutter_hooks integration
packages/flutter/qora_riverpod/      ← riverpod integration
packages/devtools/qora_devtools_profiler/ ← flamegraph des queries

# La structure se lit immédiatement, 0 ambiguité
```

---

## 3. melos.yaml — configuration complète

```yaml
# melos.yaml
name: qora_workspace
sdkPath: auto

packages:
  - packages/dart/**
  - packages/flutter/**
  - packages/devtools/**

command:
  version:
    # Versioning indépendant par package (pas de version globale forcée)
    independent: true
    # Changelog auto depuis les commits conventionnels
    workspaceChangelog: true

  bootstrap:
    # dart pub get dans tous les packages en parallèle
    runPubGetInParallel: true
    # Lier les packages locaux entre eux (path dependencies)
    usePubspecOverrides: true

scripts:

  # ── Qualité ────────────────────────────────────────────────────────
  analyze:
    run: melos exec -- dart analyze --fatal-infos
    description: Analyse statique sur tous les packages
    packageFilters:
      ignore:
        - "*example*"

  format:
    run: melos exec -- dart format . --set-exit-if-changed
    description: Vérifie le formatage

  # ── Tests par domaine ─────────────────────────────────────────────
  test:dart:
    run: melos exec -- dart test
    description: Tests unitaires packages dart/
    packageFilters:
      scope:
        - "qora_core"
        - "qora_devtools_shared"
        - "qora_devtools_extension"

  test:flutter:
    run: melos exec -- flutter test
    description: Tests packages flutter/ et devtools/ Flutter
    packageFilters:
      scope:
        - "qora"
        - "qora_devtools_overlay"

  test:all:
    run: melos run test:dart && melos run test:flutter
    description: Tous les tests

  # ── Build DevTools UI ─────────────────────────────────────────────
  build:devtools:
    run: |
      cd packages/devtools/qora_devtools_ui
      flutter build web --output build/devtools_extension
      cp -r build/devtools_extension \
        ../../dart/qora_core/extension/devtools/build
    description: Build l'UI Web DevTools et copie vers qora_core

  # ── Publication ordonnée ──────────────────────────────────────────
  # L'ordre est critique : les dépendances d'abord
  publish:dart:
    run: melos exec --scope="qora_core" -- dart pub publish --dry-run
    description: Publie qora_core (doit être premier)

  publish:devtools:shared:
    run: melos exec --scope="qora_devtools_shared" -- dart pub publish
    description: Publie le protocole partagé

  publish:all:
    run: |
      melos exec --scope="qora_core" -- dart pub publish
      melos exec --scope="qora_devtools_shared" -- dart pub publish
      melos exec --scope="qora_devtools_extension" -- dart pub publish
      melos exec --scope="qora" -- dart pub publish
      melos exec --scope="qora_devtools_overlay" -- dart pub publish
      melos exec --scope="qora_devtools_ui" -- dart pub publish
    description: Publication complète dans le bon ordre

  # ── Vérification des dépendances inter-domaines ───────────────────
  check:deps:
    run: dart run tools/check_domain_deps.dart
    description: |
      Vérifie qu'aucun package dart/ ou flutter/ ne dépend de devtools/
      et qu'aucun package dart/ ne dépend de flutter/

  # ── Nettoyage ─────────────────────────────────────────────────────
  clean:
    run: melos exec -- flutter clean
    description: Clean tous les packages

  clean:deep:
    run: |
      melos clean
      melos exec -- rm -rf .dart_tool pubspec_overrides.yaml
```

---

## 4. pubspec.yaml de chaque package

### `packages/dart/qora_core/pubspec.yaml`

```yaml
name: qora_core
description: >
  Core state management library for Dart.
  Framework-agnostic query client, cache, mutations and optimistic updates.
version: 0.1.0
repository: https://github.com/yourorg/qora/tree/main/packages/dart/qora_core

environment:
  sdk: ">=3.0.0 <4.0.0"
  # Pas de Flutter SDK ici — pur Dart

dependencies:
  meta: ^1.9.0

dev_dependencies:
  test: ^1.24.0
  lints: ^3.0.0
```

### `packages/flutter/qora/pubspec.yaml`

```yaml
name: qora
description: >
  Flutter widgets and hooks for qora_core.
  QueryBuilder, MutationBuilder, QoraProvider.
version: 0.1.0
repository: https://github.com/yourorg/qora/tree/main/packages/flutter/qora

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  qora_core: ^0.1.0      # dépend du core Dart

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

### `packages/devtools/qora_devtools_shared/pubspec.yaml`

```yaml
name: qora_devtools_shared
description: >
  Shared protocol for Qora DevTools.
  Events, models, commands and JSON codecs. Pure Dart, no Flutter.
version: 0.1.0
repository: https://github.com/yourorg/qora/tree/main/packages/devtools/qora_devtools_shared

environment:
  sdk: ">=3.0.0 <4.0.0"
  # Pas de Flutter SDK — pur Dart testable sans runner Flutter

dependencies:
  qora_core: ^0.1.0      # pour QueryStatus, les types de base

dev_dependencies:
  test: ^1.24.0
  lints: ^3.0.0
```

### `packages/devtools/qora_devtools_extension/pubspec.yaml`

```yaml
name: qora_devtools_extension
description: >
  Dart VM Service bridge for Qora DevTools.
  Registers VM extensions, pushes events to the IDE DevTools panel.
version: 0.1.0
repository: https://github.com/yourorg/qora/tree/main/packages/devtools/qora_devtools_extension

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  qora_core: ^0.1.0
  qora_devtools_shared: ^0.1.0

dev_dependencies:
  test: ^1.24.0
  lints: ^3.0.0
```

### `packages/devtools/qora_devtools_overlay/pubspec.yaml`

```yaml
name: qora_devtools_overlay
description: >
  In-app DevTools overlay for Flutter apps (debug only).
  FAB + 3-column panel with cache inspector, mutations timeline,
  optimistic updates and refetch/invalidate actions.
version: 0.1.0
repository: https://github.com/yourorg/qora/tree/main/packages/devtools/qora_devtools_overlay

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  qora_core: ^0.1.0              # pour QoraTracker, QueryClient
  qora_devtools_shared: ^0.1.0   # pour les events, models, presentation helpers

  # ❌ PAS de qora_devtools_extension — overlay = transport direct
  # ❌ PAS de qora_devtools_ui — overlay ≠ IDE

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

### `packages/devtools/qora_devtools_ui/pubspec.yaml`

```yaml
name: qora_devtools_ui
description: >
  Official IDE DevTools extension for Qora.
  Flutter Web app displayed as a tab in VS Code / IntelliJ DevTools.
version: 0.1.0
repository: https://github.com/yourorg/qora/tree/main/packages/devtools/qora_devtools_ui

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  devtools_extensions: ^0.0.8
  devtools_app_shared: ^0.0.8
  vm_service: ^14.0.0
  qora_devtools_shared: ^0.1.0   # protocole commun

  # ❌ PAS de qora_core direct — passe par VM Service
  # ❌ PAS de qora_devtools_overlay — surfaces indépendantes

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## 5. Graphe de dépendances final

```
                    ┌─────────────────┐
                    │   qora_core     │  packages/dart/
                    │   (pur Dart)    │
                    └────────┬────────┘
                             │ dépend de
              ┌──────────────┼──────────────────┐
              │              │                  │
              ▼              ▼                  ▼
    ┌──────────────┐  ┌─────────────────┐  (autres dart/)
    │     qora     │  │ qora_devtools   │  qora_core_persist
    │  (Flutter)   │  │    _shared      │  qora_core_offline
    │ packages/    │  │  (pur Dart)     │
    │  flutter/    │  └────────┬────────┘
    └──────────────┘           │ dépend de
                    ┌──────────┴──────────┐
                    │                     │
                    ▼                     ▼
         ┌─────────────────┐   ┌──────────────────┐
         │ qora_devtools   │   │ qora_devtools    │
         │  _extension     │   │     _ui          │
         │  (pur Dart)     │   │ (Flutter Web)    │
         └─────────────────┘   └──────────────────┘

         ┌──────────────────────────┐
         │  qora_devtools_overlay   │  packages/devtools/
         │  (Flutter mobile)        │
         │  dépend de:              │
         │  · qora_core             │
         │  · qora_devtools_shared  │
         │  UNIQUEMENT              │
         └──────────────────────────┘

Règles visuelles :
  dart/     →  flèches vers le BAS uniquement
  flutter/  →  peut pointer vers dart/, jamais vers devtools/
  devtools/ →  peut pointer vers dart/ et flutter/
              jamais l'inverse
```

---

## 6. Scripts Melos utiles

### Filtres par domaine

```bash
# Travailler uniquement sur le domaine dart
melos exec --scope="qora_core" -- dart test

# Travailler uniquement sur devtools
melos exec --scope="qora_devtools_*" -- dart analyze

# Exclure les examples
melos exec --ignore="*example*" -- flutter test

# Voir les packages qui dépendent de qora_core
melos list --scope="qora_core" --dependents
```

### Script de vérification des règles inter-domaines

```dart
// tools/check_domain_deps.dart
// Lancé par : melos run check:deps en CI

import 'dart:io';
import 'package:yaml/yaml.dart';

void main() {
  final violations = <String>[];

  // Règle 1 : dart/ ne doit pas dépendre de flutter/ ou devtools/
  _checkDomain('packages/dart', forbidden: [
    'flutter', 'qora_devtools_',
  ], violations: violations);

  // Règle 2 : flutter/ ne doit pas dépendre de devtools/
  _checkDomain('packages/flutter', forbidden: [
    'qora_devtools_',
  ], violations: violations);

  if (violations.isNotEmpty) {
    print('❌ Domain dependency violations:');
    violations.forEach(print);
    exit(1);
  }

  print('✅ All domain dependency rules respected');
}

void _checkDomain(String domain, {
  required List<String> forbidden,
  required List<String> violations,
}) {
  final dir = Directory(domain);
  for (final pkg in dir.listSync().whereType<Directory>()) {
    final pubspec = File('${pkg.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;

    final yaml = loadYaml(pubspec.readAsStringSync()) as Map;
    final deps = {
      ...?(yaml['dependencies'] as Map?)?.keys.cast<String>(),
      ...?(yaml['dev_dependencies'] as Map?)?.keys.cast<String>(),
    };

    for (final dep in deps) {
      for (final f in forbidden) {
        if (dep.contains(f)) {
          violations.add('  $domain/${pkg.uri.pathSegments.last} → $dep (FORBIDDEN)');
        }
      }
    }
  }
}
```

---

## 7. Conventions de versioning

Avec `independent: true` dans melos, chaque package a sa propre version. Mais il faut une convention claire.

### Règle de bump

```
qora_core         1.0.0   ← version de référence
qora              1.0.0   ← suit qora_core (même majeur)
qora_devtools_*   0.x.y   ← versioning libre, pas lié à qora_core
```

Les DevTools ne font pas partie de l'API publique de Qora — ils peuvent sortir des breaking changes sans impacter les utilisateurs du core.

### Commits conventionnels (requis pour changelog auto)

```bash
feat(core): add stale-while-revalidate support     → minor bump
fix(overlay): fix memory leak in ring buffer        → patch bump
feat(overlay)!: rename QoraInspector to QoraPanel  → major bump (breaking)
chore: update dependencies                          → pas de bump
```

---

## 8. Ce que Melos te donne gratuitement

| Feature | Comment |
|---|---|
| `melos bootstrap` | `pub get` dans tous les packages + crée les `pubspec_overrides.yaml` pour lier les packages locaux entre eux par path |
| `melos version` | Bump automatique des versions + génération du CHANGELOG depuis les commits conventionnels |
| `melos publish` | Publication sur pub.dev dans l'ordre des dépendances |
| `--scope` / `--ignore` | Filtrer les commandes par package ou pattern glob |
| `--since` | Lancer les tests seulement sur les packages modifiés depuis le dernier commit (utile en CI) |
| `packageFilters` | Configurer dans melos.yaml quels packages sont concernés par chaque script |

### `--since` en CI — le plus précieux

```yaml
# .github/workflows/ci.yaml
- name: Test changed packages only
  run: |
    melos exec \
      --since="origin/main" \   # seulement les packages modifiés
      --diff-base="HEAD" \
      -- flutter test
```

Sur un monorepo de 6 packages, ça réduit le temps de CI de ~60% dès que les packages sont stables.

---

## Résumé des règles à retenir

```
1. dart/     → 0 dépendance Flutter, 0 dépendance devtools/
2. flutter/  → peut dépendre de dart/, jamais de devtools/
3. devtools/ → peut dépendre de dart/ ET flutter/
              → les 4 packages devtools/ sont indépendants entre eux
                 sauf shared qui est la base commune
4. overlay   → JAMAIS de dépendance sur extension ou ui
5. ui        → JAMAIS de dépendance sur overlay
6. Versioning → qora_core et qora suivent le même majeur
                qora_devtools_* versioning libre
```

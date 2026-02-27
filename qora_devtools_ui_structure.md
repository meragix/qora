# `qora_devtools_ui` — Structure détaillée

> Chaque fichier est mappé à un élément visuel de l'UI screenshot.

---

## Arborescence complète

```
packages/devtools/qora_devtools_ui/
│
├── devtools_options.yaml               ← déclaration extension IDE (obligatoire)
├── pubspec.yaml
│
└── lib/
    ├── main.dart                       ← runApp(DevToolsExtension(child: QoraDevToolsApp()))
    │
    └── src/
        │
        ├── data/                       ── COUCHE DATA ──────────────────────────────────────
        │   ├── vm_service_client.dart  ← WebSocket + streamListen(kExtension)
        │   │                              reçoit developer.postEvent('qora:event', ...)
        │   │                              envoie callServiceExtension('ext.qora.refetch', ...)
        │   │
        │   ├── event_repository.dart   ← parse les événements bruts VM → QoraEvent typés
        │   │                              gère le lazy chunking (getPayload chunks)
        │   │
        │   └── isolate_manager.dart    ← liste les isolates disponibles
        │                                  sélectionne le main isolate automatiquement
        │
        ├── domain/                     ── COUCHE DOMAIN ────────────────────────────────────
        │   │
        │   ├── queries_notifier.dart   ← état de l'onglet QUERIES
        │   │                              List<QuerySnapshot> queryList
        │   │                              int activeQueryCount  → badge "5 queries active"
        │   │
        │   ├── mutations_notifier.dart ← état de l'onglet MUTATIONS
        │   │                              List<MutationEvent> mutations  → col 1 liste
        │   │                              (user › 42 › update, posts › create, products › 1337 › delete)
        │   │
        │   ├── mutation_inspector_notifier.dart
        │   │                           ← mutation sélectionnée en col 1 → expose à col 2
        │   │                              MutationDetail? selected
        │   │                              · status      → badge "error"
        │   │                              · variables   → Object(1)
        │   │                              · error       → Object(3)
        │   │                              · rollbackCtx → Object(2)
        │   │                              · metadata    → Created/Submitted/Updated At, Retry Count
        │   │                              Future<void> retry()  → bouton "Retry"
        │   │
        │   └── timeline_notifier.dart  ← état col 3 TIMELINE
        │                                  List<TimelineEvent> events  → "19 EVENTS"
        │                                  bool paused                 → bouton "Pause"
        │                                  String filter               → champ "Filter…"
        │                                  void clear()                → bouton "Clear"
        │
        └── ui/                         ── COUCHE UI ────────────────────────────────────────
            │
            ├── app.dart                ← MaterialApp avec DevToolsColorScheme (thème IDE)
            │
            ├── shell/                  ── CHROME GLOBAL ────────────────────────────────────
            │   │
            │   ├── app_shell.dart      ← layout racine : header + tab bar + tab views
            │   │
            │   ├── devtools_header.dart
            │   │   ┌─────────────────────────────────────────────────────┐
            │   │   │ Qora Devtools   5 queries active          ⤢  ✕      │
            │   │   └─────────────────────────────────────────────────────┘
            │   │   → titre + badge activeCount + boutons expand/close
            │   │
            │   └── main_tab_bar.dart
            │       ┌──────────────────────────────────────────────────────┐
            │       │  QUERIES    MUTATIONS    MUTATION INSPECTOR           │
            │       │             ━━━━━━━━━━                                │
            │       └──────────────────────────────────────────────────────┘
            │       → TabBar 3 onglets, indicateur bleu sous l'actif
            │
            ├── tabs/                   ── ONGLETS PRINCIPAUX ───────────────────────────────
            │   │
            │   ├── queries/
            │   │   └── queries_tab.dart         ← contenu onglet QUERIES (à implémenter)
            │   │
            │   ├── mutations/                   ← onglet MUTATIONS (celui du screenshot)
            │   │   │
            │   │   ├── mutations_tab.dart       ← Row(col1 | col2 | col3) — layout 3 colonnes
            │   │   │
            │   │   ├── col1_mutations_list/
            │   │   │   ├── mutations_list.dart
            │   │   │   │   ┌──────────────────────┐
            │   │   │   │   │ MUTATIONS (3)         │
            │   │   │   │   │ ● user › 42 › update  │
            │   │   │   │   │   ⚡ Optimistic 33s   │
            │   │   │   │   │ ○ posts › create      │
            │   │   │   │   │   ⚡ Optimistic 11s   │
            │   │   │   │   │ ▲ products›1337›delete│
            │   │   │   │   │   Retries: 2   23s    │◄ sélectionnée (fond clair)
            │   │   │   │   └──────────────────────┘
            │   │   │   │
            │   │   │   └── mutation_list_item.dart
            │   │   │       → BreadcrumbKey ("user › 42 › update")
            │   │   │       → StatusDot (● vert / ○ bleu / ▲ orange)
            │   │   │       → OptimisticBadge ("⚡ Optimistic")
            │   │   │       → RetriesBadge ("Retries: 2")
            │   │   │       → TimeAgo ("33s ago")
            │   │   │
            │   │   ├── col2_mutation_inspector/
            │   │   │   ├── mutation_inspector.dart
            │   │   │   │   ┌────────────────────────────┐
            │   │   │   │   │ STATUS                      │
            │   │   │   │   │ [error]                     │
            │   │   │   │   │ ACTIONS                     │
            │   │   │   │   │ [↺ Retry]                   │
            │   │   │   │   │ VARIABLES                   │
            │   │   │   │   │ > Object(1)                 │
            │   │   │   │   │ ERROR                       │
            │   │   │   │   │ > Object(3)  ← fond rouge   │
            │   │   │   │   │ ROLLBACK CONTEXT            │
            │   │   │   │   │ > Object(2)                 │
            │   │   │   │   │ METADATA                    │
            │   │   │   │   │ Created At:   03:06:02.670  │
            │   │   │   │   │ Submitted At: 03:06:03.170  │
            │   │   │   │   │ Updated At:   03:06:07.670  │
            │   │   │   │   │ Retry Count:  2             │
            │   │   │   │   └────────────────────────────┘
            │   │   │   │
            │   │   │   ├── inspector_section.dart       ← wrapper label + contenu (STATUS, ACTIONS…)
            │   │   │   ├── status_badge.dart            ← badge "error" / "success" / "pending"
            │   │   │   ├── retry_button.dart            ← bouton "↺ Retry" bleu
            │   │   │   ├── expandable_object.dart       ← "> Object(N)" cliquable/expandable
            │   │   │   └── metadata_table.dart          ← grille Created/Submitted/Updated/Retry
            │   │   │
            │   │   └── col3_secondary_tabs/
            │   │       ├── secondary_tab_bar.dart
            │   │       │   ┌──────────────────────────────┐
            │   │       │   │  TIMELINE  WIDGET TREE  DATA DIFF │
            │   │       │   │  ────────                    │
            │   │       │   └──────────────────────────────┘
            │   │       │
            │   │       ├── timeline/
            │   │       │   ├── timeline_tab.dart
            │   │       │   │   ┌────────────────────────────────────────┐
            │   │       │   │   │ TIMELINE (19 EVENTS)                   │
            │   │       │   │   │ [Filter…]  [⏸ Pause]  [🗑 Clear]      │
            │   │       │   │   │ ────────────────────────────────────── │
            │   │       │   │   │ ⚡ OptimisticUpdate    03:06:14.870 AM │
            │   │       │   │   │    posts › list                        │
            │   │       │   │   │ ↗  MutationStarted    03:06:14.670 AM │
            │   │       │   │   │    posts › list                        │
            │   │       │   │   │ +  QueryCreated       03:06:12.670 AM │
            │   │       │   │   │ ▶  FetchStarted       03:06:12.670 AM │
            │   │       │   │   │ ✕  FetchError (20000ms) 03:06:07.670  │
            │   │       │   │   │ ✕  MutationError (5000ms) 03:06:07…   │
            │   │       │   │   │ ↗  MutationStarted    03:06:02.670 AM │
            │   │       │   │   │ ✓  MutationSuccess (5000ms) 03:05:57  │
            │   │       │   │   └────────────────────────────────────────┘
            │   │       │   │
            │   │       │   ├── timeline_toolbar.dart    ← Filter + Pause + Clear
            │   │       │   └── timeline_event_row.dart  ← icône colorée + nom + key + timestamp
            │   │       │
            │   │       ├── widget_tree/
            │   │       │   └── widget_tree_tab.dart     ← placeholder (à implémenter)
            │   │       │
            │   │       └── data_diff/
            │   │           └── data_diff_tab.dart       ← placeholder (à implémenter)
            │   │
            │   └── mutation_inspector/
            │       └── mutation_inspector_tab.dart      ← onglet "MUTATION INSPECTOR" (3ème onglet)
            │                                               vue dédiée quand pas de place en col
            │
            └── shared/                 ── WIDGETS PARTAGÉS ENTRE TABS ──────────────────────
                ├── breadcrumb_key.dart ← "user › 42 › update" (utilisé col1 + onglet QUERIES)
                ├── status_dot.dart     ← ● vert / ○ bleu / ▲ orange (statut mutation)
                ├── section_label.dart  ← label majuscule gris "STATUS", "VARIABLES"…
                └── empty_state.dart    ← "Select a mutation" quand rien n'est sélectionné
```

---

## Mapping visuel → fichier

| Élément dans le screenshot | Fichier |
|---|---|
| `Qora Devtools  5 queries active  ⤢ ✕` | `shell/devtools_header.dart` |
| Tabs `QUERIES / MUTATIONS / MUTATION INSPECTOR` | `shell/main_tab_bar.dart` |
| Liste `MUTATIONS (3)` col gauche | `tabs/mutations/col1_mutations_list/mutations_list.dart` |
| Row `user › 42 › update` + badges | `tabs/mutations/col1_mutations_list/mutation_list_item.dart` |
| Badge `⚡ Optimistic` | `tabs/mutations/col1_mutations_list/mutation_list_item.dart` |
| Badge `Retries: 2` orange | `tabs/mutations/col1_mutations_list/mutation_list_item.dart` |
| Section `STATUS` + badge `error` | `tabs/mutations/col2_mutation_inspector/status_badge.dart` |
| Bouton `↺ Retry` | `tabs/mutations/col2_mutation_inspector/retry_button.dart` |
| `> Object(1)` / `> Object(3)` / `> Object(2)` | `tabs/mutations/col2_mutation_inspector/expandable_object.dart` |
| Bloc `ERROR` fond rouge | `tabs/mutations/col2_mutation_inspector/expandable_object.dart` (prop `isError`) |
| Grille `Created At / Submitted At / …` | `tabs/mutations/col2_mutation_inspector/metadata_table.dart` |
| Tabs `TIMELINE / WIDGET TREE / DATA DIFF` | `tabs/mutations/col3_secondary_tabs/secondary_tab_bar.dart` |
| `TIMELINE (19 EVENTS)` + toolbar | `tabs/mutations/col3_secondary_tabs/timeline/timeline_toolbar.dart` |
| Chaque row timeline avec icône colorée | `tabs/mutations/col3_secondary_tabs/timeline/timeline_event_row.dart` |
| `Filter…` champ texte | `tabs/mutations/col3_secondary_tabs/timeline/timeline_toolbar.dart` |
| Boutons `Pause` / `Clear` | `tabs/mutations/col3_secondary_tabs/timeline/timeline_toolbar.dart` |

---

## Règles de l'extension IDE

```yaml
# devtools_options.yaml — à la racine de qora_devtools_ui
extensions:
  - name: qora
    description: Inspect queries, mutations, cache & optimistic updates
    icon: assets/qora_logo.png
```

```dart
// main.dart — point d'entrée obligatoire
void main() {
  runApp(
    const DevToolsExtension(   // ← wrapper SDK officiel, OBLIGATOIRE
      child: QoraDevToolsApp(),
    ),
  );
}
```

Le `ServiceManager` fourni par `devtools_extensions` donne accès au `VmService` et à l'`isolateId` sans configuration manuelle — c'est lui qui fait le pont avec l'IDE hôte.

# Qora DevTools Overlay — Architecture & Implémentation v2

> **Package** : `qora_devtools_overlay` | **Type** : FAB → Panel in-app | **Env** : Debug only, même process

---

## Sommaire

1. [Positionnement dans le Monorepo](#1-positionnement-dans-le-monorepo)
2. [Arborescence du Package](#2-arborescence-du-package)
3. [Analyse UI & Décisions de Design](#3-analyse-ui--décisions-de-design)
4. [Stratégie Responsive — Le vrai problème](#4-stratégie-responsive--le-vrai-problème)
5. [Couche Data — OverlayTracker](#5-couche-data--overlaytracker)
6. [Couche Domain — Notifiers](#6-couche-domain--notifiers)
7. [Couche UI — FAB + Panel](#7-couche-ui--fab--panel)
8. [Layout Adaptatif — ResponsivePanelLayout](#8-layout-adaptatif--responsivepanellayout)
9. [Les Panels détaillés](#9-les-panels-détaillés)
10. [Intégration Utilisateur](#10-intégration-utilisateur)
11. [Zéro Overhead en Production](#11-zéro-overhead-en-production)
12. [Graphe de dépendances final](#12-graphe-de-dépendances-final)

---

## 1. Positionnement dans le Monorepo

| Critère | `qora_devtools_extension` | `qora_devtools_overlay` |
|---|---|---|
| Transport | Dart VM Service (WebSocket) | Direct — même isolate |
| Environnement cible | Device physique + simulateur | Simulateur / debug builds |
| UI | Flutter Web externe (IDE) | Widget injecté in-app |
| Dépendance Flutter | ❌ (pur Dart) | ✅ (widgets, gestures) |
| Latence | ~1–5 ms (IPC) | ~0 ms (appel direct) |
| Release build | Tree-shaken via dart define | Guard `kDebugMode` |

```
qora_devtools_ui        qora_devtools_overlay
       │                        │
       └──────────┬─────────────┘
                  ▼
       qora_devtools_shared
                  │
       qora_devtools_extension
                  │
               qora  ← noyau, toujours aveugle
```

> **Règle maintenue** : `qora_devtools_overlay` dépend de `qora` + `qora_devtools_shared` uniquement.

---

## 2. Arborescence du Package

Structure mise à jour pour refléter le vrai UI (3 colonnes + tabs secondaires) :

```
packages/qora_devtools_overlay/
├── lib/
│   ├── src/
│   │   │
│   │   ├── data/
│   │   │   ├── overlay_tracker.dart              ← implémente QoraTracker
│   │   │   └── overlay_tracker_store.dart        ← ring-buffer en mémoire
│   │   │
│   │   ├── domain/
│   │   │   ├── queries_notifier.dart             ← liste queries + actions
│   │   │   ├── mutations_notifier.dart           ← liste mutations
│   │   │   ├── mutation_inspector_notifier.dart  ← détail mutation sélectionnée
│   │   │   ├── timeline_notifier.dart            ← flux global + pause/filter
│   │   │   └── cache_notifier.dart               ← snapshot cache
│   │   │
│   │   └── ui/
│   │       ├── qora_inspector.dart               ← widget public (point d'entrée)
│   │       │
│   │       ├── fab/
│   │       │   ├── qora_fab.dart                 ← bouton Q draggable
│   │       │   └── fab_badge.dart                ← badge "5 queries active"
│   │       │
│   │       ├── panel/
│   │       │   ├── qora_panel.dart               ← DraggableScrollableSheet host
│   │       │   ├── panel_header.dart             ← "Qora Devtools · N queries active"
│   │       │   ├── panel_tab_bar.dart            ← QUERIES / MUTATIONS / MUTATION INSPECTOR
│   │       │   └── responsive_panel_layout.dart  ← ⭐ logique mobile vs desktop
│   │       │
│   │       └── panels/
│   │           │
│   │           ├── queries/
│   │           │   ├── queries_panel.dart
│   │           │   └── query_row.dart
│   │           │
│   │           ├── mutations/
│   │           │   ├── mutations_panel.dart           ← liste col 1
│   │           │   ├── mutation_row.dart              ← "user › 42 › update"
│   │           │   ├── mutation_inspector_panel.dart  ← col 2 (STATUS/ACTIONS/…)
│   │           │   └── secondary_tabs/
│   │           │       ├── timeline_tab.dart          ← col 3 TIMELINE
│   │           │       ├── widget_tree_tab.dart       ← col 3 WIDGET TREE
│   │           │       └── data_diff_tab.dart         ← col 3 DATA DIFF
│   │           │
│   │           └── shared/
│   │               ├── expandable_object.dart    ← "> Object(1)" collapsible
│   │               ├── status_badge.dart         ← badge "error" / "optimistic"
│   │               ├── breadcrumb_key.dart       ← "user › 42 › update"
│   │               └── timeline_event_row.dart   ← row avec icône colorée
│   │
│   └── qora_devtools_overlay.dart
│
├── example/
└── pubspec.yaml
```

---

## 3. Analyse UI & Décisions de Design

### Ce qui est excellent

**Layout 3 colonnes** — exactement le pattern React Query DevTools / Redux DevTools. La séparation Liste / Inspector / Timeline est la référence du secteur. À conserver absolument.

**Breadcrumb key** (`user › 42 › update`) — bien supérieur à une string plate. Permet de comprendre immédiatement la hiérarchie de la query key sans parser mentalement. Implémenté via le widget dédié `BreadcrumbKey`.

**Mutation Inspector complet** — les sections STATUS / ACTIONS / VARIABLES / ERROR / ROLLBACK CONTEXT / METADATA sont exactement ce qu'un dev a besoin en debug. Le **ROLLBACK CONTEXT** est particulièrement utile pour les optimistic updates — c'est rare de voir ça dans un DevTools.

**Timeline globale** avec icônes colorées par type d'event et timestamps précis — c'est le "flight recorder" de l'app. Indispensable pour reproduire un bug par ordre chronologique.

**Tabs secondaires** TIMELINE / WIDGET TREE / DATA DIFF — montre que tu as pensé à l'extensibilité du tool dès le début.

**Badge "5 queries active"** dans le header — info de contexte immédiate sans naviguer.

**Retry button** inline dans l'inspector — action directe, sans friction, au bon endroit.

**"Retries: 2"** visible dans la liste mutations — on voit en un coup d'oeil les mutations qui ont échoué et retenté.

### Ce qui peut être amélioré

| Point | Problème | Solution |
|---|---|---|
| `> Object(1)` | On ne sait pas si c'est cliquable | Chevron animé + curseur pointer + hover state |
| Pas de filtre sur la liste mutations | Difficile avec 20+ mutations | `SearchBar` en haut de la col 1 |
| Timestamps relatifs (`33s ago`) | Disparaissent si panel fermé longtemps | Garder l'absolu en tooltip au hover |
| WIDGET TREE / DATA DIFF | Placeholder ? | Badge "soon" ou désactivés visuellement |
| Pas de tri sur la liste mutations | Ordre d'arrivée par défaut | Toggle: par date / par status / par key |

---

## 4. Stratégie Responsive — Le vrai problème

### Le problème concret

Ton UI 3 colonnes fait ~1000px de large minimum. Un iPhone 14 fait **390px**. Les options :

| Option | Verdict |
|---|---|
| Scroll horizontal | ❌ Catastrophique — le dev doit scroller pour voir ses données |
| Tout compresser | ❌ Illisible en dessous de 400px |
| Tabs à la place des colonnes | ⚠️ Perd le contexte (tu ne vois plus la liste pendant l'inspection) |
| **Navigation en stack avec back/forward** | ✅ Pattern iOS natif, intuitif, conserve le contexte |

### La stratégie retenue

```
Desktop / Tablette  ≥ 600px  →  Layout 3 colonnes (ton UI actuel)
Mobile              < 600px  →  Navigation en stack (3 écrans)
```

Sur mobile les 3 colonnes deviennent 3 **écrans** avec transitions `SlideTransition`. L'utilisateur navigue en avant/arrière — pas de scroll horizontal, pas de pinch.

```
[Écran 1 — Liste]      [Écran 2 — Inspector]     [Écran 3 — Timeline]
                   →                          →
MUTATIONS (3)          STATUS: error              TIMELINE (19 EVENTS)
user › 42 › update     ACTIONS: [Retry]           Filter… [Pause] [Clear]
posts › create         VARIABLES: Object(1)       ──────────────────────
products › 1337 ◀sel   ERROR: Object(3)           ⚡ OptimisticUpdate
                       ROLLBACK: Object(2)         ↗ MutationStarted
← back                 METADATA: Created At…      ✓ QueryCreated
                    ← back         Timeline →      ← back
```

### Implémentation — `ResponsivePanelLayout`

```dart
// lib/src/ui/panel/responsive_panel_layout.dart
const double kMobileBreakpoint = 600.0;

enum PanelScreen { list, inspector, secondary }

class ResponsivePanelLayout extends StatelessWidget {
  final Widget listColumn;
  final Widget? inspectorColumn;
  final Widget? secondaryColumn;
  final PanelScreen currentScreen;
  final ValueChanged<PanelScreen> onNavigate;

  const ResponsivePanelLayout({
    super.key,
    required this.listColumn,
    this.inspectorColumn,
    this.secondaryColumn,
    required this.currentScreen,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < kMobileBreakpoint;
    return isMobile
        ? _MobileLayout(
            listColumn: listColumn,
            inspectorColumn: inspectorColumn,
            secondaryColumn: secondaryColumn,
            currentScreen: currentScreen,
            onNavigate: onNavigate,
          )
        : _DesktopLayout(
            listColumn: listColumn,
            inspectorColumn: inspectorColumn,
            secondaryColumn: secondaryColumn,
          );
  }
}
```

### Desktop Layout — 3 colonnes

```dart
class _DesktopLayout extends StatelessWidget {
  final Widget listColumn;
  final Widget? inspectorColumn;
  final Widget? secondaryColumn;

  const _DesktopLayout({
    required this.listColumn,
    this.inspectorColumn,
    this.secondaryColumn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Col 1 — liste mutations (largeur fixe)
        SizedBox(width: 260, child: listColumn),
        _ColDivider(),
        // Col 2 — inspector (flex, prend le reste)
        if (inspectorColumn != null)
          Expanded(flex: 2, child: inspectorColumn!),
        if (secondaryColumn != null) _ColDivider(),
        // Col 3 — timeline / tabs secondaires
        if (secondaryColumn != null)
          SizedBox(width: 300, child: secondaryColumn!),
      ],
    );
  }
}

class _ColDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: const Color(0xFF1E293B));
}
```

### Mobile Layout — Stack animé

```dart
class _MobileLayout extends StatelessWidget {
  final Widget listColumn;
  final Widget? inspectorColumn;
  final Widget? secondaryColumn;
  final PanelScreen currentScreen;
  final ValueChanged<PanelScreen> onNavigate;

  const _MobileLayout({
    required this.listColumn,
    this.inspectorColumn,
    this.secondaryColumn,
    required this.currentScreen,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        final screenIndex = _screenIndex(currentScreen);
        final childScreenIndex = _screenIndexFromKey(child.key);
        final goingForward = childScreenIndex >= screenIndex;
        final begin = goingForward
            ? const Offset(1.0, 0.0)
            : const Offset(-1.0, 0.0);
        return SlideTransition(
          position: Tween(begin: begin, end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
      child: switch (currentScreen) {
        PanelScreen.list => KeyedSubtree(
            key: const ValueKey(PanelScreen.list),
            child: listColumn,
          ),
        PanelScreen.inspector => KeyedSubtree(
            key: const ValueKey(PanelScreen.inspector),
            child: Column(children: [
              _MobileNavBar(
                title: 'Inspector',
                onBack: () => onNavigate(PanelScreen.list),
                forwardLabel: secondaryColumn != null ? 'Timeline' : null,
                onForward: secondaryColumn != null
                    ? () => onNavigate(PanelScreen.secondary)
                    : null,
              ),
              Expanded(child: inspectorColumn ?? const SizedBox()),
            ]),
          ),
        PanelScreen.secondary => KeyedSubtree(
            key: const ValueKey(PanelScreen.secondary),
            child: Column(children: [
              _MobileNavBar(
                title: 'Timeline',
                onBack: () => onNavigate(PanelScreen.inspector),
              ),
              Expanded(child: secondaryColumn ?? const SizedBox()),
            ]),
          ),
      },
    );
  }

  int _screenIndex(PanelScreen s) =>
      [PanelScreen.list, PanelScreen.inspector, PanelScreen.secondary].indexOf(s);

  int _screenIndexFromKey(Key? key) {
    if (key == const ValueKey(PanelScreen.list)) return 0;
    if (key == const ValueKey(PanelScreen.inspector)) return 1;
    if (key == const ValueKey(PanelScreen.secondary)) return 2;
    return 0;
  }
}

/// Barre de navigation mobile — back + titre + forward optionnel
class _MobileNavBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final String? forwardLabel;
  final VoidCallback? onForward;

  const _MobileNavBar({
    required this.title,
    required this.onBack,
    this.forwardLabel,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: onBack,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chevron_left_rounded,
                color: Color(0xFF3B82F6), size: 20),
            Text('Back',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13)),
          ]),
        ),
        // Titre centré
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Forward optionnel
        if (onForward != null)
          GestureDetector(
            onTap: onForward,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                forwardLabel ?? 'Next',
                style: const TextStyle(
                    color: Color(0xFF3B82F6), fontSize: 13),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF3B82F6), size: 20),
            ]),
          )
        else
          const SizedBox(width: 60),
      ]),
    );
  }
}
```

### Schéma de décision responsive

```
┌─────────────────────────────────────────────────────────────┐
│  MediaQuery.sizeOf(context).width                           │
│                                                             │
│  ≥ 600px  ──►  Row(                                         │
│                  SizedBox(260) │ Expanded(flex:2) │ 300px   │
│                  Liste         │ Inspector        │ Timeline│
│                )                                            │
│                                                             │
│  < 600px  ──►  AnimatedSwitcher(SlideTransition)            │
│                  PanelScreen.list       → Col 1 plein écran │
│                  PanelScreen.inspector  → Col 2 + NavBar    │
│                  PanelScreen.secondary  → Col 3 + NavBar    │
│                                                             │
│  Trigger: tap sur une mutation → onNavigate(inspector)      │
│           tap "Timeline" →       onNavigate(secondary)      │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Couche Data — OverlayTracker

```dart
// lib/src/data/overlay_tracker.dart
class OverlayTracker implements QoraTracker {
  static const int _kMaxEvents = 200;

  final _queryController      = StreamController<QueryEvent>.broadcast();
  final _mutationController   = StreamController<MutationEvent>.broadcast();
  final _optimisticController = StreamController<OptimisticEvent>.broadcast();
  final _timelineController   = StreamController<TimelineEvent>.broadcast();

  // Ring-buffers — mémoire bornée, O(1)
  final _queryHistory    = ListQueue<QueryEvent>(_kMaxEvents);
  final _mutationHistory = ListQueue<MutationEvent>(_kMaxEvents);
  final _timelineHistory = ListQueue<TimelineEvent>(_kMaxEvents);

  // État courant du cache (key → snapshot)
  final _cacheState = <String, QuerySnapshot>{};

  // Streams publics
  Stream<QueryEvent>      get onQuery      => _queryController.stream;
  Stream<MutationEvent>   get onMutation   => _mutationController.stream;
  Stream<OptimisticEvent> get onOptimistic => _optimisticController.stream;
  Stream<TimelineEvent>   get onTimeline   => _timelineController.stream;

  // Snapshots synchrones pour l'initialisation des panels
  List<QueryEvent>           get queryHistory    => List.unmodifiable(_queryHistory);
  List<MutationEvent>        get mutationHistory => List.unmodifiable(_mutationHistory);
  List<TimelineEvent>        get timelineHistory => List.unmodifiable(_timelineHistory);
  Map<String, QuerySnapshot> get cacheSnapshot   => Map.unmodifiable(_cacheState);

  bool _disposed = false;

  @override
  void onQueryFetched(String key, Object? data, QueryStatus status) {
    if (_disposed) return;
    final event = QueryEvent.fetched(key: key, status: status, timestamp: DateTime.now());
    _push(_queryHistory, _queryController, event);
    _cacheState[key] = QuerySnapshot(
      key: key, status: status,
      updatedAt: DateTime.now(),
      dataPreview: _truncate(data),
    );
    _emitTimeline(TimelineEventType.fetchStarted, key);
  }

  @override
  void onMutationStarted(String id, String key, Object? variables) {
    if (_disposed) return;
    final event = MutationEvent.started(
      id: id, key: key,
      variablesPreview: _truncate(variables),
      timestamp: DateTime.now(),
    );
    _push(_mutationHistory, _mutationController, event);
    _emitTimeline(TimelineEventType.mutationStarted, key, id: id);
  }

  @override
  void onMutationSettled(String id, bool success, Object? result) {
    if (_disposed) return;
    final event = MutationEvent.settled(
      id: id, success: success,
      resultPreview: _truncate(result),
      timestamp: DateTime.now(),
    );
    _push(_mutationHistory, _mutationController, event);
    _emitTimeline(
      success ? TimelineEventType.mutationSuccess : TimelineEventType.mutationError,
      null, id: id,
    );
  }

  @override
  void onOptimisticUpdate(String key, Object? optimisticData) {
    if (_disposed) return;
    _optimisticController.add(OptimisticEvent(
      key: key,
      preview: _truncate(optimisticData),
      timestamp: DateTime.now(),
    ));
    _emitTimeline(TimelineEventType.optimisticUpdate, key);
  }

  @override
  void onCacheCleared() {
    if (_disposed) return;
    _cacheState.clear();
    _emitTimeline(TimelineEventType.cacheCleared, null);
  }

  void _emitTimeline(TimelineEventType type, String? key, {String? id}) {
    final event = TimelineEvent(
      type: type, key: key, mutationId: id,
      timestamp: DateTime.now(),
    );
    if (_timelineHistory.length >= _kMaxEvents) _timelineHistory.removeFirst();
    _timelineHistory.addLast(event);
    _timelineController.add(event);
  }

  void _push<T>(ListQueue<T> buf, StreamController<T> ctrl, T event) {
    if (buf.length >= _kMaxEvents) buf.removeFirst();
    buf.addLast(event);
    ctrl.add(event);
  }

  String? _truncate(Object? data, {int max = 200}) {
    if (data == null) return null;
    final s = data.toString();
    return s.length > max ? '${s.substring(0, max)}…' : s;
  }

  @override
  void dispose() {
    _disposed = true;
    _queryController.close();
    _mutationController.close();
    _optimisticController.close();
    _timelineController.close();
    _queryHistory.clear();
    _mutationHistory.clear();
    _timelineHistory.clear();
    _cacheState.clear();
  }
}
```

---

## 6. Couche Domain — Notifiers

### MutationInspectorNotifier — sélection + retry

Notifier clé du layout 3 colonnes. La col 1 appelle `select()`, la col 2 lit `detail`.

```dart
// lib/src/domain/mutation_inspector_notifier.dart
class MutationInspectorNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;
  final QueryClient _client;
  late final StreamSubscription<MutationEvent> _sub;

  MutationEvent? _selected;
  MutationEvent? get selected => _selected;
  MutationDetail? get detail =>
      _selected == null ? null : MutationDetail.fromEvent(_selected!);

  MutationInspectorNotifier(this._tracker, this._client) {
    _sub = _tracker.onMutation.listen((event) {
      // Auto-update si la mutation sélectionnée change d'état (ex: retry settled)
      if (_selected != null && event.id == _selected!.id) {
        _selected = event;
        notifyListeners();
      }
    });
  }

  void select(MutationEvent mutation) {
    _selected = mutation;
    notifyListeners();
  }

  Future<void> retry() async {
    if (_selected == null) return;
    await _client.retryMutation(_selected!.id);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

### TimelineNotifier — pause / filter / clear

```dart
// lib/src/domain/timeline_notifier.dart
class TimelineNotifier extends ChangeNotifier {
  final OverlayTracker _tracker;
  late final StreamSubscription<TimelineEvent> _sub;

  final _events = <TimelineEvent>[];
  bool _paused = false;
  String _filter = '';

  bool get paused => _paused;
  String get filter => _filter;

  List<TimelineEvent> get filteredEvents {
    final reversed = _events.reversed.toList();
    if (_filter.isEmpty) return reversed;
    return reversed.where((e) =>
        (e.key?.contains(_filter) ?? false) ||
        e.type.name.toLowerCase().contains(_filter.toLowerCase()),
    ).toList();
  }

  TimelineNotifier(this._tracker) {
    _events.addAll(_tracker.timelineHistory);
    _sub = _tracker.onTimeline.listen((event) {
      if (_paused) return;
      _events.add(event);
      if (_events.length > 200) _events.removeAt(0);
      notifyListeners();
    });
  }

  void togglePause() { _paused = !_paused; notifyListeners(); }
  void setFilter(String v) { _filter = v; notifyListeners(); }
  void clear() { _events.clear(); notifyListeners(); }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}
```

---

## 7. Couche UI — FAB + Panel

### Panel Header

```dart
// lib/src/ui/panel/panel_header.dart
class PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  const PanelHeader({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final activeCount = context.watch<QueriesNotifier>().activeQueryCount;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        // Logo Q
        const Text('Q', style: TextStyle(
          color: Color(0xFF3B82F6), fontSize: 18, fontWeight: FontWeight.w900,
        )),
        const SizedBox(width: 8),
        const Text('Qora Devtools', style: TextStyle(
          color: Color(0xFFE2E8F0), fontSize: 14, fontWeight: FontWeight.w600,
        )),
        const SizedBox(width: 8),
        // Badge "5 queries active"
        if (activeCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$activeCount ${activeCount == 1 ? 'query' : 'queries'} active',
              style: const TextStyle(
                color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const Spacer(),
        // Expand
        IconButton(
          icon: const Icon(Icons.open_in_full_rounded,
              color: Color(0xFF475569), size: 16),
          onPressed: () {},
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        // Close
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: Color(0xFF475569), size: 16),
          onPressed: onClose,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
    );
  }
}
```

---

## 8. Layout Adaptatif — ResponsivePanelLayout

Voir section 4 pour le code complet. Voici comment il est câblé dans le panel Mutations :

```dart
// lib/src/ui/panels/mutations/mutations_panel.dart
class MutationsTabView extends StatefulWidget {
  const MutationsTabView();
  @override
  State<MutationsTabView> createState() => _MutationsTabViewState();
}

class _MutationsTabViewState extends State<MutationsTabView> {
  PanelScreen _mobileScreen = PanelScreen.list;

  @override
  Widget build(BuildContext context) {
    final inspector = context.watch<MutationInspectorNotifier>();

    return ResponsivePanelLayout(
      currentScreen: _mobileScreen,
      onNavigate: (s) => setState(() => _mobileScreen = s),

      // ── Col 1 : liste des mutations ────────────────────────────
      listColumn: MutationListColumn(
        onMutationTap: (mutation) {
          inspector.select(mutation);
          final isMobile =
              MediaQuery.sizeOf(context).width < kMobileBreakpoint;
          if (isMobile) setState(() => _mobileScreen = PanelScreen.inspector);
        },
      ),

      // ── Col 2 : inspector ──────────────────────────────────────
      inspectorColumn: const MutationInspectorColumn(),

      // ── Col 3 : tabs secondaires (Timeline / Widget Tree / Data Diff)
      secondaryColumn: DefaultTabController(
        length: 3,
        child: Column(children: [
          const TabBar(
            tabs: [
              Tab(text: 'TIMELINE'),
              Tab(text: 'WIDGET TREE'),
              Tab(text: 'DATA DIFF'),
            ],
            labelColor: Color(0xFFE2E8F0),
            unselectedLabelColor: Color(0xFF475569),
            indicatorColor: Color(0xFF3B82F6),
            labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const Expanded(
            child: TabBarView(children: [
              TimelineTab(),
              WidgetTreeTab(),
              DataDiffTab(),
            ]),
          ),
        ]),
      ),
    );
  }
}
```

---

## 9. Les Panels détaillés

### BreadcrumbKey

```dart
// lib/src/ui/panels/shared/breadcrumb_key.dart
class BreadcrumbKey extends StatelessWidget {
  final String queryKey;
  const BreadcrumbKey({super.key, required this.queryKey});

  List<String> get _segments => queryKey
      .split(RegExp(r'[./\[\],]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final segs = _segments;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < segs.length; i++) ...[
          Text(segs[i], style: const TextStyle(
            color: Color(0xFFE2E8F0), fontFamily: 'monospace',
            fontSize: 13, fontWeight: FontWeight.w600,
          )),
          if (i < segs.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('›', style: TextStyle(
                color: Color(0xFF475569), fontSize: 13,
              )),
            ),
        ],
      ],
    );
  }
}
```

### MutationInspectorColumn — col 2

```dart
// lib/src/ui/panels/mutations/mutation_inspector_panel.dart
class MutationInspectorColumn extends StatelessWidget {
  const MutationInspectorColumn();

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<MutationInspectorNotifier>().detail;

    if (detail == null) {
      return const Center(
        child: Text('Select a mutation',
            style: TextStyle(color: Color(0xFF475569), fontSize: 13)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // STATUS
        _Section(
          label: 'STATUS',
          child: StatusBadge(status: detail.status),
        ),

        // ACTIONS
        _Section(
          label: 'ACTIONS',
          child: Row(children: [
            if (detail.status == QueryStatus.error)
              _RetryButton(
                onTap: () => context.read<MutationInspectorNotifier>().retry(),
              ),
          ]),
        ),

        // VARIABLES
        _Section(
          label: 'VARIABLES',
          child: ExpandableObject(
            label: 'Object(${detail.variablesCount})',
            preview: detail.variablesPreview,
          ),
        ),

        // ERROR — conditionnel
        if (detail.errorPreview != null)
          _Section(
            label: 'ERROR',
            child: ExpandableObject(
              label: 'Object(${detail.errorCount})',
              preview: detail.errorPreview,
              isError: true,
            ),
          ),

        // ROLLBACK CONTEXT — si optimistic update
        if (detail.rollbackContextPreview != null)
          _Section(
            label: 'ROLLBACK CONTEXT',
            child: ExpandableObject(
              label: 'Object(${detail.rollbackCount})',
              preview: detail.rollbackContextPreview,
            ),
          ),

        // METADATA
        _Section(
          label: 'METADATA',
          child: Column(children: [
            _MetaRow('Created At',   _fmt(detail.createdAt)),
            if (detail.submittedAt != null)
              _MetaRow('Submitted At', _fmt(detail.submittedAt!)),
            if (detail.updatedAt != null)
              _MetaRow('Updated At',   _fmt(detail.updatedAt!)),
            _MetaRow('Retry Count',  '${detail.retryCount}'),
          ]),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}.'
      '${dt.millisecond.toString().padLeft(3, '0')} AM';
}
```

### TimelineTab — col 3 avec icônes colorées

```dart
// lib/src/ui/panels/mutations/secondary_tabs/timeline_tab.dart
class TimelineTab extends StatelessWidget {
  const TimelineTab();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<TimelineNotifier>();
    final events = notifier.filteredEvents;

    return Column(children: [
      // ── Toolbar ────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          Text(
            'TIMELINE (${events.length} EVENTS)',
            style: const TextStyle(
              color: Color(0xFF64748B), fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Filter input
          SizedBox(
            width: 80, height: 26,
            child: TextField(
              onChanged: notifier.setFilter,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Filter…',
                hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 11),
                prefixIcon: const Icon(Icons.filter_list_rounded,
                    size: 12, color: Color(0xFF475569)),
                filled: true, fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Pause / Resume
          _ToolbarChip(
            label: notifier.paused ? 'Resume' : 'Pause',
            onTap: notifier.togglePause,
          ),
          const SizedBox(width: 4),
          // Clear
          _ToolbarChip(label: 'Clear', onTap: notifier.clear),
        ]),
      ),
      // ── Liste ──────────────────────────────────────────────────
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: events.length,
          itemBuilder: (context, i) => TimelineEventRow(event: events[i]),
        ),
      ),
    ]);
  }
}

// Icônes colorées par type — fidèle au screenshot
class TimelineEventRow extends StatelessWidget {
  final TimelineEvent event;
  const TimelineEventRow({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconForType(event.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15), shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.type.displayName, style: const TextStyle(
              color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w500,
            )),
            if (event.key != null)
              Text(event.key!, style: const TextStyle(
                color: Color(0xFF64748B), fontSize: 10, fontFamily: 'monospace',
              )),
          ]),
        ),
        Text(_fmtTime(event.timestamp), style: const TextStyle(
          color: Color(0xFF475569), fontSize: 10, fontFamily: 'monospace',
        )),
      ]),
    );
  }

  (IconData, Color) _iconForType(TimelineEventType t) => switch (t) {
    TimelineEventType.optimisticUpdate  => (Icons.auto_fix_high,        const Color(0xFFF59E0B)),
    TimelineEventType.mutationStarted   => (Icons.play_arrow_rounded,   const Color(0xFF8B5CF6)),
    TimelineEventType.mutationSuccess   => (Icons.check_circle_outline, const Color(0xFF22C55E)),
    TimelineEventType.mutationError     => (Icons.error_outline,        const Color(0xFFEF4444)),
    TimelineEventType.fetchStarted      => (Icons.download_rounded,     const Color(0xFF3B82F6)),
    TimelineEventType.fetchError        => (Icons.cloud_off_rounded,    const Color(0xFFEF4444)),
    TimelineEventType.queryCreated      => (Icons.add_circle_outline,   const Color(0xFF22C55E)),
    TimelineEventType.cacheCleared      => (Icons.delete_sweep_rounded, const Color(0xFF94A3B8)),
    _                                   => (Icons.circle,               const Color(0xFF64748B)),
  };

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}.'
      '${dt.millisecond.toString().padLeft(3, '0')} AM';
}
```

---

## 10. Intégration Utilisateur

```dart
// main.dart — 2 lignes suffisent
import 'package:qora_devtools_overlay/qora_devtools_overlay.dart';

void main() {
  runApp(
    QoraInspector(
      client: queryClient,
      child: MyApp(),
    ),
  );
}
```

---

## 11. Zéro Overhead en Production

```dart
// Niveau 1 — dev_dependencies (package absent du release bundle)
dev_dependencies:
  qora_devtools_overlay: ^1.0.0

// Niveau 2 — guard widget
@override
Widget build(BuildContext context) {
  if (!kDebugMode) return child; // court-circuit total
  return _buildDebugOverlay();
}

// Niveau 3 — tracker jamais instancié
@override
void initState() {
  super.initState();
  if (!kDebugMode) return; // stream jamais ouvert, 0 byte alloué
  _tracker = OverlayTracker();
  widget.client.debugSetTracker(_tracker);
}
```

Le tree-shaker Dart élimine tout code sous `kDebugMode` en release. **Résultat : 0 byte ajouté au bundle prod.**

---

## 12. Graphe de dépendances final

```
packages/
├── qora/                          ← noyau (aveugle)
│
├── qora_devtools_shared/          ← protocole (pur Dart)
│     QoraEvent, TimelineEvent, MutationDetail, BreadcrumbKey model…
│
├── qora_devtools_extension/       ← VM bridge pour l'IDE
│
├── qora_devtools_ui/              ← extension IDE officielle
│
└── qora_devtools_overlay/         ← in-app overlay
      OverlayTracker               dépend de: qora + shared uniquement
      ResponsivePanelLayout        ≥600px → 3 cols | <600px → stack animé
      MutationInspectorNotifier    sélection + retry
      TimelineNotifier             pause / filter / clear
```

### Les deux surfaces DevTools

| | `qora_devtools_ui` (IDE) | `qora_devtools_overlay` (in-app) |
|---|---|---|
| **Activation** | VS Code / IntelliJ | `QoraInspector` wrapper |
| **Transport** | Dart VM Service | Direct (même process) |
| **Layout** | Libre (fenêtre IDE) | 3 cols ≥600px / stack <600px |
| **Petit écran** | N/A | Stack avec `_MobileNavBar` |
| **Release build** | Absent | `kDebugMode` guard |
| **Meilleur pour** | Debugging profond | Développement au quotidien |

---

*Qora DevTools Overlay v2 — mis à jour depuis UI screenshot*

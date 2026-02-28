import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qora_devtools_overlay/src/data/overlay_tracker.dart';
import 'package:qora_devtools_overlay/src/domain/cache_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/mutation_inspector_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/mutations_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/queries_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/timeline_notifier.dart';
import 'package:qora_devtools_overlay/src/ui/fab/qora_fab.dart';
import 'package:qora_devtools_overlay/src/ui/panel/qora_panel.dart';

/// Public entry point for the Qora DevTools overlay.
///
/// Wraps [child] with the DevTools FAB and panel. Zero overhead in release
/// builds — the entire overlay is tree-shaken when [kDebugMode] is `false`.
///
/// ## Setup
///
/// ```dart
/// // 1. Create a shared tracker
/// final tracker = OverlayTracker();
///
/// // 2. Pass it to QoraClient so it receives hook calls
/// final client = QoraClient(tracker: tracker);
///
/// // 3. Wrap your app
/// runApp(
///   QoraInspector(
///     tracker: tracker,
///     child: MyApp(),
///   ),
/// );
/// ```
///
/// The overlay only mounts its widget tree in `kDebugMode`. In release builds,
/// [child] is returned directly with no extra allocations.
class QoraInspector extends StatefulWidget {
  const QoraInspector({
    super.key,
    required this.child,
    required this.tracker,
  });

  final Widget child;

  /// The [OverlayTracker] connected to the [QoraClient] of this app.
  final OverlayTracker tracker;

  @override
  State<QoraInspector> createState() => _QoraInspectorState();
}

class _QoraInspectorState extends State<QoraInspector> {
  late final TimelineNotifier _timelineNotifier;
  late final MutationInspectorNotifier _mutationInspectorNotifier;
  late final QueriesNotifier _queriesNotifier;
  late final MutationsNotifier _mutationsNotifier;
  late final CacheNotifier _cacheNotifier;

  bool _panelOpen = false;

  @override
  void initState() {
    super.initState();
    if (!kDebugMode) return;
    _timelineNotifier = TimelineNotifier(widget.tracker);
    _mutationInspectorNotifier = MutationInspectorNotifier(widget.tracker);
    _queriesNotifier = QueriesNotifier(widget.tracker);
    _mutationsNotifier = MutationsNotifier(widget.tracker);
    _cacheNotifier = CacheNotifier(widget.tracker);
  }

  @override
  void dispose() {
    if (kDebugMode) {
      _timelineNotifier.dispose();
      _mutationInspectorNotifier.dispose();
      _queriesNotifier.dispose();
      _mutationsNotifier.dispose();
      _cacheNotifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _queriesNotifier),
        ChangeNotifierProvider.value(value: _mutationsNotifier),
        ChangeNotifierProvider.value(value: _mutationInspectorNotifier),
        ChangeNotifierProvider.value(value: _timelineNotifier),
        ChangeNotifierProvider.value(value: _cacheNotifier),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            widget.child,
            if (_panelOpen)
              QoraPanel(onClose: () => setState(() => _panelOpen = false)),
            if (!_panelOpen)
              QoraFab(onTap: () => setState(() => _panelOpen = true)),
          ],
        ),
      ),
    );
  }
}

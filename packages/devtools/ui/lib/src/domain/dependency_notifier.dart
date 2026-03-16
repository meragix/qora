import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/usecases/observe_events.dart';

/// A node in the dependency graph — either a mutation or a query.
class GraphNode {
  /// Creates a graph node.
  const GraphNode(
      {required this.id, required this.label, required this.isMutation});

  /// Unique node identifier (mutation ID or query key).
  final String id;

  /// Human-readable label shown in the graph.
  final String label;

  /// `true` for mutation nodes, `false` for query nodes.
  final bool isMutation;
}

/// A directed edge from a mutation node to a query node.
///
/// Inferred via temporal correlation — see [DependencyNotifier].
class GraphEdge {
  /// Creates a graph edge.
  const GraphEdge({required this.fromMutationId, required this.toQueryKey});

  /// Source mutation node ID.
  final String fromMutationId;

  /// Destination query node key.
  final String toQueryKey;
}

/// A directed edge from a dependency query node to a dependent query node.
///
/// Created from authoritative [QueryEvent.dependsOnKey] data — no heuristic
/// involved. Corresponds to `QoraOptions.dependsOn` declared in the app.
class DependsOnEdge {
  /// Creates a query→query dependency edge.
  const DependsOnEdge({
    required this.dependencyKey,
    required this.dependentKey,
  });

  /// The query that must resolve first (the dependency).
  final String dependencyKey;

  /// The query that declared [dependencyKey] as its `dependsOn`.
  final String dependentKey;
}

/// Pending mutation record used for temporal correlation.
class _PendingMutation {
  _PendingMutation(
      {required this.id, required this.key, required this.settledAtMs});

  final String id;
  final String key;
  final int settledAtMs;
}

/// Domain notifier that infers query→mutation dependency edges from event timing.
///
/// ## Inference algorithm
///
/// When a [MutationEvent.settled] arrives, the mutation is added to a
/// short-lived sliding window (max [maxPendingMutations] entries, FIFO eviction).
///
/// When a [QueryEvent.invalidated] arrives, any mutation that settled within
/// [correlationWindowMs] milliseconds before the invalidation is inferred to
/// have caused it, and an edge is recorded.
///
/// This heuristic works well in practice because Qora's `mutate()` callbacks
/// typically call `invalidateQuery()` immediately after settlement.
///
/// ## Limitations
///
/// - Does not capture direct programmatic invalidation (no mutation involved).
/// - Window-based correlation can produce false positives under very high event
///   rates; reduce [correlationWindowMs] if this is an issue.
class DependencyNotifier extends ChangeNotifier {
  /// Creates the notifier and subscribes to [observeEvents].
  DependencyNotifier({
    required ObserveEventsUseCase observeEvents,
    this.correlationWindowMs = 500,
    this.maxPendingMutations = 50,
  }) {
    _subscription = observeEvents().listen(_onEvent);
  }

  /// Maximum time gap (ms) between mutation settlement and query invalidation
  /// to consider them correlated.
  final int correlationWindowMs;

  /// Maximum number of recently settled mutations kept in the sliding window.
  final int maxPendingMutations;

  late final StreamSubscription<QoraEvent> _subscription;

  final Map<String, GraphNode> _nodes = <String, GraphNode>{};
  final List<GraphEdge> _edges = <GraphEdge>[];
  final List<DependsOnEdge> _dependsOnEdges = <DependsOnEdge>[];
  final List<_PendingMutation> _pendingMutations = <_PendingMutation>[];

  /// All graph nodes (mutations + queries that have appeared in events).
  List<GraphNode> get nodes => List<GraphNode>.unmodifiable(_nodes.values);

  /// All inferred mutation→query dependency edges (temporal heuristic).
  List<GraphEdge> get edges => List<GraphEdge>.unmodifiable(_edges);

  /// All authoritative query→query dependency edges sourced from
  /// [QueryEvent.dependsOnKey] (set via `QoraOptions.dependsOn` in the app).
  List<DependsOnEdge> get dependsOnEdges =>
      List<DependsOnEdge>.unmodifiable(_dependsOnEdges);

  void _onEvent(QoraEvent event) {
    if (event is MutationEvent) {
      if (event.type == MutationEventType.settled) {
        final node = GraphNode(
          id: event.id,
          label: event.key.isNotEmpty ? event.key : event.id,
          isMutation: true,
        );
        _nodes[event.id] = node;

        _pendingMutations.add(
          _PendingMutation(
            id: event.id,
            key: event.key,
            settledAtMs: event.timestampMs,
          ),
        );
        if (_pendingMutations.length > maxPendingMutations) {
          _pendingMutations.removeAt(0);
        }
        notifyListeners();
      }
      return;
    }

    if (event is QueryEvent && event.type == QueryEventType.fetched) {
      final depKey = event.dependsOnKey;
      if (depKey != null && depKey.isNotEmpty) {
        // Ensure both nodes exist.
        _nodes.putIfAbsent(
          depKey,
          () => GraphNode(id: depKey, label: depKey, isMutation: false),
        );
        _nodes.putIfAbsent(
          event.key,
          () => GraphNode(id: event.key, label: event.key, isMutation: false),
        );
        final exists = _dependsOnEdges.any(
          (e) => e.dependencyKey == depKey && e.dependentKey == event.key,
        );
        if (!exists) {
          _dependsOnEdges.add(
            DependsOnEdge(dependencyKey: depKey, dependentKey: event.key),
          );
          notifyListeners();
        }
      }
      return;
    }

    if (event is QueryEvent && event.type == QueryEventType.invalidated) {
      final queryKey = event.key;
      final nowMs = event.timestampMs;

      _nodes.putIfAbsent(
        queryKey,
        () => GraphNode(id: queryKey, label: queryKey, isMutation: false),
      );

      // Find all mutations that settled within the correlation window.
      for (final mut in _pendingMutations) {
        if (nowMs - mut.settledAtMs <= correlationWindowMs) {
          final edge = GraphEdge(
            fromMutationId: mut.id,
            toQueryKey: queryKey,
          );
          // Avoid duplicate edges.
          final exists = _edges.any(
            (e) =>
                e.fromMutationId == edge.fromMutationId &&
                e.toQueryKey == edge.toQueryKey,
          );
          if (!exists) {
            _edges.add(edge);
          }
        }
      }
      notifyListeners();
    }
  }

  /// Clears all nodes and edges (both heuristic and authoritative).
  void clear() {
    _nodes.clear();
    _edges.clear();
    _dependsOnEdges.clear();
    _pendingMutations.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

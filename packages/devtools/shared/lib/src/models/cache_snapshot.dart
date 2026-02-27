import 'mutation_snapshot.dart';
import 'query_snapshot.dart';

/// Full cache dump transported from the runtime bridge to DevTools.
final class CacheSnapshot {
  /// Query snapshots indexed in insertion order.
  final List<QuerySnapshot> queries;

  /// Mutation snapshots indexed in insertion order.
  final List<MutationSnapshot> mutations;

  /// Snapshot creation timestamp in unix epoch milliseconds.
  final int emittedAtMs;

  /// Creates a cache snapshot.
  const CacheSnapshot({
    required this.queries,
    required this.mutations,
    required this.emittedAtMs,
  });

  /// Creates an instance from JSON.
  factory CacheSnapshot.fromJson(Map<String, Object?> json) {
    return CacheSnapshot(
      queries: ((json['queries'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => QuerySnapshot.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false),
      mutations: ((json['mutations'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) => MutationSnapshot.fromJson(Map<String, Object?>.from(item)),
          )
          .toList(growable: false),
      emittedAtMs: (json['emittedAtMs'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Converts the snapshot to JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'queries': queries.map((query) => query.toJson()).toList(growable: false),
        'mutations': mutations.map((mutation) => mutation.toJson()).toList(growable: false),
        'emittedAtMs': emittedAtMs,
      };
}

import 'mutation_snapshot.dart';
import 'query_snapshot.dart';

/// Full cache dump transported from the runtime bridge to DevTools.
///
/// A [CacheSnapshot] is produced on demand when the DevTools UI calls
/// `ext.qora.getCacheSnapshot`. It represents a **point-in-time view** of
/// the cache — it is not a live stream.
///
/// ## Scaling note — snapshot size
///
/// For large applications with thousands of active queries or mutations, this
/// response can become very large. To mitigate:
/// - [QuerySnapshot.data] is omitted for large payloads (only metadata is
///   included; use `ext.qora.getPayloadChunk` to pull raw data).
/// - [QuerySnapshot.summary] provides lightweight statistics for the cache
///   inspector list view without requiring the full payload.
///
/// If snapshot size becomes a concern, add server-side pagination support:
/// a `page` + `pageSize` param to `getCacheSnapshot` and a matching
/// [CacheSnapshot] `hasMore` flag.
final class CacheSnapshot {
  /// Query snapshots in insertion order (oldest first).
  ///
  /// Each entry corresponds to one active query key in the Qora cache.
  final List<QuerySnapshot> queries;

  /// Mutation snapshots in insertion order (oldest first).
  ///
  /// Only includes mutations that have been started but not yet garbage-
  /// collected by the runtime.
  final List<MutationSnapshot> mutations;

  /// Unix epoch milliseconds at the moment the snapshot was created on the app
  /// side.
  ///
  /// Use this to indicate snapshot staleness in the DevTools header.
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

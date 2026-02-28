/// Immutable view of a mutation state used by DevTools timeline and details.
///
/// [MutationSnapshot] is included in [CacheSnapshot.mutations] and exposes
/// all in-flight or recently settled mutations at snapshot time.
///
/// ## Lifecycle correlation
///
/// Use [id] to correlate this snapshot with [MutationEvent] entries in the
/// timeline: a snapshot entry and its matching events share the same [id].
/// The elapsed time `(settledAtMs ?? now) - startedAtMs` gives the duration.
final class MutationSnapshot {
  /// Runtime-assigned mutation identifier, stable across retries.
  final String id;

  /// Associated query/cache key invalidated or updated on settlement.
  final String key;

  /// Mutation lifecycle status.
  ///
  /// Common values: `'started'`, `'running'`, `'settled'`.
  final String status;

  /// Input variables dispatched to the mutation function.
  final Object? variables;

  /// Settlement result — server response on success or error details on failure.
  ///
  /// `null` before settlement.
  final Object? result;

  /// Settlement outcome — `true` on success, `false` on failure.
  ///
  /// `null` before settlement.
  final bool? success;

  /// Unix epoch milliseconds when the mutation was initiated.
  final int startedAtMs;

  /// Unix epoch milliseconds when the mutation settled.
  ///
  /// `null` for in-flight mutations. Use `DateTime.now().millisecondsSinceEpoch`
  /// as an upper-bound for elapsed-time calculations.
  final int? settledAtMs;

  /// Creates a mutation snapshot.
  const MutationSnapshot({
    required this.id,
    required this.key,
    required this.status,
    required this.startedAtMs,
    this.variables,
    this.result,
    this.success,
    this.settledAtMs,
  });

  /// Creates an instance from JSON.
  factory MutationSnapshot.fromJson(Map<String, Object?> json) {
    return MutationSnapshot(
      id: (json['id'] as String?) ?? '',
      key: (json['key'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'unknown',
      variables: json['variables'],
      result: json['result'],
      success: json['success'] as bool?,
      startedAtMs: (json['startedAtMs'] as int?) ?? 0,
      settledAtMs: json['settledAtMs'] as int?,
    );
  }

  /// Converts the snapshot to JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'key': key,
        'status': status,
        'variables': variables,
        'result': result,
        'success': success,
        'startedAtMs': startedAtMs,
        'settledAtMs': settledAtMs,
      };
}

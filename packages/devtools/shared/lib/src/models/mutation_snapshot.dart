/// Immutable view of a mutation state used by DevTools timeline and details.
final class MutationSnapshot {
  /// Mutation identifier.
  final String id;

  /// Associated query/cache key.
  final String key;

  /// Mutation status (`started`, `running`, `settled`, ...).
  final String status;

  /// Input variables.
  final Object? variables;

  /// Output result.
  final Object? result;

  /// Whether the mutation settled with success.
  final bool? success;

  /// Mutation start timestamp in unix epoch milliseconds.
  final int startedAtMs;

  /// Optional mutation settle timestamp in unix epoch milliseconds.
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

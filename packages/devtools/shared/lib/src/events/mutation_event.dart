import 'qora_event.dart';

/// Enumerates mutation event subtypes emitted by the runtime.
///
/// Mutations progress through a predictable lifecycle:
///
/// ```
/// (none) ─── started ──► updated* ──► settled
///                          ▲ 0..n re-emissions during in-flight retries
/// ```
///
/// The DevTools timeline correlates events by [MutationEvent.id] so that
/// retries appear as a linked chain rather than independent entries.
enum MutationEventType {
  /// Mutation has started execution (variables dispatched to the server).
  started,

  /// Mutation has settled — either succeeded or failed.
  ///
  /// Check [MutationEvent.success] to determine the outcome.
  /// [MutationEvent.result] carries the response payload on success or the
  /// error details on failure.
  settled,

  /// Mutation state has been updated in-flight (e.g. retry in progress).
  ///
  /// Emitted zero or more times between `started` and `settled`.
  updated,
}

/// Typed protocol event for mutation lifecycle changes.
///
/// Mutations are identified by a runtime-generated [id] that remains stable
/// across retries. The [key] field links the mutation to the query cache entry
/// it invalidates or updates on completion.
///
/// ## Correlation by [id]
///
/// The DevTools timeline groups multiple events sharing the same [id] into a
/// single mutation row, displaying the full lifecycle as a timeline segment.
/// When building new UI panels, always use [id] — not [timestampMs] — to
/// correlate `started` / `updated` / `settled` events.
///
/// ## Variables and result size
///
/// [variables] and [result] are sent inline and are **not** subject to lazy
/// chunking. If mutation payloads are expected to be large (e.g. batch
/// operations), consider storing only a summary here and adding a dedicated
/// `mutation.payload` event with lazy loading support in a future version.
final class MutationEvent extends QoraEvent {
  /// Mutation event subtype.
  final MutationEventType type;

  /// Runtime-assigned mutation identifier, stable across retries.
  final String id;

  /// Query/cache key associated with this mutation.
  ///
  /// Matches the key that will be invalidated or updated on settlement.
  final String key;

  /// Optional input variables dispatched to the mutation function.
  final Object? variables;

  /// Optional result payload — present only on [MutationEventType.settled].
  ///
  /// Contains the server response on success or error details on failure.
  final Object? result;

  /// Settlement outcome — `true` on success, `false` on failure.
  ///
  /// Only meaningful for [MutationEventType.settled]; `null` otherwise.
  final bool? success;

  /// Creates a mutation event.
  ///
  /// Prefer the named factories ([MutationEvent.started], [MutationEvent.settled])
  /// which auto-generate [eventId] and [timestampMs].
  MutationEvent({
    required super.eventId,
    required super.timestampMs,
    required this.type,
    required this.id,
    required this.key,
    this.variables,
    this.result,
    this.success,
  }) : super(kind: 'mutation.${type.name}');

  /// Helper constructor for `mutation.started`.
  ///
  /// Auto-generates [QoraEvent.eventId] and timestamps the event at call time.
  factory MutationEvent.started({
    required String id,
    required String key,
    Object? variables,
  }) {
    return MutationEvent(
      eventId: QoraEvent.generateId(),
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      type: MutationEventType.started,
      id: id,
      key: key,
      variables: variables,
    );
  }

  /// Helper constructor for `mutation.settled`.
  ///
  /// Auto-generates [QoraEvent.eventId] and timestamps the event at call time.
  factory MutationEvent.settled({
    required String id,
    required String key,
    required bool success,
    Object? result,
  }) {
    return MutationEvent(
      eventId: QoraEvent.generateId(),
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      type: MutationEventType.settled,
      id: id,
      key: key,
      success: success,
      result: result,
    );
  }

  /// Deserializes a mutation event from a raw JSON map.
  ///
  /// Tolerant of missing fields: falls back to sensible defaults so that
  /// partial payloads emitted by older runtimes do not throw.
  /// Unknown `kind` suffixes resolve to [MutationEventType.updated].
  factory MutationEvent.fromJson(Map<String, Object?> json) {
    final rawKind = (json['kind'] as String?) ?? 'mutation.updated';
    final kindSuffix = rawKind.startsWith('mutation.') ? rawKind.substring('mutation.'.length) : rawKind;
    final type = MutationEventType.values.firstWhere(
      (value) => value.name == kindSuffix,
      orElse: () => MutationEventType.updated,
    );

    return MutationEvent(
      eventId: (json['eventId'] as String?) ?? QoraEvent.generateId(),
      timestampMs: (json['timestampMs'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      type: type,
      id: (json['mutationId'] as String?) ?? '',
      key: (json['queryKey'] as String?) ?? '',
      variables: json['variables'],
      result: json['result'],
      success: json['success'] as bool?,
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'kind': kind,
        'timestampMs': timestampMs,
        'mutationId': id,
        'queryKey': key,
        'variables': variables,
        'result': result,
        'success': success,
      };
}

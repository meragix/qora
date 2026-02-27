import 'qora_event.dart';

/// Enumerates mutation event subtypes emitted by the runtime.
enum MutationEventType {
  /// Mutation has started execution.
  started,

  /// Mutation has completed.
  settled,

  /// Mutation has been updated in-flight.
  updated,
}

/// Typed protocol event for mutation lifecycle changes.
final class MutationEvent extends QoraEvent {
  /// Mutation event subtype.
  final MutationEventType type;

  /// Runtime mutation identifier.
  final String id;

  /// Query/cache key associated with the mutation.
  final String key;

  /// Optional input variables.
  final Object? variables;

  /// Optional result payload.
  final Object? result;

  /// Mutation result marker for settled events.
  final bool? success;

  /// Creates a mutation event.
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

  /// Deserializes a mutation event.
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

import 'dart:math';

/// Base contract for every event exchanged between the Qora runtime bridge
/// and the DevTools UI.
///
/// Implementations must provide a stable JSON representation through [toJson].
abstract class QoraEvent {
  /// Unique event identifier.
  final String eventId;

  /// Event kind (example: `query.fetched`, `mutation.started`).
  final String kind;

  /// Unix epoch in milliseconds.
  final int timestampMs;

  /// Creates a protocol event.
  const QoraEvent({
    required this.eventId,
    required this.kind,
    required this.timestampMs,
  });

  /// Converts the event to a JSON-safe map.
  Map<String, Object?> toJson();

  /// Generates a compact unique-ish identifier suitable for debug tooling.
  static String generateId() {
    final random = Random().nextInt(0x7fffffff).toRadixString(16);
    return 'evt_${DateTime.now().microsecondsSinceEpoch}_$random';
  }
}

/// Fallback event used when no typed event implementation matches.
///
/// This keeps the protocol forward-compatible: older UI versions can still
/// display unknown events without crashing.
final class GenericQoraEvent extends QoraEvent {
  /// Creates a generic event with arbitrary [payload].
  GenericQoraEvent({
    required super.eventId,
    required super.kind,
    required super.timestampMs,
    Map<String, Object?>? payload,
  }) : payload = payload ?? const <String, Object?>{};

  /// Additional untyped fields.
  final Map<String, Object?> payload;

  /// Builds a generic event from a JSON map.
  factory GenericQoraEvent.fromJson(Map<String, Object?> json) {
    return GenericQoraEvent(
      eventId: (json['eventId'] as String?) ?? QoraEvent.generateId(),
      kind: (json['kind'] as String?) ?? 'unknown',
      timestampMs: (json['timestampMs'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      payload: Map<String, Object?>.from(json),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        ...payload,
        'eventId': eventId,
        'kind': kind,
        'timestampMs': timestampMs,
      };
}

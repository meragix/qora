import 'package:qora_devtools_shared/src/events/mutation_event.dart';
import 'package:qora_devtools_shared/src/events/qora_event.dart';
import 'package:qora_devtools_shared/src/events/query_event.dart';

/// JSON codec for Qora protocol events.
abstract final class EventCodec {
  /// Decodes an event payload received from VM service.
  ///
  /// Unknown kinds are deserialized as [GenericQoraEvent] to preserve
  /// forward compatibility.
  static QoraEvent decode(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Event payload must be a map');
    }

    final json = Map<String, Object?>.from(raw);
    final kind = json['kind'] as String?;
    if (kind == null) {
      return GenericQoraEvent.fromJson(json);
    }
    if (kind.startsWith('query.')) {
      return QueryEvent.fromJson(json);
    }
    if (kind.startsWith('mutation.')) {
      return MutationEvent.fromJson(json);
    }
    return GenericQoraEvent.fromJson(json);
  }

  /// Encodes an event into a JSON-safe map.
  static Map<String, Object?> encode(QoraEvent event) => event.toJson();
}

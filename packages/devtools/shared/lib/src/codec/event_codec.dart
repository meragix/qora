import 'package:qora_devtools_shared/src/events/mutation_event.dart';
import 'package:qora_devtools_shared/src/events/qora_event.dart';
import 'package:qora_devtools_shared/src/events/query_event.dart';

/// JSON codec for Qora protocol events.
///
/// [EventCodec] is the single entry-point for deserialising the raw maps
/// received from `developer.postEvent` on the VM service `Extension` stream.
///
/// ## Dispatch table
///
/// | Kind prefix   | Target class       |
/// |---------------|--------------------|
/// | `query.*`     | [QueryEvent]       |
/// | `mutation.*`  | [MutationEvent]    |
/// | *(anything)*  | [GenericQoraEvent] |
///
/// This design keeps the codec **open for extension** (OCP): adding a new
/// event domain only requires inserting a new `if (kind.startsWith(...))`
/// branch — no existing code changes.
///
/// ## Adding a new event domain
///
/// ```dart
/// // In EventCodec.decode, before the fallback:
/// if (kind.startsWith('optimistic.')) {
///   return OptimisticEvent.fromJson(json);
/// }
/// ```
///
/// Then export the new class from `qora_devtools_shared.dart`.
abstract final class EventCodec {
  /// Decodes an event payload received from the VM service extension stream.
  ///
  /// [raw] must be a `Map` (the type returned by `extensionData.data`).
  /// Throws [FormatException] only when the top-level type is not a `Map` —
  /// missing or malformed fields within the map are handled gracefully by each
  /// [QoraEvent] subclass.
  ///
  /// Unknown kinds are deserialized as [GenericQoraEvent] to preserve
  /// forward compatibility across protocol versions.
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

  /// Encodes an event into a JSON-safe map for `developer.postEvent`.
  ///
  /// Delegates to [QoraEvent.toJson] — no transformation is applied.
  static Map<String, Object?> encode(QoraEvent event) => event.toJson();
}

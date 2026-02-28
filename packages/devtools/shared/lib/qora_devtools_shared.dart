/// Shared protocol package for Qora DevTools.
///
/// This package is the **single source of truth** for the communication
/// contract between the runtime bridge (`qora_devtools_extension`) and the
/// DevTools UI (`qora_devtools_ui`). It must remain Flutter-agnostic so that
/// it can be consumed in pure-Dart test suites without a Flutter engine.
///
/// ## Package layout
///
/// ```
/// qora_devtools_shared/
/// ├── src/
/// │   ├── events/          ← Push  : App → DevTools (query.*, mutation.*, ...)
/// │   ├── commands/        ← Pull  : DevTools → App (refetch, invalidate, ...)
/// │   ├── models/          ← DTOs  : CacheSnapshot, QuerySnapshot, ...
/// │   ├── codec/           ← JSON  : EventCodec, CommandCodec
/// │   └── protocol/        ← Names : QoraExtensionMethods, QoraExtensionEvents
/// ```
///
/// ## Communication model (push / pull)
///
/// ```
/// App (qora_devtools_extension)           DevTools UI (qora_devtools_ui)
///  │                                               │
///  │── postEvent('qora:event', event.toJson()) ──► │  push: lightweight events
///  │                                               │
///  │◄── callServiceExtension('ext.qora.*') ───────  │  pull: heavy payloads,
///  │                                               │  commands (refetch, ...)
/// ```
///
/// ## Versioning discipline
///
/// Because both sides of the protocol are updated independently, follow these
/// rules when extending the shared package:
///
/// - **Add new event kinds**: create a subclass of [QoraEvent] and add a
///   branch to [EventCodec.decode]. Never remove existing `kind` strings.
/// - **Add new commands**: create a subclass of [QoraCommand], add a constant
///   to [QoraExtensionMethods], and add a branch to [CommandCodec.decode].
/// - **Rename fields**: add the new field, keep the old one for one semver
///   minor, then drop it in the next major.
/// - **Bump the pubspec version** whenever the JSON schema changes in a
///   breaking way; both `extension` and `ui` must update their constraint.
///
/// ## Quick-start
///
/// ```dart
/// import 'package:qora_devtools_shared/qora_devtools_shared.dart';
///
/// // Encode an event for postEvent:
/// final event = QueryEvent.fetched(key: 'todos', status: 'success');
/// developer.postEvent(QoraExtensionEvents.qoraEvent, event.toJson());
///
/// // Decode an event received from the VM service stream:
/// final decoded = EventCodec.decode(extensionData.data);
///
/// // Dispatch a command from the DevTools UI:
/// final cmd = RefetchCommand(queryKey: 'todos');
/// await vmService.callServiceExtension(
///   '${QoraExtensionMethods.prefix}.${cmd.method}',
///   args: cmd.params,
/// );
/// ```
library;

// Commands
export 'src/commands/get_cache_snapshot_command.dart';
export 'src/commands/get_playload_chunk_command.dart';
export 'src/commands/invalidate_command.dart';
export 'src/commands/qora_command.dart';
export 'src/commands/refetch_command.dart';
export 'src/commands/rollback_optimic_command.dart';

// Codecs
export 'src/codec/command_codec.dart';
export 'src/codec/event_codec.dart';

// Events
export 'src/events/mutation_event.dart';
export 'src/events/qora_event.dart';
export 'src/events/query_event.dart';
export 'src/events/timeline_event.dart';

// Models
export 'src/models/cache_snapshot.dart';
export 'src/models/mutation_snapshot.dart';
export 'src/models/query_snapshot.dart';

// Protocol
export 'src/protocol/extension_methods.dart';

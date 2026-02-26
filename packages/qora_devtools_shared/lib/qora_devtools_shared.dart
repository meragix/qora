/// Shared protocol package for Qora DevTools.
///
/// This package defines:
/// - transport-safe event models (`QoraEvent` and specializations),
/// - command contracts used by the DevTools UI to control the runtime,
/// - JSON codecs for event/command serialization,
/// - VM service extension method names.
///
/// The package is intentionally Flutter-agnostic so it can be reused by:
/// - the mobile/desktop runtime bridge (`qora_devtools_extension`),
/// - the DevTools extension UI (`qora_devtools_ui`),
/// - protocol-focused unit/integration tests.
library;

// Commands
export 'src/commands/get_cache_snapshot_command.dart';
export 'src/commands/get_playload_chunk_command.dart';
export 'src/commands/invalidate_command.dart';
export 'src/commands/refetch_command.dart';
export 'src/commands/rollback_optimic_command.dart';

// Codecs
export 'src/codec/command_codec.dart';
export 'src/codec/event_codec.dart';

// Events
export 'src/events/mutation_event.dart';
export 'src/events/qora_event.dart';
export 'src/events/query_event.dart';

// Models
export 'src/models/cache_snapshot.dart';
export 'src/models/mutation_snapshot.dart';
export 'src/models/query_snapshot.dart';

// Protocol
export 'src/protocol/extension_methods.dart';

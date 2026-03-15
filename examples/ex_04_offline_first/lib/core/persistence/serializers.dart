import 'package:qora_flutter/qora_flutter.dart';

import '../../features/todos/models/todo.dart';

/// Registers every type that should survive app restarts in [PersistQoraClient].
///
/// This function is the single authoritative list of persisted types.
/// Explicit [name] values are required so the registry survives Dart
/// obfuscation (`--obfuscate`) and Flutter Web tree-shaking.
///
/// Call this once at startup, **before** [PersistQoraClient.hydrate].
void registerAllSerializers(PersistQoraClient client) {
  client.registerSerializer<List<Todo>>(
    QoraSerializer(
      toJson: (list) => list.map((t) => t.toJson()).toList(),
      fromJson: (json) => (json as List).map((e) => Todo.fromJson(e)).toList(),
    ),
    name: 'List<Todo>',
  );
}

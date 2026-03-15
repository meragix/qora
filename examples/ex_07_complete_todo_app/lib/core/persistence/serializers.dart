import 'package:qora_flutter/qora_flutter.dart';

import '../../core/auth/auth_service.dart';

/// Registers every type that should survive app restarts in [PersistQoraClient].
///
/// Todos are fetched via [InfiniteQueryBuilder] and are not individually
/// persisted — the infinite page structure makes them impractical to
/// serialise/deserialise cleanly. Auth data, however, is small and benefits
/// greatly from hydration so the user session is restored without a login
/// screen flash.
///
/// Call this once at startup, **before** [PersistQoraClient.hydrate].
void registerAllSerializers(PersistQoraClient client) {
  client.registerSerializer<AuthUser>(
    QoraSerializer(
      toJson: (user) => user.toJson(),
      fromJson: (json) => AuthUser.fromJson(json as Map<String, dynamic>),
    ),
    name: 'AuthUser',
  );
}

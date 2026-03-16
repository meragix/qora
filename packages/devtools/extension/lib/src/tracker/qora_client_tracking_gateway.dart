import 'dart:convert';

import 'package:qora/qora.dart';
// Hide the protocol MutationEvent — this file uses the core qora MutationEvent
// (from QoraClient.activeMutations) which has different fields.
import 'package:qora_devtools_shared/qora_devtools_shared.dart'
    hide MutationEvent;

import 'tracking_gateway.dart';

/// Default [TrackingGateway] implementation backed by a [QoraClient].
///
/// Eliminates the boilerplate of writing a custom [TrackingGateway] for the
/// common case where the app uses a single [QoraClient]. Simply pass it to
/// [ExtensionHandlers] and DevTools commands will be forwarded automatically.
///
/// ## Setup
///
/// ```dart
/// // main_debug.dart — debug/profile builds only
/// final lazy    = LazyPayloadManager();
/// final tracker = VmTracker(lazyPayloadManager: lazy);
/// final client  = QoraClient(tracker: tracker);
///
/// ExtensionRegistrar(
///   handlers: ExtensionHandlers(
///     gateway: QoraClientTrackingGateway(client),   // ← one line
///     lazyPayloadManager: lazy,
///   ),
/// ).registerAll();
/// ```
///
/// ## Key decoding
///
/// DevTools sends query keys as JSON-encoded strings (e.g. `'["users",1]'`).
/// Each gateway method decodes the string with [jsonDecode] before forwarding
/// to [QoraClient], which only accepts `List<dynamic>` or [QoraKey] keys.
///
/// ## getCacheSnapshot
///
/// Iterates [QoraClient.cachedKeys] and calls `getQueryState<dynamic>` for
/// each entry. The status string follows the Qora state machine:
///
/// | `QoraState` subtype | `status`    |
/// |---------------------|-------------|
/// | `Initial`           | `'idle'`    |
/// | `Loading`           | `'loading'` |
/// | `Success`           | `'success'` |
/// | `Failure`           | `'error'`   |
///
/// Only in-flight mutations ([QoraClient.activeMutations]) are included in the
/// mutation list — settled mutations are not retained in the client.
class QoraClientTrackingGateway implements TrackingGateway {
  /// Creates a gateway bound to [client].
  const QoraClientTrackingGateway(this._client);

  final QoraClient _client;

  @override
  bool refetch(String queryKey) {
    // invalidate() marks the entry stale and triggers a background refetch
    // for any active subscriber currently watching the key.
    _client.invalidate(_decodeKey(queryKey));
    return true;
  }

  @override
  bool invalidate(String queryKey) {
    _client.invalidate(_decodeKey(queryKey));
    return true;
  }

  @override
  bool rollbackOptimistic(String queryKey) {
    // restoreQueryData(key, null) clears the optimistic write and reinstates
    // the pre-optimistic snapshot if one was saved by setQueryData.
    _client.restoreQueryData<dynamic>(_decodeKey(queryKey), null);
    return true;
  }

  @override
  CacheSnapshot getCacheSnapshot() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final queries = <QuerySnapshot>[];
    for (final key in _client.cachedKeys) {
      // dynamic satisfies every CacheEntry<T> is-check — no StateError risk.
      final state = _client.getQueryState<dynamic>(key);
      final status = switch (state) {
        Initial() => 'idle',
        Loading() => 'loading',
        Success() => 'success',
        Failure() => 'error',
      };
      queries.add(QuerySnapshot(
        key: jsonEncode(key),
        status: status,
        data: state.dataOrNull,
        updatedAtMs: nowMs,
      ));
    }

    // activeMutations only contains currently pending (in-flight) entries.
    // The map key equals event.mutatorId; the query key lives in metadata.
    final mutations = _client.activeMutations.values.map((event) {
      final mutationKey =
          (event.metadata?['queryKey'] as String?) ?? '';
      return MutationSnapshot(
        id: event.mutatorId,
        key: mutationKey,
        status: 'running',
        variables: event.variables,
        startedAtMs: event.timestamp.millisecondsSinceEpoch,
      );
    }).toList();

    return CacheSnapshot(
      queries: queries,
      mutations: mutations,
      emittedAtMs: nowMs,
    );
  }

  /// Decodes a JSON-encoded query key string into a [List] suitable for
  /// [QoraClient] key normalisation.
  ///
  /// If [jsonDecode] returns a [List], it is used directly. Any other decoded
  /// type (String, num, bool) is wrapped in a single-element list so that
  /// simple scalar keys still round-trip correctly.
  List<dynamic> _decodeKey(String jsonKey) {
    final decoded = jsonDecode(jsonKey);
    return decoded is List ? decoded : <dynamic>[decoded];
  }
}

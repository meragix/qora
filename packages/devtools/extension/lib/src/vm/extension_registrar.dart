import 'dart:developer' as developer;

import 'package:qora_devtools_shared/qora_devtools_shared.dart';

import 'extension_handlers.dart';

/// Registers all `ext.qora.*` VM service extension handlers with the Dart VM.
///
/// [ExtensionRegistrar] is a thin orchestrator: it maps each Qora extension
/// method name (from [QoraExtensionMethods]) to a handler in [ExtensionHandlers]
/// via `developer.registerExtension`.
///
/// ## Registration lifecycle
///
/// Call [registerAll] **once** during app startup, before the DevTools panel
/// is opened. Registering the same method name twice raises a [StateError]
/// from the Dart VM — guard with a flag if the call site can be reached
/// multiple times (e.g. hot restart in development).
///
/// ## Adding a new extension method
///
/// 1. Add a constant to [QoraExtensionMethods].
/// 2. Add a `handle<Verb>` method to [ExtensionHandlers].
/// 3. Add a `developer.registerExtension(...)` call in [registerAll] below.
///
/// No other files in this package need to change.
class ExtensionRegistrar {
  /// Handler facade invoked for every VM service extension call.
  final ExtensionHandlers handlers;

  /// Creates a registrar bound to the given [handlers].
  const ExtensionRegistrar({required this.handlers});

  /// Registers all `ext.qora.*` service extension methods with the Dart VM.
  ///
  /// Must be called exactly **once** per application lifetime, after the
  /// Flutter engine is initialised but before the DevTools tab is opened.
  ///
  /// Also registers the legacy [QoraExtensionMethods.getPayload] alias for
  /// backward compatibility with older DevTools UI builds.
  void registerAll() {
    developer.registerExtension(
      QoraExtensionMethods.refetch,
      _handleRefetch,
    );
    developer.registerExtension(
      QoraExtensionMethods.invalidate,
      _handleInvalidate,
    );
    developer.registerExtension(
      QoraExtensionMethods.rollbackOptimistic,
      _handleRollback,
    );
    developer.registerExtension(
      QoraExtensionMethods.getCacheSnapshot,
      _handleCacheSnapshot,
    );
    developer.registerExtension(
      QoraExtensionMethods.getPayloadChunk,
      _handlePayloadChunk,
    );

    // Keep compatibility with older UI builds using ext.qora.getPayload.
    developer.registerExtension(
      QoraExtensionMethods.getPayload,
      _handlePayloadChunk,
    );
  }

  Future<developer.ServiceExtensionResponse> _handleRefetch(
    String method,
    Map<String, String> params,
  ) {
    return handlers.refetchResponse(params);
  }

  Future<developer.ServiceExtensionResponse> _handleInvalidate(
    String method,
    Map<String, String> params,
  ) {
    return handlers.invalidateResponse(params);
  }

  Future<developer.ServiceExtensionResponse> _handleRollback(
    String method,
    Map<String, String> params,
  ) {
    return handlers.rollbackResponse(params);
  }

  Future<developer.ServiceExtensionResponse> _handleCacheSnapshot(
    String method,
    Map<String, String> params,
  ) {
    return handlers.snapshotResponse(params);
  }

  Future<developer.ServiceExtensionResponse> _handlePayloadChunk(
    String method,
    Map<String, String> params,
  ) {
    return handlers.payloadChunkResponse(params);
  }
}

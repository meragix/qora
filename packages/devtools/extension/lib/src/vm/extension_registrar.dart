import 'dart:developer' as developer;

import 'package:qora_devtools_shared/qora_devtools_shared.dart';

import 'extension_handlers.dart';

/// Registers all `ext.qora.*` VM service extension handlers.
class ExtensionRegistrar {
  /// Handler facade invoked for each extension call.
  final ExtensionHandlers handlers;

  /// Creates a registrar with concrete [handlers].
  const ExtensionRegistrar({required this.handlers});

  /// Registers all service extension methods.
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

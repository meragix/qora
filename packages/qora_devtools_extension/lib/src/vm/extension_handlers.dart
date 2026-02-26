import 'dart:convert';
import 'dart:developer' as developer;

import 'package:qora_devtools_extension/src/lazy/lazy_payload_manager.dart';
import 'package:qora_devtools_extension/src/tracker/tracking_gateway.dart';

/// Request handlers backing VM service extension methods.
class ExtensionHandlers {
  final TrackingGateway _gateway;
  final LazyPayloadManager _lazy;

  /// Creates extension handlers.
  const ExtensionHandlers({
    required TrackingGateway gateway,
    required LazyPayloadManager lazyPayloadManager,
  })  : _gateway = gateway,
        _lazy = lazyPayloadManager;

  /// Handles `ext.qora.refetch`.
  Future<developer.ServiceExtensionResponse> refetchResponse(
    Map<String, String> params,
  ) async {
    final queryKey = params['queryKey'];
    if (queryKey == null || queryKey.isEmpty) {
      return _badRequest('Missing required param: queryKey');
    }
    final ok = await _gateway.refetch(queryKey);
    return _ok(<String, Object?>{'ok': ok, 'queryKey': queryKey});
  }

  /// Handles `ext.qora.invalidate`.
  Future<developer.ServiceExtensionResponse> invalidateResponse(
    Map<String, String> params,
  ) async {
    final queryKey = params['queryKey'];
    if (queryKey == null || queryKey.isEmpty) {
      return _badRequest('Missing required param: queryKey');
    }
    final ok = await _gateway.invalidate(queryKey);
    return _ok(<String, Object?>{'ok': ok, 'queryKey': queryKey});
  }

  /// Handles `ext.qora.rollbackOptimistic`.
  Future<developer.ServiceExtensionResponse> rollbackResponse(
    Map<String, String> params,
  ) async {
    final queryKey = params['queryKey'];
    if (queryKey == null || queryKey.isEmpty) {
      return _badRequest('Missing required param: queryKey');
    }
    final ok = await _gateway.rollbackOptimistic(queryKey);
    return _ok(<String, Object?>{'ok': ok, 'queryKey': queryKey});
  }

  /// Handles `ext.qora.getCacheSnapshot`.
  Future<developer.ServiceExtensionResponse> snapshotResponse(
    Map<String, String> params,
  ) async {
    final snapshot = await _gateway.getCacheSnapshot();
    return _ok(snapshot.toJson());
  }

  /// Handles `ext.qora.getPayloadChunk` and legacy `ext.qora.getPayload`.
  Future<developer.ServiceExtensionResponse> payloadChunkResponse(
    Map<String, String> params,
  ) async {
    final payloadId = params['payloadId'];
    if (payloadId == null || payloadId.isEmpty) {
      return _badRequest('Missing required param: payloadId');
    }

    final chunkIndex = int.tryParse(
      params['chunkIndex'] ?? params['chunk'] ?? '0',
    );
    if (chunkIndex == null || chunkIndex < 0) {
      return _badRequest('Invalid chunk index');
    }

    final chunk = _lazy.getChunk(payloadId, chunkIndex);
    return _ok(chunk);
  }

  developer.ServiceExtensionResponse _ok(Map<String, Object?> value) {
    return developer.ServiceExtensionResponse.result(jsonEncode(value));
  }

  developer.ServiceExtensionResponse _badRequest(String message) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionErrorMin,
      message,
    );
  }
}

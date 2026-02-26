import 'dart:convert';

import 'package:qora_devtools_extension/qora_devtools_extension.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:test/test.dart';

void main() {
  group('LazyPayloadManager', () {
    test('stores large payload as chunks', () {
      final manager = LazyPayloadManager();
      final large = List<int>.generate(120000, (index) => index % 255);

      final meta = manager.store(<String, Object?>{'values': large});

      expect(meta.hasLargePayload, isTrue);
      expect(meta.payloadId, isNotEmpty);
      expect(meta.totalChunks, greaterThan(1));
    });

    test('returns base64 chunk payload', () {
      final manager = LazyPayloadManager(chunkSize: 32);
      final payload = <String, Object?>{
        'data': List<int>.generate(500, (index) => index)
      };

      final meta = manager.store(payload);
      final chunk = manager.getChunk(meta.payloadId, 0);

      expect(chunk['encoding'], 'base64');
      expect(chunk['totalChunks'], meta.totalChunks);
      expect(chunk['data'], isA<String>());
      expect(
        () => base64.decode(chunk['data'] as String),
        returnsNormally,
      );
    });
  });

  group('VmTracker', () {
    test('emits query fetched event into recent buffer', () {
      final tracker = VmTracker();

      tracker.onQueryFetched('todos', <String, Object?>{'count': 1}, 'success');

      final events = tracker.recentEvents;
      expect(events, hasLength(1));
      expect(events.first, isA<QueryEvent>());
      expect((events.first as QueryEvent).key, 'todos');
    });
  });
}

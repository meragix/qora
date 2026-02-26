import 'package:flutter_test/flutter_test.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

void main() {
  group('EventCodec', () {
    test('decodes query fetched event', () {
      final input = <String, Object?>{
        'eventId': 'evt_1',
        'kind': 'query.fetched',
        'timestampMs': 1,
        'queryKey': 'todos',
        'status': 'success',
        'data': <String, Object?>{'count': 3},
      };

      final event = EventCodec.decode(input);
      expect(event, isA<QueryEvent>());
      expect((event as QueryEvent).key, 'todos');
      expect(event.type, QueryEventType.fetched);
    });

    test('decodes mutation started event', () {
      final input = <String, Object?>{
        'eventId': 'evt_2',
        'kind': 'mutation.started',
        'timestampMs': 2,
        'mutationId': 'm1',
        'queryKey': 'todos',
      };

      final event = EventCodec.decode(input);
      expect(event, isA<MutationEvent>());
      expect((event as MutationEvent).id, 'm1');
      expect(event.type, MutationEventType.started);
    });
  });

  group('CommandCodec', () {
    test('decodes refetch suffix method', () {
      final input = <String, Object?>{
        'method': 'refetch',
        'params': <String, Object?>{'queryKey': 'todos'},
      };

      final command = CommandCodec.decode(input);
      expect(command, isA<RefetchCommand>());
      expect((command as RefetchCommand).queryKey, 'todos');
    });

    test('decodes fully-qualified extension method', () {
      final input = <String, Object?>{
        'method': QoraExtensionMethods.refetch,
        'params': <String, Object?>{'queryKey': 'posts'},
      };

      final command = CommandCodec.decode(input);
      expect(command, isA<RefetchCommand>());
      expect((command as RefetchCommand).queryKey, 'posts');
    });
  });

  group('Snapshots', () {
    test('cache snapshot roundtrip', () {
      final snapshot = CacheSnapshot(
        queries: const <QuerySnapshot>[
          QuerySnapshot(
            key: 'todos',
            status: 'success',
            data: <String, Object?>{'count': 1},
            updatedAtMs: 11,
          ),
        ],
        mutations: const <MutationSnapshot>[
          MutationSnapshot(
            id: 'm1',
            key: 'todos',
            status: 'settled',
            success: true,
            startedAtMs: 10,
            settledAtMs: 12,
          ),
        ],
        emittedAtMs: 99,
      );

      final decoded = CacheSnapshot.fromJson(snapshot.toJson());
      expect(decoded.queries.single.key, 'todos');
      expect(decoded.mutations.single.id, 'm1');
      expect(decoded.emittedAtMs, 99);
    });
  });
}

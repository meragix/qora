import 'dart:async';

import 'package:qora/qora.dart';
import 'package:test/test.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('watchQuery invalidation refetch', () {
    late QoraClient client;

    setUp(() => client = QoraClient());
    tearDown(() => client.dispose());

    test('refetches after invalidate and ends in Success with fresh data',
        () async {
      var calls = 0;
      final states = <QoraState<String>>[];
      final sub = client.watchQuery<String>(
        key: ['k'],
        fetcher: () async => 'v${++calls}',
      ).listen(states.add);

      await _settle();
      expect(calls, 1);

      client.invalidate(['k']);
      await _settle();

      expect(calls, 2);
      expect(states.last, isA<Success<String>>());
      expect((states.last as Success<String>).data, 'v2');
      await sub.cancel();
    });

    test('a fetcher failing synchronously after invalidate runs exactly once',
        () async {
      var calls = 0;
      var fail = false;
      final sub = client.watchQuery<String>(
        key: ['k'],
        fetcher: () async {
          calls++;
          if (fail) throw StateError('no token');
          return 'ok';
        },
        options: const QoraOptions(retryCount: 0),
      ).listen((_) {});

      await _settle();
      final before = calls;
      fail = true;
      client.invalidate(['k']);
      await _settle();
      await _settle();

      expect(calls - before, 1, reason: 'no refetch feedback loop');
      expect(client.getQueryState<String>(['k']), isA<Failure<String>>());
      await sub.cancel();
    });

    test('concurrent watchers on the same key trigger a single refetch',
        () async {
      var calls = 0;
      Future<String> fetcher() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 'v$calls';
      }

      final a = client.watchQuery<String>(key: ['k'], fetcher: fetcher);
      final b = client.watchQuery<String>(key: ['k'], fetcher: fetcher);
      final subA = a.listen((_) {});
      final subB = b.listen((_) {});

      await _settle();
      final before = calls;
      client.invalidate(['k']);
      await _settle();

      expect(calls - before, 1);
      await subA.cancel();
      await subB.cancel();
    });

    test('disabled watcher does not refetch on invalidate', () async {
      client.setQueryData<String>(['k'], 'seed');
      var calls = 0;
      final sub = client.watchQuery<String>(
        key: ['k'],
        fetcher: () async => 'v${++calls}',
        options: const QoraOptions(enabled: false),
      ).listen((_) {});

      await _settle();
      client.invalidate(['k']);
      await _settle();

      expect(calls, 0);
      await sub.cancel();
    });

    test('cancelled watcher no longer refetches on invalidate', () async {
      var calls = 0;
      final sub = client.watchQuery<String>(
        key: ['k'],
        fetcher: () async => 'v${++calls}',
      ).listen((_) {});

      await _settle();
      await sub.cancel();
      client.invalidate(['k']);
      await _settle();

      expect(calls, 1);
    });

    test('invalidateWhere and invalidateTags refetch active watchers',
        () async {
      var calls = 0;
      final sub = client.watchQuery<String>(
        key: ['posts', 1],
        fetcher: () async => 'v${++calls}',
        options: const QoraOptions(providesTags: [QueryTag('post', '1')]),
      ).listen((_) {});

      await _settle();
      client.invalidateWhere((key) => key.first == 'posts');
      await _settle();
      expect(calls, 2);

      await client.invalidateTags([QueryTag('post')]);
      await _settle();
      expect(calls, 3);
      await sub.cancel();
    });
  });
}

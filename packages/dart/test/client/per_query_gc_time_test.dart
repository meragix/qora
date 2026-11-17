import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:qora/qora.dart';
import 'package:test/test.dart';

const _short = Duration(milliseconds: 10);
const _long = Duration(hours: 1);

QoraClient _client({required Duration defaultGcTime}) {
  final client = QoraClient(
    config: QoraClientConfig(
      defaultOptions: QoraOptions(retryCount: 0, gcTime: defaultGcTime),
    ),
  );
  addTearDown(client.dispose);
  return client;
}

/// Watches [key] with [gcTime], waits for the data, then stops watching.
Future<void> _watchOnce(
  QoraClient client,
  List<Object> key, {
  Duration? gcTime,
}) async {
  final sub = client
      .watchQuery<String>(
        key: key,
        fetcher: () async => 'data',
        options: QoraOptions(gcTime: gcTime),
      )
      .listen((_) {});
  await pumpEventQueue();
  await sub.cancel();
}

bool _isCached(QoraClient client, List<Object> key) =>
    client.cachedKeys.any((k) => k.length == 1 && k.first == key.first);

void main() {
  group('per-query gcTime', () {
    test('a shorter gcTime than the default collects the query sooner',
        () async {
      final client = _client(defaultGcTime: _long);

      await _watchOnce(client, ['a'], gcTime: _short);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(_isCached(client, ['a']), isFalse);
    });

    test('a longer gcTime than the default keeps the query', () async {
      final client = _client(defaultGcTime: _short);

      await _watchOnce(client, ['a'], gcTime: _long);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(_isCached(client, ['a']), isTrue);
    });

    test('a query without gcTime still uses the client default', () async {
      final client = _client(defaultGcTime: _short);

      await _watchOnce(client, ['a']);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(_isCached(client, ['a']), isFalse);
    });

    test('the longest gcTime asked for a key wins', () async {
      final client = _client(defaultGcTime: _short);

      await _watchOnce(client, ['a'], gcTime: _long);
      await _watchOnce(client, ['a'], gcTime: _short);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(_isCached(client, ['a']), isTrue);
    });

    test('gcTime zero collects the query once its last watcher leaves',
        () async {
      final client = _client(defaultGcTime: _long);

      await _watchOnce(client, ['a'], gcTime: Duration.zero);
      await pumpEventQueue();

      expect(_isCached(client, ['a']), isFalse);
    });

    group('lazy eviction', () {
      // A long staleTime: a cache hit returns without fetching, so a second
      // fetcher call proves the expired entry was dropped.
      Future<int> fetchTwice(QoraClient client, Duration gcTime) async {
        var calls = 0;
        final options = QoraOptions(staleTime: _long, gcTime: gcTime);
        Future<String> fetcher() async => 'v${++calls}';

        await client.fetchQuery<String>(
          key: ['a'],
          fetcher: fetcher,
          options: options,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await client.fetchQuery<String>(
          key: ['a'],
          fetcher: fetcher,
          options: options,
        );
        return calls;
      }

      test('drops a query whose own gcTime expired', () async {
        final client = _client(defaultGcTime: _long);
        expect(await fetchTwice(client, _short), 2);
      });

      test('keeps a query whose own gcTime has not expired', () async {
        final client = _client(defaultGcTime: _short);
        expect(await fetchTwice(client, _long), 1);
      });
    });

    test('the sweep collects a short gcTime query next to a long one', () {
      fakeAsync((async) {
        final evicted = <List<dynamic>>[];
        // DateTime.now() is not faked: the long entry expires an hour of real
        // time from now, the 1 µs one by the next sweep.
        final client = QoraClient(
          config: QoraClientConfig(
            onCacheEvict: evicted.add,
            defaultOptions: const QoraOptions(retryCount: 0, gcTime: _long),
          ),
        );

        unawaited(
          client.fetchQuery<String>(key: ['long'], fetcher: () async => 'L'),
        );
        async.flushMicrotasks();
        // The first sweep arms the next one for the long entry's expiry.
        async.elapse(const Duration(minutes: 1));

        unawaited(
          client.fetchQuery<String>(
            key: ['short'],
            fetcher: () async => 'S',
            options: const QoraOptions(gcTime: Duration(microseconds: 1)),
          ),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2));

        expect(evicted, [
          ['short'],
        ]);
        client.dispose();
      });
    });
  });
}

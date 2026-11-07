import 'dart:async';

import 'package:qora/qora.dart';
import 'package:test/test.dart';

/// Fails fast: the retry loop is not what these tests are about.
const _noRetry = QoraOptions(retryCount: 0);

void main() {
  group('QoraClient.prefetch', () {
    late QoraClient client;
    late List<(Object, List<dynamic>)> reported;

    setUp(() {
      reported = [];
      client = QoraClient(
        config: QoraClientConfig(
          onBackgroundFetchError: (error, stackTrace, key) =>
              reported.add((error, key)),
        ),
      );
    });

    tearDown(() => client.dispose());

    test('completes normally when the fetcher throws', () async {
      await expectLater(
        client.prefetch<String>(
          key: ['user', 1],
          fetcher: () async => throw StateError('boom'),
          options: _noRetry,
        ),
        completes,
      );
    });

    test('stores the error in the query state', () async {
      final error = StateError('boom');

      await client.prefetch<String>(
        key: ['user', 1],
        fetcher: () async => throw error,
        options: _noRetry,
      );

      final state = client.getQueryState<String>(['user', 1]);
      expect(state, isA<Failure<String>>());
      expect((state as Failure<String>).error, same(error));
    });

    test('reports the error to onBackgroundFetchError with the key', () async {
      final error = StateError('boom');

      await client.prefetch<String>(
        key: ['user', 1],
        fetcher: () async => throw error,
        options: _noRetry,
      );

      expect(reported, hasLength(1));
      expect(reported.single.$1, same(error));
      expect(reported.single.$2, ['user', 1]);
    });

    test('does not report a cancelled prefetch', () async {
      final token = CancelToken();

      final prefetch = client.prefetch<String>(
        key: ['user', 1],
        fetcher: () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return 'late';
        },
        options: _noRetry,
        cancelToken: token,
      );
      token.cancel();

      await expectLater(prefetch, completes);
      expect(reported, isEmpty);
    });

    test('does not report a prefetch paused while offline', () async {
      final connectivity = _FakeConnectivity(online: false);
      client.attachConnectivityManager(connectivity);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        client.prefetch<String>(
          key: ['user', 1],
          fetcher: () async => 'data',
          options: _noRetry,
        ),
        completes,
      );
      expect(reported, isEmpty);
    });

    test('reports a failure once when two prefetches share the fetch',
        () async {
      var calls = 0;
      final gate = Completer<void>();
      Future<String> fetcher() async {
        calls++;
        await gate.future;
        throw StateError('boom');
      }

      final first = client.prefetch<String>(
        key: ['user', 1],
        fetcher: fetcher,
        options: _noRetry,
      );
      final second = client.prefetch<String>(
        key: ['user', 1],
        fetcher: fetcher,
        options: _noRetry,
      );
      gate.complete();
      await Future.wait([first, second]);

      expect(calls, 1);
      expect(reported, hasLength(1));
    });

    test('does not report a failure delivered to a fetchQuery caller',
        () async {
      final gate = Completer<void>();
      final fetch = client.fetchQuery<String>(
        key: ['user', 1],
        fetcher: () async {
          await gate.future;
          throw StateError('boom');
        },
        options: _noRetry,
      );
      final prefetch = client.prefetch<String>(
        key: ['user', 1],
        fetcher: () async => 'unused',
        options: _noRetry,
      );
      gate.complete();

      await expectLater(fetch, throwsStateError);
      await expectLater(prefetch, completes);
      expect(reported, isEmpty);
    });

    test('a prefetch and a watcher sharing a failing fetch report once',
        () async {
      final gate = Completer<void>();
      var calls = 0;
      Future<String> fetcher() async {
        calls++;
        await gate.future;
        throw StateError('boom');
      }

      final prefetch = client.prefetch<String>(
        key: ['user', 1],
        fetcher: fetcher,
        options: _noRetry,
      );
      // The screen mounts while the prefetch is still in flight; its deferred
      // mount fetch joins the prefetch.
      final sub = client.watchQuery<String>(
        key: ['user', 1],
        fetcher: fetcher,
        options: _noRetry,
      ).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      gate.complete();
      await prefetch;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(calls, 1);
      expect(reported, hasLength(1));
    });

    group('paused offline', () {
      late _FakeConnectivity network;

      setUp(() async {
        // One replay per batch, so a failing replay could stop later ones.
        client.dispose();
        client = QoraClient(
          config: QoraClientConfig(
            onBackgroundFetchError: (error, stackTrace, key) =>
                reported.add((error, key)),
            reconnectStrategy: const ReconnectStrategy(
              maxConcurrent: 1,
              jitter: Duration.zero,
            ),
          ),
        );
        network = _FakeConnectivity(online: false);
        client.attachConnectivityManager(network);
        await Future<void>.delayed(Duration.zero);
      });

      test('fetches on reconnect', () async {
        await client.prefetch<String>(
          key: ['user', 1],
          fetcher: () async => 'Ada',
          options: _noRetry,
        );
        expect(client.getQueryData<String>(['user', 1]), isNull);

        network.set(NetworkStatus.online);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(client.getQueryData<String>(['user', 1]), 'Ada');
        expect(reported, isEmpty);
      });

      test('reports a failure after reconnect once, without crashing',
          () async {
        final error = StateError('after reconnect');
        await client.prefetch<String>(
          key: ['user', 1],
          fetcher: () async => throw error,
          options: _noRetry,
        );

        network.set(NetworkStatus.online);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          client.getQueryState<String>(['user', 1]),
          isA<Failure<String>>(),
        );
        expect(reported, hasLength(1));
        expect(reported.single.$1, same(error));
      });

      test('a failed replay does not stop later batches or mutations',
          () async {
        final sent = <String>[];
        final mutation = MutationController<String, String, void>(
          mutator: (v) async {
            sent.add(v);
            return v;
          },
          options: const MutationOptions(offlineQueue: true),
          isOnline: () => client.isOnline,
          offlineQueue: client.offlineMutationQueue,
        );
        await client.prefetch<String>(
          key: ['a'],
          fetcher: () async => throw StateError('a'),
          options: _noRetry,
        );
        await client.prefetch<String>(
          key: ['b'],
          fetcher: () async => 'b',
          options: _noRetry,
        );
        await mutation.mutate('queued');
        expect(sent, isEmpty);

        network.set(NetworkStatus.online);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(client.getQueryData<String>(['b']), 'b');
        expect(sent, ['queued']);
        mutation.dispose();
      });

      test('a replay joining a fetch started after reconnect reports once',
          () async {
        final gateA = Completer<void>();
        final gateB = Completer<void>();
        await client.prefetch<String>(
          key: ['a'],
          fetcher: () async {
            await gateA.future;
            return 'a';
          },
          options: _noRetry,
        );
        await client.prefetch<String>(
          key: ['b'],
          fetcher: () async => throw StateError('stale replay'),
          options: _noRetry,
        );

        // Batch 1 replays "a" and waits on gateA; "b" waits for batch 2.
        network.set(NetworkStatus.online);
        await Future<void>.delayed(Duration.zero);

        // Meanwhile a new prefetch on "b" starts (and owns) a fetch.
        final fresh = client.prefetch<String>(
          key: ['b'],
          fetcher: () async {
            await gateB.future;
            throw StateError('b');
          },
          options: _noRetry,
        );
        gateA.complete(); // batch 2 replays "b" and joins the fresh fetch
        await Future<void>.delayed(const Duration(milliseconds: 5));
        gateB.complete();
        await fresh;
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(reported.map((r) => r.$2), [
          ['b'],
        ]);
      });

      test('a watcher paused with no cache reports nothing', () async {
        final sub = client.watchQuery<String>(
          key: ['user', 1],
          fetcher: () async => 'Ada',
          options: _noRetry,
        ).listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();

        expect(reported, isEmpty);
      });
    });

    test('caches the data on success', () async {
      await client.prefetch<String>(
        key: ['user', 1],
        fetcher: () async => 'Ada',
      );

      expect(client.getQueryData<String>(['user', 1]), 'Ada');
      expect(reported, isEmpty);
    });

    test('fetchQuery still throws the same error', () async {
      await expectLater(
        client.fetchQuery<String>(
          key: ['user', 1],
          fetcher: () async => throw StateError('boom'),
          options: _noRetry,
        ),
        throwsStateError,
      );
    });
  });
}

class _FakeConnectivity implements ConnectivityManager {
  _FakeConnectivity({required bool online})
      : _status = online ? NetworkStatus.online : NetworkStatus.offline;

  final _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status;

  @override
  NetworkStatus get currentStatus => _status;

  @override
  Stream<NetworkStatus> get statusStream => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  void dispose() => _controller.close();

  void set(NetworkStatus status) {
    _status = status;
    _controller.add(status);
  }
}

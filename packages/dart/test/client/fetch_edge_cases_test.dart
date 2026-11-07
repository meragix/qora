import 'dart:async';

import 'package:qora/qora.dart';
import 'package:test/test.dart';

const _noRetry = QoraOptions(retryCount: 0);

void main() {
  group('onBackgroundFetchError that throws', () {
    test('does not make prefetch throw; the error reaches the Zone', () async {
      final zoneErrors = <Object>[];
      await runZonedGuarded(
        () async {
          final client = QoraClient(
            config: QoraClientConfig(
              onBackgroundFetchError: (_, __, ___) =>
                  throw StateError('callback bug'),
            ),
          );

          await expectLater(
            client.prefetch<String>(
              key: ['user', 1],
              fetcher: () async => throw StateError('fetch failed'),
              options: _noRetry,
            ),
            completes,
          );
          client.dispose();
        },
        (error, _) => zoneErrors.add(error),
      );
      await pumpEventQueue();

      expect(zoneErrors, hasLength(1));
      expect((zoneErrors.single as StateError).message, 'callback bug');
    });
  });

  group('a fetch superseded after invalidate()', () {
    late QoraClient client;

    setUp(() => client = QoraClient());
    tearDown(() => client.dispose());

    test('keeps the newer fetch deduplicated', () async {
      final gateA = Completer<void>();
      final gateB = Completer<void>();
      var calls = 0;
      Future<String> fetcher() async {
        final n = ++calls;
        await (n == 1 ? gateA.future : gateB.future);
        return 'v$n';
      }

      final a = client.fetchQuery<String>(
        key: ['k'],
        fetcher: fetcher,
        options: _noRetry,
      );
      await pumpEventQueue();
      client.invalidate(['k']);
      final b = client.fetchQuery<String>(
        key: ['k'],
        fetcher: fetcher,
        options: _noRetry,
      );
      await pumpEventQueue();

      gateA.complete(); // the old fetch settles while the new one runs
      await a;
      final c = client.fetchQuery<String>(
        key: ['k'],
        fetcher: fetcher,
        options: _noRetry,
      );
      gateB.complete();
      await Future.wait([b, c]);

      expect(calls, 2, reason: 'the third call must join the newer fetch');
      expect(client.isFetchingCount, 0);
    });

    test('does not overwrite the newer result with its own', () async {
      final gateA = Completer<void>();
      var calls = 0;
      Future<String> fetcher() async {
        final n = ++calls;
        if (n == 1) await gateA.future;
        return 'v$n';
      }

      final a = client.fetchQuery<String>(
        key: ['k'],
        fetcher: fetcher,
        options: _noRetry,
      );
      await pumpEventQueue();
      client.invalidate(['k']);
      await client.fetchQuery<String>(
        key: ['k'],
        fetcher: fetcher,
        options: _noRetry,
      );
      expect(client.getQueryData<String>(['k']), 'v2');

      gateA.complete(); // the old, slower fetch settles last
      expect(await a, 'v1', reason: 'its own caller still gets its result');

      expect(client.getQueryData<String>(['k']), 'v2');
    });

    test('still writes its result when no newer fetch started', () async {
      final gate = Completer<void>();
      final a = client.fetchQuery<String>(
        key: ['k'],
        fetcher: () async {
          await gate.future;
          return 'v1';
        },
        options: _noRetry,
      );
      await pumpEventQueue();
      client.invalidate(['k']);

      gate.complete();
      await a;

      expect(client.getQueryData<String>(['k']), 'v1');
      expect(client.isFetchingCount, 0);
    });
  });

  group('a newer fetch that is cancelled', () {
    late QoraClient client;

    setUp(() => client = QoraClient());
    tearDown(() => client.dispose());

    Future<void> run({required bool throwFromFetcher}) async {
      final gateA = Completer<void>();
      final gateB = Completer<void>();
      final token = CancelToken();

      final a = client.fetchQuery<String>(
        key: ['k'],
        fetcher: () async {
          await gateA.future;
          return 'A';
        },
        options: _noRetry,
      );
      await pumpEventQueue();
      client.invalidate(['k']);
      final b = client.fetchQuery<String>(
        key: ['k'],
        fetcher: () async {
          await gateB.future;
          if (throwFromFetcher) throw const QoraCancelException('inner');
          return 'B';
        },
        options: _noRetry,
        cancelToken: throwFromFetcher ? null : token,
      );
      await pumpEventQueue();

      if (!throwFromFetcher) token.cancel();
      gateB.complete();
      await expectLater(b, throwsA(isA<QoraCancelException>()));

      gateA.complete();
      expect(await a, 'A');
    }

    test('hands the state back to the fetch it superseded (token)', () async {
      await run(throwFromFetcher: false);

      final state = client.getQueryState<String>(['k']);
      expect(state, isA<Success<String>>());
      expect((state as Success<String>).data, 'A');
    });

    test('hands the state back to the fetch it superseded (fetcher)', () async {
      await run(throwFromFetcher: true);

      expect(client.getQueryData<String>(['k']), 'A');
      expect(client.isFetchingCount, 0);
    });
  });

  group('a fetch whose entry was removed', () {
    test('leaves fetch status and persistence to the newer fetch', () async {
      final client = _RecordingClient();
      addTearDown(client.dispose);
      final gateA = Completer<void>();
      final gateB = Completer<void>();

      final a = client.fetchQuery<String>(
        key: ['k'],
        fetcher: () async {
          await gateA.future;
          return 'A';
        },
        options: _noRetry,
      );
      await pumpEventQueue();
      client.removeQuery(['k']);
      final b = client.fetchQuery<String>(
        key: ['k'],
        fetcher: () async {
          await gateB.future;
          return 'B';
        },
        options: _noRetry,
      );
      final statuses = <FetchStatus>[];
      final sub = client.watchFetchStatus(['k']).listen(statuses.add);
      await pumpEventQueue();

      gateA.complete(); // the removed entry's fetch settles first
      expect(await a, 'A');
      await pumpEventQueue();
      expect(
        statuses,
        isNot(contains(FetchStatus.idle)),
        reason: 'the newer fetch is still running',
      );

      gateB.complete();
      await b;
      await pumpEventQueue();
      await sub.cancel();

      expect(client.getQueryData<String>(['k']), 'B');
      expect(client.persisted, ['B'], reason: 'A must not be persisted');
    });
  });

  group('reconnect replay with a throwing callback', () {
    test('runs every batch', () async {
      final zoneErrors = <Object>[];
      late QoraClient client;
      final network = _FakeConnectivity();
      await runZonedGuarded(
        () async {
          client = QoraClient(
            config: QoraClientConfig(
              onBackgroundFetchError: (_, __, ___) =>
                  throw StateError('callback bug'),
              reconnectStrategy: const ReconnectStrategy(
                maxConcurrent: 1,
                jitter: Duration.zero,
              ),
            ),
          );
          client.attachConnectivityManager(network);
          await pumpEventQueue();
          for (final k in ['a', 'b']) {
            await client.prefetch<String>(
              key: [k],
              fetcher: () async => throw StateError(k),
              options: _noRetry,
            );
          }
          await client.prefetch<String>(
            key: ['c'],
            fetcher: () async => 'c',
            options: _noRetry,
          );

          network.set(NetworkStatus.online);
          await pumpEventQueue();
        },
        (error, _) => zoneErrors.add(error),
      );
      await pumpEventQueue();

      expect(client.getQueryData<String>(['c']), 'c');
      expect(zoneErrors, hasLength(2));
      client.dispose();
    });
  });

  group('a fetcher that throws QoraCancelException', () {
    late QoraClient client;

    setUp(() => client = QoraClient());
    tearDown(() => client.dispose());

    test('releases the key and restores the previous state', () async {
      await expectLater(
        client.fetchQuery<String>(
          key: ['k'],
          fetcher: () async => throw const QoraCancelException('inner'),
          options: _noRetry,
        ),
        throwsA(isA<QoraCancelException>()),
      );

      expect(client.isFetchingCount, 0);
      expect(client.getQueryState<String>(['k']), isA<Initial<String>>());

      // The key is not stuck: a new fetch runs instead of joining a dead one.
      var calls = 0;
      final data = await client.fetchQuery<String>(
        key: ['k'],
        fetcher: () async {
          calls++;
          return 'new';
        },
        options: _noRetry,
      );
      expect(calls, 1);
      expect(data, 'new');
    });
  });
}

class _RecordingClient extends QoraClient {
  final persisted = <Object?>[];

  @override
  void onFetchSuccess<T>(List<dynamic> key, T data) => persisted.add(data);
}

class _FakeConnectivity implements ConnectivityManager {
  final _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status = NetworkStatus.offline;

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

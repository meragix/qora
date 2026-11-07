import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:meta/meta.dart';
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

    test('lets the fetch it superseded write its result (token)', () async {
      await run(throwFromFetcher: false);

      final state = client.getQueryState<String>(['k']);
      expect(state, isA<Success<String>>());
      expect((state as Success<String>).data, 'A');
    });

    test('lets the fetch it superseded write its result (fetcher)', () async {
      await run(throwFromFetcher: true);

      expect(client.getQueryData<String>(['k']), 'A');
      expect(client.isFetchingCount, 0);
    });

    for (final cancelMiddleFirst in [true, false]) {
      test(
          'in a chain of three, the oldest still writes '
          '(middle cancelled ${cancelMiddleFirst ? 'first' : 'last'})',
          () async {
        final gates = List.generate(3, (_) => Completer<void>());
        final tokens = [CancelToken(), CancelToken()];
        Future<String> start(int i) {
          return client.fetchQuery<String>(
            key: ['k'],
            fetcher: () async {
              await gates[i].future;
              return 'v$i';
            },
            options: _noRetry,
            cancelToken: i == 0 ? null : tokens[i - 1],
          );
        }

        final a = start(0);
        await pumpEventQueue();
        client.invalidate(['k']);
        final b = start(1);
        await pumpEventQueue();
        client.invalidate(['k']);
        final c = start(2);
        await pumpEventQueue();

        Future<void> cancel(int i, Future<String> fetch) async {
          tokens[i - 1].cancel();
          gates[i].complete();
          await expectLater(fetch, throwsA(isA<QoraCancelException>()));
        }

        if (cancelMiddleFirst) {
          await cancel(1, b);
          await cancel(2, c);
        } else {
          await cancel(2, c);
          await cancel(1, b);
        }
        gates[0].complete();
        expect(await a, 'v0');

        expect(client.getQueryData<String>(['k']), 'v0');
        expect(client.isFetchingCount, 0);
      });
    }

    test('keeps the result of a superseded fetch that settled first', () async {
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
          return 'B';
        },
        options: _noRetry,
        cancelToken: token,
      );
      await pumpEventQueue();

      gateA.complete(); // no newer fetch has written: A's result is shown
      await a;
      expect(client.getQueryData<String>(['k']), 'A');

      token.cancel();
      gateB.complete();
      await expectLater(b, throwsA(isA<QoraCancelException>()));

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

  group('eviction of a query with a fetch in flight', () {
    Future<String> gated(Completer<void> gate, String value) async {
      await gate.future;
      return value;
    }

    test('LRU skips it, and catches up once the fetch settled', () async {
      final evicted = <List<dynamic>>[];
      final client = _RecordingClient(
        config: QoraClientConfig(maxCacheSize: 1, onCacheEvict: evicted.add),
      );
      addTearDown(client.dispose);
      final gate = Completer<void>();

      final a = client.prefetch<String>(
        key: ['a'],
        fetcher: () => gated(gate, 'A'),
        options: _noRetry,
      );
      await pumpEventQueue();
      await client.prefetch<String>(
        key: ['b'],
        fetcher: () async => 'B',
        options: _noRetry,
      );
      expect(evicted, isEmpty, reason: "['a'] is still fetching");

      gate.complete();
      await a;
      expect(client.getQueryData<String>(['a']), 'A');
      expect(client.persisted, ['B', 'A']);
      expect(client.isFetchingCount, 0);

      // The next insertion brings the cache back under maxCacheSize.
      await client.prefetch<String>(
        key: ['c'],
        fetcher: () async => 'C',
        options: _noRetry,
      );
      expect(client.cachedKeys, [
        ['c'],
      ]);
    });

    test('LRU skips it when the fetch fails, and the key is released',
        () async {
      final client = QoraClient(
        config: const QoraClientConfig(maxCacheSize: 1),
      );
      addTearDown(client.dispose);
      final gate = Completer<void>();

      final a = client.fetchQuery<String>(
        key: ['a'],
        fetcher: () async {
          await gate.future;
          throw StateError('boom');
        },
        options: _noRetry,
      );
      await pumpEventQueue();
      await client.prefetch<String>(
        key: ['b'],
        fetcher: () async => 'B',
        options: _noRetry,
      );

      gate.complete();
      await expectLater(a, throwsStateError);
      expect(client.getQueryState<String>(['a']), isA<Failure<String>>());
      expect(client.isFetchingCount, 0);

      var calls = 0;
      await client.fetchQuery<String>(
        key: ['a'],
        fetcher: () async {
          calls++;
          return 'retry';
        },
        options: _noRetry,
      );
      expect(calls, 1);
    });

    test('the GC timer waits for the fetch, then collects the query', () async {
      // The GC timer reads the client defaults: the entry has no options of
      // its own until a fetch succeeds.
      final client = QoraClient(
        config: const QoraClientConfig(
          defaultOptions: QoraOptions(gcTime: Duration(milliseconds: 10)),
        ),
      );
      addTearDown(client.dispose);
      final gate = Completer<void>();

      final sub = client.watchQuery<String>(
        key: ['a'],
        fetcher: () => gated(gate, 'A'),
        options: _noRetry,
      ).listen((_) {});
      await pumpEventQueue();
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        client.cachedKeys,
        anyElement(equals(['a'])),
        reason: 'still fetching',
      );

      gate.complete();
      await pumpEventQueue();
      expect(client.getQueryData<String>(['a']), 'A');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.cachedKeys, isNot(anyElement(equals(['a']))));
    });
  });

  group('lazy eviction', () {
    // A long staleTime: a cache hit returns the data without fetching, so a
    // second fetcher call proves the expired entry was dropped.
    const opts = QoraOptions(
      retryCount: 0,
      staleTime: Duration(hours: 1),
      gcTime: Duration(milliseconds: 10),
    );

    test('drops an expired, inactive query on its next access', () async {
      final evicted = <List<dynamic>>[];
      // The background sweep starts with a 1-minute heartbeat, so only the
      // lazy check can drop the entry within this test.
      final client = QoraClient(
        config: QoraClientConfig(
          defaultOptions: opts,
          onCacheEvict: evicted.add,
        ),
      );
      addTearDown(client.dispose);
      var calls = 0;
      Future<String> fetcher() async => 'v${++calls}';

      await client.fetchQuery<String>(key: ['a'], fetcher: fetcher);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final data = await client.fetchQuery<String>(
        key: ['a'],
        fetcher: fetcher,
      );

      expect(evicted, [
        ['a'],
      ]);
      expect(calls, 2);
      expect(data, 'v2');
    });

    test('keeps a query whose fetch is still running', () async {
      final client = QoraClient(
        config: const QoraClientConfig(defaultOptions: opts),
      );
      addTearDown(client.dispose);
      final gate = Completer<void>();
      var calls = 0;
      Future<String> fetcher() async {
        calls++;
        await gate.future;
        return 'A';
      }

      final first = client.fetchQuery<String>(key: ['a'], fetcher: fetcher);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final second = client.fetchQuery<String>(key: ['a'], fetcher: fetcher);
      gate.complete();

      expect(await Future.wait([first, second]), ['A', 'A']);
      expect(calls, 1, reason: 'the second call joins the running fetch');
      expect(client.getQueryData<String>(['a']), 'A');
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

  group('a fetch whose error handling throws', () {
    for (final viaMapper in [false, true]) {
      final name = viaMapper ? 'errorMapper' : 'transformError';
      test('a throwing $name fails the fetch and releases the key', () async {
        final client = QoraClient(
          config: QoraClientConfig(
            errorMapper:
                viaMapper ? (_, __) => throw StateError('mapper bug') : null,
          ),
        );
        addTearDown(client.dispose);
        final options = viaMapper
            ? _noRetry
            : QoraOptions(
                retryCount: 0,
                transformError: (_) => throw StateError('mapper bug'),
              );

        await expectLater(
          client.fetchQuery<String>(
            key: ['k'],
            fetcher: () async => throw Exception('network'),
            options: options,
          ),
          throwsA(isA<StateError>()),
        );

        expect(client.isFetchingCount, 0);
        final state = client.getQueryState<String>(['k']);
        expect(state, isA<Failure<String>>());
        final error = (state as Failure<String>).error as StateError;
        expect(error.message, 'mapper bug');

        var calls = 0;
        await client.fetchQuery<String>(
          key: ['k'],
          fetcher: () async {
            calls++;
            return 'ok';
          },
          options: _noRetry,
        );
        expect(calls, 1, reason: 'the key must not stay on the dead fetch');
      });
    }

    test('a throwing structural share writes Failure, not a stuck Loading',
        () async {
      final client = QoraClient();
      addTearDown(client.dispose);
      var n = 0;
      Future<_Exploding> fetcher() async => _Exploding(++n);

      await client.fetchQuery<_Exploding>(
        key: ['k'],
        fetcher: fetcher,
        options: _noRetry,
      );
      client.invalidate(['k']);
      await expectLater(
        client.fetchQuery<_Exploding>(
          key: ['k'],
          fetcher: fetcher,
          options: _noRetry,
        ),
        throwsStateError,
      );

      final state = client.getQueryState<_Exploding>(['k']);
      expect(state, isA<Failure<_Exploding>>());
      expect(client.isFetchingCount, 0);
    });
  });

  group('a newer fetch that fails after a superseded one wrote', () {
    for (final keep in [true, false]) {
      test('keeps the data on screen (keepPreviousData: $keep)', () async {
        final client = QoraClient();
        addTearDown(client.dispose);
        final options = QoraOptions(retryCount: 0, keepPreviousData: keep);
        final gateA = Completer<void>();
        final gateB = Completer<void>();

        final a = client.fetchQuery<String>(
          key: ['k'],
          fetcher: () async {
            await gateA.future;
            return 'A';
          },
          options: options,
        );
        await pumpEventQueue();
        client.invalidate(['k']);
        final b = client.fetchQuery<String>(
          key: ['k'],
          fetcher: () async {
            await gateB.future;
            throw StateError('B failed');
          },
          options: options,
        );
        await pumpEventQueue();

        gateA.complete();
        expect(await a, 'A');
        gateB.complete();
        await expectLater(b, throwsStateError);

        final state = client.getQueryState<String>(['k']);
        if (keep) {
          expect(state, isA<Success<String>>());
        } else {
          expect(state, isA<Failure<String>>());
        }
        expect(state.dataOrNull, 'A');
      });
    }
  });

  group('offline and eviction', () {
    test('no idle status while a fetch for the key is paused', () async {
      final client = QoraClient();
      addTearDown(client.dispose);
      final network = _FakeConnectivity();
      client.attachConnectivityManager(network);
      network.set(NetworkStatus.online);
      await pumpEventQueue();
      final statuses = <FetchStatus>[];
      final sub = client.watchFetchStatus(['k']).listen(statuses.add);
      final gate = Completer<void>();

      final a = client.fetchQuery<String>(
        key: ['k'],
        fetcher: () async {
          await gate.future;
          return 'A';
        },
        options: _noRetry,
      );
      await pumpEventQueue();
      network.set(NetworkStatus.offline);
      await pumpEventQueue();
      client.invalidate(['k']);
      await client.prefetch<String>(
        key: ['k'],
        fetcher: () async => 'B',
        options: _noRetry,
      ); // paused
      gate.complete(); // the old fetch settles while the new one is paused
      await a;
      await pumpEventQueue();
      await sub.cancel();

      expect(statuses.last, FetchStatus.paused);
    });

    test('a query paused offline is not evicted, and GC runs after replay',
        () async {
      final evicted = <List<dynamic>>[];
      final client = QoraClient(
        config: QoraClientConfig(
          maxCacheSize: 1,
          onCacheEvict: evicted.add,
          defaultOptions: const QoraOptions(gcTime: Duration(milliseconds: 10)),
        ),
      );
      addTearDown(client.dispose);
      final network = _FakeConnectivity(); // starts offline
      client.attachConnectivityManager(network);
      await pumpEventQueue();

      final sub = client.watchQuery<String>(
        key: ['a'],
        fetcher: () async => 'A',
        options: _noRetry,
      ).listen((_) {});
      await pumpEventQueue();
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 40)); // GC fires
      await client.prefetch<String>(
        key: ['b'],
        fetcher: () async => 'B',
        options: _noRetry,
      ); // LRU pressure
      expect(evicted, isEmpty, reason: "['a'] is paused, not idle");

      network.set(NetworkStatus.online);
      await pumpEventQueue();
      expect(client.getQueryData<String>(['a']), 'A');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(evicted, anyElement(equals(['a'])));
    });

    test('a replay queued behind a running batch fills the live entry',
        () async {
      final client = QoraClient(
        config: const QoraClientConfig(
          maxCacheSize: 2,
          reconnectStrategy: ReconnectStrategy(
            maxConcurrent: 1,
            jitter: Duration.zero,
          ),
        ),
      );
      addTearDown(client.dispose);
      final network = _FakeConnectivity(); // starts offline
      client.attachConnectivityManager(network);
      await pumpEventQueue();
      final gateA = Completer<void>();
      final gateB = Completer<void>();
      var bCalls = 0;
      Future<String> fetchB() async {
        bCalls++;
        await gateB.future;
        return 'B';
      }

      await client.prefetch<String>(
        key: ['a'],
        fetcher: () async {
          await gateA.future;
          return 'A';
        },
        options: _noRetry,
      );
      await client.prefetch<String>(
        key: ['b'],
        fetcher: fetchB,
        options: _noRetry,
      );

      network.set(NetworkStatus.online);
      await pumpEventQueue(); // batch 1 runs ['a']; ['b'] waits, unpaused
      await client.prefetch<String>(
        key: ['c'],
        fetcher: () async => 'C',
        options: _noRetry,
      ); // LRU evicts ['b']
      expect(client.cachedKeys, isNot(anyElement(equals(['b']))));

      gateA.complete(); // batch 2 replays ['b']
      await pumpEventQueue();
      final states = <QoraState<String>>[];
      final sub = client.watchQuery<String>(
        key: ['b'],
        fetcher: fetchB,
        options: _noRetry,
      ).listen(states.add);
      await pumpEventQueue();
      gateB.complete();
      await pumpEventQueue();
      await sub.cancel();

      expect(bCalls, 1, reason: 'the watcher joins the replay');
      expect(states.last, isA<Success<String>>());
      expect(client.getQueryData<String>(['b']), 'B');
    });

    test('gcTime zero keeps a hydrated entry for the fetch that reads it',
        () async {
      final client = QoraClient(
        config: const QoraClientConfig(
          defaultOptions: QoraOptions(gcTime: Duration.zero),
        ),
      );
      addTearDown(client.dispose);
      client.queueHydration(['a'], 'hydrated', updatedAt: DateTime(2000));

      final data = await client.fetchQuery<String>(
        key: ['a'],
        fetcher: () async => 'network',
        options: _noRetry,
      );

      // Stale hydrated data is served at once and revalidated in the
      // background, on the entry the cache holds.
      expect(data, 'hydrated');
      await pumpEventQueue();
      expect(client.getQueryData<String>(['a']), 'network');
    });

    test('the sweep skips a query with a fetch in flight, without spinning',
        () {
      fakeAsync((async) {
        var timers = 0;
        runZoned(
          () {
            final evicted = <List<dynamic>>[];
            // DateTime.now() is not faked: a 1 µs gcTime makes the entry
            // expire in real time by the first sweep, a fake minute later.
            final client = QoraClient(
              config: QoraClientConfig(
                onCacheEvict: evicted.add,
                defaultOptions: const QoraOptions(
                  retryCount: 0,
                  gcTime: Duration(microseconds: 1),
                ),
              ),
            );
            final gate = Completer<void>();
            unawaited(
              client.fetchQuery<String>(
                key: ['a'],
                fetcher: () async {
                  await gate.future;
                  return 'A';
                },
              ),
            );
            async.flushMicrotasks();

            async.elapse(const Duration(minutes: 2));
            expect(evicted, isEmpty, reason: 'its fetch is still running');
            expect(timers, lessThan(10), reason: 'no zero-delay re-arm loop');

            gate.complete();
            async.flushMicrotasks();
            async.elapse(const Duration(minutes: 2));
            expect(evicted, [
              ['a'],
            ]);
            client.dispose();
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              if (++timers > 1000) throw StateError('timer spin');
              return parent.createTimer(zone, duration, callback);
            },
          ),
        );
      });
    });
  });
}

class _RecordingClient extends QoraClient {
  _RecordingClient({super.config});

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

/// A model whose `==` throws, to make structural sharing fail.
@immutable
class _Exploding {
  _Exploding(this.id);

  final int id;

  @override
  bool operator ==(Object other) => throw StateError('== bug');

  @override
  int get hashCode => id;
}

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

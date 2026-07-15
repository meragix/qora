import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/config/qora_options.dart';
import 'package:qora/src/key/qora_key.dart';
import 'package:qora/src/state/qora_state.dart';
import 'package:test/test.dart';

void main() {
  group('QoraClient', () {
    late QoraClient client;

    setUp(() {
      client = QoraClient();
    });

    tearDown(() {
      client.clear();
    });

    test('fetchQuery returns data', () async {
      final data = await client.fetchQuery(
        key: QoraKey(['test']),
        fetcher: () async => 'Hello',
      );

      expect(data, 'Hello');
    });

    test('fetchQuery uses cache for fresh data', () async {
      var callCount = 0;

      final key = QoraKey(['test']);

      Future<String> fetcher() async {
        callCount++;
        return 'Data';
      }

      // Premier appel
      await client.fetchQuery<String>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(staleTime: Duration(seconds: 10)),
      );

      // Deuxième appel (doit utiliser le cache)
      await client.fetchQuery<String>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(staleTime: Duration(seconds: 10)),
      );

      expect(callCount, 1); // ✅ Un seul fetch
    });

    test('stale-while-revalidate returns stale data immediately', () async {
      final key = QoraKey(['test']);

      // Premier fetch
      await client.fetchQuery<String>(
        key: key,
        fetcher: () async => 'Old',
        options: const QoraOptions(staleTime: Duration.zero),
      );

      // Attendre pour que les données soient stale
      await Future.delayed(const Duration(milliseconds: 10), () {});

      // Deuxième fetch avec données stale
      final data = await client.fetchQuery<String>(
        key: key,
        fetcher: () async {
          await Future.delayed(const Duration(milliseconds: 100), () {});
          return 'New';
        },
        options: const QoraOptions(staleTime: Duration.zero),
      );

      // Doit retourner immédiatement les anciennes données
      expect(data, 'Old');

      // Attendre le refetch en arrière-plan
      await Future.delayed(const Duration(milliseconds: 150), () {});

      // Maintenant les nouvelles données sont en cache
      final newData = client.getQueryData<String>(key);
      expect(newData, 'New');
    });

    // test('invalidateQueries with prefix', () {
    //   client.setQueryData(QoraKey(['users', 1]), (_) => 'User 1');
    //   client.setQueryData(QoraKey(['users', 2]), (_) => 'User 2');
    //   client.setQueryData(QoraKey(['posts', 1]), (_) => 'Post 1');

    //   client.invalidateQueries(prefix: ['users']);

    //   final user1 = client._cache[QoraKey(['users', 1])];
    //   final user2 = client._cache[QoraKey(['users', 2])];
    //   final post1 = client._cache[QoraKey(['posts', 1])];

    //   expect(user1?.isInvalidated, true);
    //   expect(user2?.isInvalidated, true);
    //   expect(post1?.isInvalidated, false);
    // });

    test('Deep equality for keys', () {
      final key1 = QoraKey(['users', 1, 'posts']);
      final key2 = QoraKey(['users', 1, 'posts']);
      final key3 = QoraKey(['users', 2, 'posts']);

      expect(key1 == key2, true);
      expect(key1 == key3, false);

      // Test avec des maps
      final key4 = QoraKey([
        'filter',
        {'status': 'active'},
      ]);
      final key5 = QoraKey([
        'filter',
        {'status': 'active'},
      ]);

      expect(key4 == key5, true);
    });

    // ── RetryCondition ──────────────────────────────────────────────────

    test('retryCondition returning false skips retries', () async {
      var attempts = 0;

      await expectLater(
        client.fetchQuery<String>(
          key: QoraKey(['retry-condition-skip']),
          fetcher: () async {
            attempts++;
            throw Exception('persistent error');
          },
          options: const QoraOptions(
            retryCount: 3,
            retryDelay: Duration(milliseconds: 1),
            retryCondition: null, // default — will retry all
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(attempts, 4); // 1 initial + 3 retries

      attempts = 0;

      await expectLater(
        client.fetchQuery<String>(
          key: QoraKey(['retry-condition-skip-2']),
          fetcher: () async {
            attempts++;
            throw Exception('no retry');
          },
          options: QoraOptions(
            retryCount: 3,
            retryDelay: const Duration(milliseconds: 1),
            retryCondition: (error, attempt) => false,
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(attempts, 1); // only initial attempt, no retries
    });

    test('retryCondition returning true allows retries', () async {
      var attempts = 0;

      await expectLater(
        client.fetchQuery<String>(
          key: QoraKey(['retry-condition-allow']),
          fetcher: () async {
            attempts++;
            throw Exception('retry me');
          },
          options: QoraOptions(
            retryCount: 2,
            retryDelay: const Duration(milliseconds: 1),
            retryCondition: (error, attempt) => true,
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(attempts, 3); // 1 initial + 2 retries
    });

    test('retryCondition with selective error filtering', () async {
      var attempts = 0;

      await expectLater(
        client.fetchQuery<String>(
          key: QoraKey(['retry-condition-selective']),
          fetcher: () async {
            attempts++;
            throw ArgumentError('bad request');
          },
          options: QoraOptions(
            retryCount: 3,
            retryDelay: const Duration(milliseconds: 1),
            // Only retry FormatException — not ArgumentError
            retryCondition: (error, attempt) => error is FormatException,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        attempts,
        1,
      ); // ArgumentError does not match FormatException → skip retry
    });
  });

  group('mutate', () {
    late QoraClient client;

    setUp(() {
      client = QoraClient();
    });

    tearDown(() {
      client.clear();
    });

    test('writes data to cache and triggers stream update', () async {
      final states = <QoraState<String>>[];
      final sub = client.watchState<String>(['key']).listen(states.add);

      client.mutate(['key'], 'hello');

      await Future<void>.delayed(Duration.zero);
      expect(states.isNotEmpty, isTrue);
      expect(states.first, isA<Success<String>>());
      expect((states.first as Success<String>).data, 'hello');
      expect(client.getQueryData<String>(['key']), 'hello');

      await sub.cancel();
    });

    test('mutate is an alias for setQueryData', () {
      client.mutate(['test'], 'value');
      expect(client.getQueryData<String>(['test']), 'value');
    });

    test('mutate non-existent key creates a new entry', () {
      client.mutate(['new'], 'data');
      final state = client.getQueryState<String>(['new']);
      expect(state, isA<Success<String>>());
      expect((state as Success<String>).data, 'data');
    });

    test('mutate updates multiple subscribers', () async {
      final s1 = <QoraState<String>>[];
      final s2 = <QoraState<String>>[];
      final sub1 = client.watchState<String>(['shared']).listen(s1.add);
      final sub2 = client.watchState<String>(['shared']).listen(s2.add);

      client.mutate(['shared'], 'updated');

      await Future<void>.delayed(Duration.zero);
      expect((s1.first as Success<String>).data, 'updated');
      expect((s2.first as Success<String>).data, 'updated');

      await sub1.cancel();
      await sub2.cancel();
    });
  });
}

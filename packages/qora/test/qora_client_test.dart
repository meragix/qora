import 'package:qora/qora.dart';
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
  });
}

import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/config/qora_options.dart';
import 'package:qora/src/infinite/infinite_data.dart';
import 'package:qora/src/key/qora_key.dart';
import 'package:qora/src/utils/structural_sharing.dart';
import 'package:test/test.dart';

void main() {
  group('structuralShare', () {
    test('identical objects return old reference', () {
      final list = [1, 2, 3];
      expect(identical(structuralShare(list, list), list), isTrue);
    });

    test('deeply equal maps return old reference', () {
      final a = {'name': 'Alice', 'age': 30};
      final b = {'name': 'Alice', 'age': 30};
      expect(identical(structuralShare(a, b), a), isTrue);
    });

    test('different maps return new reference', () {
      final a = {'name': 'Alice', 'age': 30};
      final b = {'name': 'Alice', 'age': 31};
      expect(identical(structuralShare(a, b), a), isFalse);
    });

    test('deeply equal nested maps return old reference', () {
      final a = {
        'user': {
          'name': 'Alice',
          'roles': ['admin'],
        },
      };
      final b = {
        'user': {
          'name': 'Alice',
          'roles': ['admin'],
        },
      };
      expect(identical(structuralShare(a, b), a), isTrue);
    });

    test('deeply equal lists return old reference', () {
      final a = [1, 2, 3];
      final b = [1, 2, 3];
      expect(identical(structuralShare(a, b), a), isTrue);
    });

    test('different lists return new reference', () {
      final a = [1, 2, 3];
      final b = [1, 2, 4];
      expect(identical(structuralShare(a, b), a), isFalse);
    });

    test('deeply equal nested lists return old reference', () {
      final a = [
        [1, 2],
        [3, 4],
      ];
      final b = [
        [1, 2],
        [3, 4],
      ];
      expect(identical(structuralShare(a, b), a), isTrue);
    });

    test('equal sets return old reference', () {
      final a = {1, 2, 3};
      final b = {1, 2, 3};
      expect(identical(structuralShare(a, b), a), isTrue);
    });

    test('different sets return new reference', () {
      final a = {1, 2, 3};
      final b = {1, 2, 4};
      expect(identical(structuralShare(a, b), a), isFalse);
    });

    test('primitives use equality', () {
      expect(structuralShare('hello', 'hello'), 'hello');
      expect(structuralShare(42, 42), 42);
      expect(structuralShare(3.14, 3.14), 3.14);
      expect(structuralShare(true, true), isTrue);
    });

    test('different primitives return new value', () {
      expect(structuralShare('hello', 'world'), 'world');
      expect(structuralShare(42, 43), 43);
    });

    test('maps with different lengths return new', () {
      final a = {'a': 1};
      final b = {'a': 1, 'b': 2};
      expect(identical(structuralShare(a, b), a), isFalse);
    });

    test('maps with different keys return new', () {
      final a = {'a': 1};
      final b = {'b': 1};
      expect(identical(structuralShare(a, b), a), isFalse);
    });

    test('null old data returns new data', () {
      final b = [1, 2, 3];
      expect(structuralShare<Object?>(null, b), same(b));
    });

    test('null new data returns null', () {
      expect(structuralShare<Object?>('hello', null), isNull);
    });

    test('different types return new', () {
      final a = <Object?>[1, 2];
      final b = <Object?>{1, 2};
      expect(identical(structuralShare<Object?>(a, b), a), isFalse);
    });
  });

  group('QoraClient structural sharing', () {
    late QoraClient client;

    setUp(() {
      client = QoraClient();
    });

    tearDown(() {
      client.clear();
    });

    test('fetchQuery preserves reference for unchanged data', () async {
      // ignore: unused_local_variable
      var callCount = 0;
      final key = QoraKey(['test']);

      Future<Map<String, dynamic>> fetcher() async {
        callCount++;
        return {'name': 'Alice', 'age': 30};
      }

      // First fetch populates cache.
      await client.fetchQuery<Map<String, dynamic>>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(staleTime: Duration.zero),
      );

      // Make stale so next fetch triggers SWR background revalidation.
      client.markStale(key);

      // SWR returns stale data and starts background fetch.
      await client.fetchQuery<Map<String, dynamic>>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(staleTime: Duration.zero),
      );

      // Wait for background revalidation to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The background fetch returned identical data, so the reference
      // should be preserved.
      final cached = client.getQueryData<Map<String, dynamic>>(key);
      expect(cached, isNotNull);

      // First data reference from getQueryData.
      final first = client.getQueryData<Map<String, dynamic>>(key);
      client.markStale(key);
      await client.fetchQuery<Map<String, dynamic>>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(staleTime: Duration.zero),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = client.getQueryData<Map<String, dynamic>>(key);
      expect(
        identical(first, second),
        isTrue,
        reason: 'unchanged data should preserve reference',
      );
    });

    test('fetchQuery returns new reference for changed data', () async {
      var callCount = 0;
      final key = QoraKey(['test']);

      Future<Map<String, dynamic>> fetcher() async {
        callCount++;
        return callCount == 1
            ? {'name': 'Alice', 'age': 30}
            : {'name': 'Alice', 'age': 31};
      }

      await client.fetchQuery<Map<String, dynamic>>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(staleTime: Duration.zero),
      );

      client.markStale(key);

      // SWR: returns stale data, starts background fetch.
      await client.fetchQuery<Map<String, dynamic>>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(staleTime: Duration.zero),
      );
      // Wait for background revalidation with changed data.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final cached = client.getQueryData<Map<String, dynamic>>(key);
      expect(cached, {'name': 'Alice', 'age': 31});

      // A second unchanged fetch should still preserve the new reference.
      client.markStale(key);
      await client.fetchQuery<Map<String, dynamic>>(
        key: key,
        fetcher: () async => {'name': 'Alice', 'age': 31},
        options: const QoraOptions(staleTime: Duration.zero),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = client.getQueryData<Map<String, dynamic>>(key);
      expect(
        identical(cached, second),
        isTrue,
        reason: 'unchanged data after change should preserve the new reference',
      );
    });

    test('setQueryData preserves reference for unchanged data', () {
      final key = QoraKey(['test']);
      final data = {'name': 'Alice'};

      client.setQueryData(key, data);

      // Set the same data again.
      client.setQueryData(key, {'name': 'Alice'});

      final cached = client.getQueryData<Map<String, dynamic>>(key);
      expect(
        identical(cached, data),
        isTrue,
        reason: 'unchanged setQueryData should preserve reference',
      );
    });

    test('setQueryData returns new reference for changed data', () {
      final key = QoraKey(['test']);

      client.setQueryData(key, {'name': 'Alice'});

      // Set different data.
      client.setQueryData(key, {'name': 'Bob'});

      final cached = client.getQueryData<Map<String, dynamic>>(key);
      expect(cached, {'name': 'Bob'});
    });

    test('setInfiniteQueryData preserves reference for unchanged data', () {
      final key = QoraKey(['infinite']);
      final firstPage = InfiniteData<int, int>(
        pages: [1, 2],
        pageParams: [0, 1],
      );

      client.setInfiniteQueryData(key, firstPage);

      // Second set with structurally identical data (int equality works).
      client.setInfiniteQueryData(
        key,
        InfiniteData<int, int>(
          pages: [1, 2],
          pageParams: [0, 1],
        ),
      );

      final cached = client.getInfiniteQueryData<int, int>(key);
      expect(cached, isNotNull);
      expect(
        identical(cached, firstPage),
        isTrue,
        reason: 'unchanged infinite data should preserve reference',
      );
    });

    test('setInfiniteQueryData returns new reference for changed data', () {
      final key = QoraKey(['infinite']);

      client.setInfiniteQueryData<int, int>(
        key,
        InfiniteData<int, int>(pages: [1], pageParams: [0]),
      );

      client.setInfiniteQueryData<int, int>(
        key,
        InfiniteData<int, int>(pages: [1, 2], pageParams: [0, 1]),
      );

      final cached = client.getInfiniteQueryData<int, int>(key);
      expect(cached, isNotNull);
      expect(cached!.pageCount, 2);
    });

    test('structuralSharing:false always returns new references', () async {
      final key = QoraKey(['test']);
      var callCount = 0;

      Future<Map<String, dynamic>> fetcher() async {
        callCount++;
        return {'name': 'Alice', 'age': 30};
      }

      await client.fetchQuery<Map<String, dynamic>>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(
          staleTime: Duration.zero,
          structuralSharing: false,
        ),
      );

      // Get the first reference.
      final first = client.getQueryData<Map<String, dynamic>>(key);

      client.markStale(key);

      await client.fetchQuery<Map<String, dynamic>>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(
          staleTime: Duration.zero,
          structuralSharing: false,
        ),
      );
      // Wait for background revalidation.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = client.getQueryData<Map<String, dynamic>>(key);

      expect(callCount, 2);
      expect(
        identical(first, second),
        isFalse,
        reason: 'structuralSharing:false should always create new references',
      );
    });

    test('stream emits with shared data still notify subscribers', () async {
      final key = QoraKey(['test']);
      // ignore: unused_local_variable
      var callCount = 0;

      Future<String> fetcher() async {
        callCount++;
        return 'hello';
      }

      final states = <String>[];
      client
          .watchQuery<String>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(staleTime: Duration.zero),
      )
          .listen((s) {
        if (s.isSuccess) {
          states.add(s.dataOrNull as String);
        }
      });

      // Allow the first fetch to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      client.markStale(key);

      // Trigger a second fetch.
      await client.fetchQuery<String>(
        key: key,
        fetcher: fetcher,
        options: const QoraOptions(staleTime: Duration.zero),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Even with structural sharing, subscribers should be notified.
      expect(states.length, greaterThanOrEqualTo(1));
    });
  });
}

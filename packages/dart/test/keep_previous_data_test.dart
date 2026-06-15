import 'dart:async';

import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/config/qora_options.dart';
import 'package:qora/src/key/qora_key.dart';
import 'package:qora/src/state/qora_state.dart';
import 'package:test/test.dart';

void main() {
  group('keepPreviousData', () {
    late QoraClient client;

    setUp(() {
      client = QoraClient();
    });

    tearDown(() {
      client.clear();
    });

    test('keeps Success state during refetch', () async {
      final key = QoraKey(['test']);

      // First fetch
      await client.fetchQuery<String>(
        key: key,
        fetcher: () async => 'Page 1',
        options: const QoraOptions(staleTime: Duration(seconds: 10)),
      );

      expect(client.getQueryState<String>(key), isA<Success<String>>());

      // Subscribe to observe transitions
      final states = <QoraState<String>>[];
      final sub = client.watchState<String>(key).listen(states.add);

      // Second fetch with keepPreviousData: staleTime zero triggers SWR
      // so fetchQuery returns stale 'Page 1' immediately and refetches in background.
      await client.fetchQuery<String>(
        key: key,
        fetcher: () async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'Page 2';
        },
        options: const QoraOptions(
          staleTime: Duration.zero,
          keepPreviousData: true,
        ),
      );

      // Pump microtasks so stream events are delivered to the listener
      await Future<void>.delayed(Duration.zero);
      // Should NOT have observed Loading (keepPreviousData suppresses it)
      expect(states.any((s) => s is Loading), isFalse);

      // Wait for the background refetch to land 'Page 2' in the cache
      await Future.doWhile(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return client.getQueryData<String>(key) != 'Page 2';
      });

      // Final state should be Success with new data
      expect(client.getQueryState<String>(key), isA<Success<String>>());
      expect(client.getQueryData<String>(key), 'Page 2');

      await sub.cancel();
    });

    test('keeps Success state on fetch error', () async {
      final key = QoraKey(['test']);

      // First fetch
      await client.fetchQuery<String>(
        key: key,
        fetcher: () async => 'Cached data',
        options: const QoraOptions(staleTime: Duration(seconds: 10)),
      );

      // Second fetch that fails: staleTime zero triggers SWR, returning stale data.
      // The error happens in the background refetch.
      await client
          .fetchQuery<String>(
            key: key,
            fetcher: () async => throw Exception('Network error'),
            options: const QoraOptions(
              staleTime: Duration.zero,
              keepPreviousData: true,
            ),
          )
          .catchError((_) => '');

      // The fetcher throws immediately, so the background refetch error handler
      // runs on the next microtask cycle. Pump microtasks to let it settle.
      await Future<void>.delayed(Duration.zero);

      // Should still be in Success with old data
      final state = client.getQueryState<String>(key);
      expect(state, isA<Success<String>>());
      expect((state as Success<String>).data, 'Cached data');
    });

    test('no effect on initial fetch (no previous data)', () async {
      final key = QoraKey(['test']);

      // Initial fetch with keepPreviousData: should still show Loading
      final states = <QoraState<String>>[];

      final sub = client.watchState<String>(key).listen(states.add);

      await client.fetchQuery<String>(
        key: key,
        fetcher: () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return 'Data';
        },
        options: const QoraOptions(
          keepPreviousData: true,
          staleTime: Duration.zero,
        ),
      );

      // Pump microtasks so the stream delivers all pending events
      await Future<void>.delayed(Duration.zero);

      // Should have seen Loading (no previous data to keep)
      expect(states.any((s) => s is Loading), isTrue);
      // Use getQueryState for the synchronous final state
      final state = client.getQueryState<String>(key);
      expect(state, isA<Success<String>>());
      expect((state as Success<String>).data, 'Data');

      await sub.cancel();
    });

    test('false (default) transitions to Loading on refetch', () async {
      final key = QoraKey(['test']);

      await client.fetchQuery<String>(
        key: key,
        fetcher: () async => 'Page 1',
        options: const QoraOptions(staleTime: Duration(seconds: 10)),
      );

      final states = <QoraState<String>>[];
      final sub = client.watchState<String>(key).listen(states.add);

      // Second fetch with keepPreviousData: false triggers SWR.
      // _doFetch synchronously emits Loading (keepPreviousData is false),
      // but the stream delivery is async.
      await client.fetchQuery<String>(
        key: key,
        fetcher: () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return 'Page 2';
        },
        options: const QoraOptions(
          staleTime: Duration.zero,
          keepPreviousData: false,
        ),
      );

      // Pump microtasks to deliver the Loading state from the background refetch
      await Future<void>.delayed(Duration.zero);

      // Default behavior: shows Loading during refetch
      expect(states.any((s) => s is Loading), isTrue);

      await sub.cancel();
    });

    test('keeps state through multiple refetches', () async {
      final key = QoraKey(['test']);

      await client.fetchQuery<String>(
        key: key,
        fetcher: () async => 'Page 1',
        options: const QoraOptions(staleTime: Duration(seconds: 10)),
      );

      // Helper: fetch via SWR and wait for background refetch to land
      Future<void> refetch(String expected) async {
        await client.fetchQuery<String>(
          key: key,
          fetcher: () async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return expected;
          },
          options: const QoraOptions(
            staleTime: Duration.zero,
            keepPreviousData: true,
          ),
        );
        await Future.doWhile(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return client.getQueryData<String>(key) != expected;
        });
      }

      // Second refetch → 'Page 2'
      await refetch('Page 2');
      expect(client.getQueryData<String>(key), 'Page 2');

      // Third refetch → 'Page 3'
      await refetch('Page 3');
      expect(client.getQueryData<String>(key), 'Page 3');
    });
  });
}

import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/config/qora_options.dart';
import 'package:qora/src/state/qora_state.dart';
import 'package:test/test.dart';

void main() {
  group('initialData', () {
    late QoraClient client;

    setUp(() => client = QoraClient());
    tearDown(() => client.clear());

    // ── initialData — fresh (no background refetch) ───────────────────────

    test('initialData marked fresh skips the network', () async {
      var fetchCalled = false;

      final result = await client.fetchQuery<String>(
        key: ['user', 1],
        fetcher: () async {
          fetchCalled = true;
          return 'from network';
        },
        options: QoraOptions(
          initialData: 'from cache',
          // Mark as just-fetched → treated as fresh for staleTime duration.
          initialDataUpdatedAt: DateTime.now(),
          staleTime: const Duration(minutes: 5),
        ),
      );

      expect(result, 'from cache');
      expect(fetchCalled, isFalse, reason: 'data is fresh — network skipped');
    });

    test('initialData pre-populates state to Success when fresh', () async {
      await client.fetchQuery<String>(
        key: ['greeting'],
        fetcher: () async => 'network',
        options: QoraOptions(
          initialData: 'hello',
          initialDataUpdatedAt: DateTime.now(),
          staleTime: const Duration(minutes: 5),
        ),
      );

      final state = client.getQueryState<String>(['greeting']);
      expect(state, isA<Success<String>>());
      expect((state as Success<String>).data, 'hello');
    });

    // ── initialData — stale (SWR: return immediately, refetch in background)

    test('initialData without updatedAt is epoch-stale → triggers SWR refetch',
        () async {
      var fetchCount = 0;

      // Default initialDataUpdatedAt = epoch → immediately stale.
      // fetchQuery returns the initialData synchronously (SWR), then refetches.
      final result = await client.fetchQuery<String>(
        key: ['item'],
        fetcher: () async {
          fetchCount++;
          return 'fresh';
        },
        options: const QoraOptions(
          initialData: 'stale-placeholder',
          // staleTime defaults to Duration.zero → initialData is stale
        ),
      );

      // SWR: initialData is returned immediately.
      expect(result, 'stale-placeholder');

      // Drain the event loop so the background fetch completes.
      await Future<void>.delayed(Duration.zero);

      expect(fetchCount, 1, reason: 'background SWR refetch should have fired');
      expect(client.getQueryData<String>(['item']), 'fresh');
    });

    test('type mismatch in initialData is silently ignored → normal fetch',
        () async {
      final result = await client.fetchQuery<String>(
        key: ['typed'],
        fetcher: () async => 'from-network',
        options: const QoraOptions(initialData: 42), // wrong type
      );

      // Falls through to network fetch because `42 is! String`.
      expect(result, 'from-network');
    });

    // ── placeholderData ───────────────────────────────────────────────────

    test('placeholderData reads from cache and avoids a fresh fetch', () async {
      client.setQueryData<List<String>>(['users'], ['alice', 'bob']);

      var fetchCalled = false;

      final result = await client.fetchQuery<String>(
        key: ['user', 'alice'],
        fetcher: () async {
          fetchCalled = true;
          return 'alice-detail';
        },
        options: QoraOptions(
          placeholderData: () {
            final list = client.getQueryData<List<String>>(['users']);
            return list?.firstWhere((u) => u == 'alice', orElse: () => '');
          },
          initialDataUpdatedAt: DateTime.now(),
          staleTime: const Duration(minutes: 5),
        ),
      );

      expect(result, 'alice');
      expect(fetchCalled, isFalse);
    });

    test('placeholderData returning null falls through to normal fetch',
        () async {
      final result = await client.fetchQuery<String>(
        key: ['missing'],
        fetcher: () async => 'fetched',
        options: QoraOptions(placeholderData: () => null),
      );

      expect(result, 'fetched');
    });

    test('initialData takes precedence over placeholderData', () async {
      var fetchCalled = false;

      final result = await client.fetchQuery<String>(
        key: ['priority'],
        fetcher: () async {
          fetchCalled = true;
          return 'network';
        },
        options: QoraOptions(
          initialData: 'static',
          placeholderData: () => 'dynamic',
          initialDataUpdatedAt: DateTime.now(),
          staleTime: const Duration(minutes: 5),
        ),
      );

      expect(result, 'static');
      expect(fetchCalled, isFalse);
    });

    // ── watchQuery integration ────────────────────────────────────────────

    test(
        'watchQuery with stale initialData carries placeholder via '
        'Loading.previousData before replacing with network data', () async {
      final states = <QoraState<String>>[];

      final sub = client.watchQuery<String>(
        key: ['watch-initial'],
        fetcher: () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 'network';
        },
        options: const QoraOptions(
          initialData: 'placeholder',
          // epoch timestamp → stale → SWR triggers background refetch
        ),
      ).listen(states.add);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();

      // With stale initialData the sequence is:
      //   Loading(previousData: 'placeholder')  ← _doFetch sets Loading,
      //                                            carrying the placeholder
      //   Success('network')                    ← fetch completes
      expect(states.isNotEmpty, isTrue);
      expect(states.first, isA<Loading<String>>());
      expect(
        (states.first as Loading<String>).previousData,
        'placeholder',
        reason: 'placeholder is surfaced via Loading.previousData (SWR)',
      );
      expect(states.last, isA<Success<String>>());
      expect((states.last as Success<String>).data, 'network');
    });

    test(
        'watchQuery with fresh initialData emits Success immediately, '
        'no Loading flash', () async {
      final states = <QoraState<String>>[];

      final sub = client.watchQuery<String>(
        key: ['watch-fresh'],
        fetcher: () async => 'network',
        options: QoraOptions(
          initialData: 'placeholder',
          initialDataUpdatedAt: DateTime.now(),
          staleTime: const Duration(minutes: 5),
        ),
      ).listen(states.add);

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // Fresh initialData → no fetch triggered → only Success emitted.
      expect(states.first, isA<Success<String>>());
      expect((states.first as Success<String>).data, 'placeholder');
      expect(
        states.any((s) => s is Loading),
        isFalse,
        reason: 'no Loading flash with fresh initialData',
      );
    });

    // ── QoraOptions.merge ─────────────────────────────────────────────────

    test('merge preserves initialData from child options', () {
      const base = QoraOptions();
      const child = QoraOptions(initialData: 'child');
      final merged = base.merge(child);
      expect(merged.initialData, 'child');
    });

    test('merge falls back to base initialData when child has none', () {
      const base = QoraOptions(initialData: 'base');
      const child = QoraOptions();
      final merged = base.merge(child);
      expect(merged.initialData, 'base');
    });

    test('merge preserves placeholderData from child options', () {
      const base = QoraOptions();
      Object? fn() => 'x';
      final child = QoraOptions(placeholderData: fn);
      final merged = base.merge(child);
      expect(merged.placeholderData, fn);
    });
  });
}

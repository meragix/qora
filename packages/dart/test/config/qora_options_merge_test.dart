import 'package:qora/qora.dart';
import 'package:test/test.dart';

/// Every non-nullable field set to a value that differs from its default.
const _globals = QoraOptions(
  staleTime: Duration(minutes: 5),
  gcTime: Duration(minutes: 10),
  enabled: false,
  retryCount: 0,
  retryDelay: Duration(milliseconds: 10),
  refetchOnWindowFocus: false,
  refetchOnReconnect: false,
  networkMode: NetworkMode.always,
  structuralSharing: false,
  keepPreviousData: true,
);

void main() {
  group('QoraOptions.merge', () {
    test('a field the query leaves unset inherits the global value', () {
      final merged = _globals.merge(
        const QoraOptions(providesTags: [QueryTag('t')]),
      );

      expect(merged.staleTime, const Duration(minutes: 5));
      expect(merged.gcTime, const Duration(minutes: 10));
      expect(merged.enabled, isFalse);
      expect(merged.retryCount, 0);
      expect(merged.retryDelay, const Duration(milliseconds: 10));
      expect(merged.refetchOnWindowFocus, isFalse);
      expect(merged.refetchOnReconnect, isFalse);
      expect(merged.networkMode, NetworkMode.always);
      expect(merged.structuralSharing, isFalse);
      expect(merged.keepPreviousData, isTrue);
    });

    test('a field the query sets wins, even when set to its default', () {
      final merged = _globals.merge(
        const QoraOptions(
          staleTime: Duration.zero,
          gcTime: Duration(minutes: 5),
          enabled: true,
          retryCount: 3,
          retryDelay: Duration(seconds: 1),
          refetchOnWindowFocus: true,
          refetchOnReconnect: true,
          networkMode: NetworkMode.online,
          structuralSharing: true,
          keepPreviousData: false,
        ),
      );

      expect(merged.staleTime, Duration.zero);
      expect(merged.gcTime, const Duration(minutes: 5));
      expect(merged.enabled, isTrue);
      expect(merged.retryCount, 3);
      expect(merged.retryDelay, const Duration(seconds: 1));
      expect(merged.refetchOnWindowFocus, isTrue);
      expect(merged.refetchOnReconnect, isTrue);
      expect(merged.networkMode, NetworkMode.online);
      expect(merged.structuralSharing, isTrue);
      expect(merged.keepPreviousData, isFalse);
    });

    test('an unset field reads as its documented default', () {
      const options = QoraOptions();

      expect(options.staleTime, Duration.zero);
      expect(options.gcTime, const Duration(minutes: 5));
      expect(options.enabled, isTrue);
      expect(options.retryCount, 3);
      expect(options.retryDelay, const Duration(seconds: 1));
      expect(options.refetchOnWindowFocus, isTrue);
      expect(options.refetchOnReconnect, isTrue);
      expect(options.networkMode, NetworkMode.online);
      expect(options.structuralSharing, isTrue);
      expect(options.keepPreviousData, isFalse);
    });

    test('an unset field stays unset through a chain of merges', () {
      final chained = const QoraOptions()
          .merge(const QoraOptions(retryCount: 1))
          .merge(const QoraOptions(staleTime: Duration(seconds: 3)));

      // Neither step set gcTime: a later merge onto globals still inherits.
      final merged = _globals.merge(chained);
      expect(merged.gcTime, const Duration(minutes: 10));
      expect(merged.retryCount, 1);
      expect(merged.staleTime, const Duration(seconds: 3));
    });
  });

  test('per-query options keep the global retry policy', () async {
    final client = QoraClient(
      config: const QoraClientConfig(
        defaultOptions: QoraOptions(retryCount: 0),
      ),
    );
    addTearDown(client.dispose);
    var calls = 0;

    await expectLater(
      client.fetchQuery<String>(
        key: ['k'],
        fetcher: () async {
          calls++;
          throw StateError('boom');
        },
        options: const QoraOptions(staleTime: Duration(minutes: 1)),
      ),
      throwsStateError,
    );

    expect(calls, 1, reason: 'retryCount: 0 comes from defaultOptions');
  });
}

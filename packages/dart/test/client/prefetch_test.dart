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
  _FakeConnectivity({required bool online}) : _online = online;

  final bool _online;

  @override
  NetworkStatus get currentStatus =>
      _online ? NetworkStatus.online : NetworkStatus.offline;

  @override
  Stream<NetworkStatus> get statusStream => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  void dispose() {}
}

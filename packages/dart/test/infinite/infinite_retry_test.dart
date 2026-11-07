import 'package:qora/qora.dart';
import 'package:test/test.dart';

class _HttpError implements Exception {
  const _HttpError(this.status);
  final int status;
}

void main() {
  group('InfiniteQueryObserver retry', () {
    late QoraClient client;

    setUp(() => client = QoraClient());
    tearDown(() => client.dispose());

    InfiniteQueryObserver<List<int>, int> observer({
      required Future<List<int>> Function(int page) fetcher,
      required QoraOptions baseOptions,
    }) =>
        InfiniteQueryObserver<List<int>, int>(
          client: client,
          key: ['feed'],
          fetcher: fetcher,
          options: InfiniteQueryOptions<List<int>, int>(
            initialPageParam: 0,
            getNextPageParam: (lastPage, allPages) => allPages.length,
            baseOptions: baseOptions,
          ),
        );

    test('stops retrying when retryCondition returns false', () async {
      var calls = 0;
      final obs = observer(
        fetcher: (_) async {
          calls++;
          throw const _HttpError(404);
        },
        baseOptions: QoraOptions(
          retryCount: 3,
          retryDelay: Duration.zero,
          retryCondition: (error, _) =>
              error is! _HttpError || error.status >= 500,
        ),
      );

      await obs.fetch();

      expect(calls, 1);
      expect(obs.state, isA<InfiniteFailure<List<int>, int>>());
      obs.dispose();
    });

    test('retries up to retryCount while retryCondition returns true',
        () async {
      var calls = 0;
      final obs = observer(
        fetcher: (_) async {
          calls++;
          throw const _HttpError(503);
        },
        baseOptions: QoraOptions(
          retryCount: 2,
          retryDelay: Duration.zero,
          retryCondition: (error, _) =>
              error is! _HttpError || error.status >= 500,
        ),
      );

      await obs.fetch();

      expect(calls, 3);
      obs.dispose();
    });

    test('passes the error and the zero-based attempt index', () async {
      final seen = <(Object, int)>[];
      final obs = observer(
        fetcher: (_) async => throw const _HttpError(503),
        baseOptions: QoraOptions(
          retryCount: 2,
          retryDelay: Duration.zero,
          retryCondition: (error, attempt) {
            seen.add((error, attempt));
            return true;
          },
        ),
      );

      await obs.fetch();

      expect(seen.map((e) => e.$2), [0, 1]);
      expect(seen.every((e) => e.$1 is _HttpError), isTrue);
      obs.dispose();
    });

    test('applies the retryCondition of the client default options', () async {
      client.dispose();
      client = QoraClient(
        config: QoraClientConfig(
          defaultOptions: QoraOptions(
            retryCondition: (_, __) => false,
          ),
        ),
      );
      var calls = 0;
      final obs = observer(
        fetcher: (_) async {
          calls++;
          throw const _HttpError(503);
        },
        baseOptions: const QoraOptions(
          retryCount: 3,
          retryDelay: Duration.zero,
        ),
      );

      await obs.fetch();

      expect(calls, 1);
      obs.dispose();
    });

    test('also applies to fetchNextPage', () async {
      var calls = 0;
      final obs = observer(
        fetcher: (page) async {
          if (page == 0) return [0];
          calls++;
          throw const _HttpError(401);
        },
        baseOptions: QoraOptions(
          retryCount: 3,
          retryDelay: Duration.zero,
          retryCondition: (error, _) =>
              error is! _HttpError || error.status >= 500,
        ),
      );

      await obs.fetch();
      await obs.fetchNextPage();

      expect(calls, 1);
      obs.dispose();
    });
  });
}

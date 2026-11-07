import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_hooks/qora_hooks.dart';

class _HttpError implements Exception {
  const _HttpError(this.status);
  final int status;
}

void main() {
  late QoraClient client;
  late InfiniteQueryHandle<List<int>, int> handle;
  late int nextPageCalls;

  setUp(() {
    client = QoraClient();
    nextPageCalls = 0;
  });

  /// Page 0 always succeeds; page 1 throws [errors] in order, then succeeds.
  Future<void> mount(
    WidgetTester tester, {
    required List<Object> errors,
    QoraOptions? options,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QoraScope(
          client: client,
          child: HookBuilder(builder: (context) {
            handle = useInfiniteQuery<List<int>, int>(
              key: const ['feed'],
              fetcher: (page) async {
                if (page == 0) return [0];
                nextPageCalls++;
                if (nextPageCalls <= errors.length) {
                  throw errors[nextPageCalls - 1];
                }
                return [page];
              },
              getNextPageParam: (last) =>
                  last.first < 3 ? last.first + 1 : null,
              initialPageParam: 0,
              options: options,
            );
            return const SizedBox.shrink();
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Runs fetchNextPage while advancing fake time through retry delays.
  Future<void> fetchNext(WidgetTester tester) async {
    final done = handle.fetchNextPage();
    await tester.pumpAndSettle();
    await done;
    await tester.pump();
  }

  group('useInfiniteQuery fetchNextPage retry', () {
    testWidgets('retries a failed page and appends it on success',
        (tester) async {
      await mount(
        tester,
        errors: [const _HttpError(503)],
        options: const QoraOptions(retryCount: 2, retryDelay: Duration.zero),
      );

      await fetchNext(tester);

      expect(nextPageCalls, 2);
      expect(handle.pages, [
        [0],
        [1],
      ]);
      expect(handle.error, isNull);
    });

    testWidgets('gives up after retryCount and exposes the error',
        (tester) async {
      const error = _HttpError(503);
      await mount(
        tester,
        errors: [error, error, error],
        options: const QoraOptions(retryCount: 2, retryDelay: Duration.zero),
      );

      await fetchNext(tester);

      expect(nextPageCalls, 3);
      expect(handle.pages, hasLength(1));
      expect(handle.error, same(error));
    });

    testWidgets('stops when retryCondition returns false', (tester) async {
      await mount(
        tester,
        errors: [const _HttpError(404)],
        options: QoraOptions(
          retryCount: 3,
          retryDelay: Duration.zero,
          retryCondition: (e, _) => e is! _HttpError || e.status >= 500,
        ),
      );

      await fetchNext(tester);

      expect(nextPageCalls, 1);
      expect(handle.error, isA<_HttpError>());
    });

    testWidgets('applies retryCount and retryCondition from client defaults',
        (tester) async {
      client = QoraClient(
        config: QoraClientConfig(
          defaultOptions: QoraOptions(
            retryCount: 2,
            retryDelay: Duration.zero,
            retryCondition: (e, _) => e is! _HttpError || e.status >= 500,
          ),
        ),
      );
      // 503 is retried (defaults allow it), then 404 stops the retries.
      await mount(
        tester,
        errors: [const _HttpError(503), const _HttpError(404)],
      );

      await fetchNext(tester);

      expect(nextPageCalls, 2);
      expect((handle.error! as _HttpError).status, 404);
    });

    testWidgets('clears the previous error once a page loads', (tester) async {
      await mount(
        tester,
        errors: [const _HttpError(503)],
        options: const QoraOptions(retryCount: 0),
      );

      await fetchNext(tester);
      expect(handle.error, isNotNull);

      await fetchNext(tester);

      expect(handle.pages, hasLength(2));
      expect(handle.error, isNull);
    });
  });

  group('useInfiniteQuery fetchNextPage during a retry', () {
    const retryEvery100ms = QoraOptions(
      retryCount: 3,
      retryDelay: Duration(milliseconds: 100),
    );

    testWidgets('unmounting stops the retries without touching state',
        (tester) async {
      await mount(
        tester,
        errors: List.filled(4, const _HttpError(503)),
        options: retryEvery100ms,
      );

      final done = handle.fetchNextPage();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      await done;

      expect(nextPageCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a key change drops the late page of the previous key',
        (tester) async {
      final feed = ValueNotifier('a');
      late InfiniteQueryHandle<List<String>, int> feedHandle;
      var aNextCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: QoraScope(
            client: client,
            child: ValueListenableBuilder<String>(
              valueListenable: feed,
              builder: (context, name, _) => HookBuilder(builder: (context) {
                feedHandle = useInfiniteQuery<List<String>, int>(
                  key: ['feed', name],
                  fetcher: (page) async {
                    if (page == 0) return ['$name-0'];
                    if (name == 'a' && ++aNextCalls == 1) {
                      throw const _HttpError(503);
                    }
                    return ['$name-$page'];
                  },
                  getNextPageParam: (last) => 1,
                  initialPageParam: 0,
                  options: retryEvery100ms,
                );
                return const SizedBox.shrink();
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1 of "a" fails once and waits 100 ms before its retry.
      final done = feedHandle.fetchNextPage();
      await tester.pump(const Duration(milliseconds: 10));
      feed.value = 'b';
      await tester.pump(); // rebuild with the new key before the retry is due
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await done;
      await tester.pump();

      expect(feedHandle.pages, [
        ['b-0'],
      ]);
      expect(feedHandle.isFetchingNextPage, isFalse);
      expect(aNextCalls, 1);
    });
  });
}

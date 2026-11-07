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

    testWidgets('applies the client default options', (tester) async {
      client = QoraClient(
        config: const QoraClientConfig(
          defaultOptions: QoraOptions(retryCount: 0),
        ),
      );
      await mount(tester, errors: [const _HttpError(503)]);

      await fetchNext(tester);

      expect(nextPageCalls, 1);
      expect(handle.error, isA<_HttpError>());
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
}

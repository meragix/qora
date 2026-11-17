import 'package:flutter_test/flutter_test.dart';
import 'package:qora/qora.dart';
import 'package:qora_devtools_overlay/qora_devtools_overlay.dart';
import 'package:qora_devtools_overlay/src/domain/queries_notifier.dart';
import 'package:qora_devtools_overlay/src/domain/query_detail.dart';
import 'package:qora_devtools_shared/qora_devtools_shared.dart';

void main() {
  late OverlayTracker tracker;
  late QueriesNotifier queries;

  setUp(() {
    tracker = OverlayTracker();
    queries = QueriesNotifier(tracker);
  });

  tearDown(() {
    queries.dispose();
    tracker.dispose();
  });

  QueryEvent row(String key) =>
      queries.queries.singleWhere((e) => e.key == key);

  test('a failed fetch leaves the row in error, not loading', () async {
    tracker.onQueryFetching('k');
    tracker.onQueryFetched('k', null, 'error');
    await pumpEventQueue();

    expect(row('k').status, 'error');
    expect(queries.activeQueryCount, 0);
  });

  test('a cancelled refetch shows the previous result again', () async {
    tracker.onQueryFetching('k');
    tracker.onQueryFetched('k', {'n': 1}, 'success');
    tracker.onQueryFetching('k');
    tracker.onQueryCancelled('k');
    await pumpEventQueue();

    expect(row('k').status, 'success');
    expect(row('k').data, {'n': 1});
    expect(queries.activeQueryCount, 0);
  });

  test('a cancelled first fetch leaves an idle row, not loading', () async {
    tracker.onQueryFetching('k');
    tracker.onQueryCancelled('k');
    await pumpEventQueue();

    expect(row('k').status, 'idle');
    expect(queries.activeQueryCount, 0);
  });

  test('setQueryData creates a row with the written data', () async {
    tracker.onOptimisticUpdate('k', {'title': 'local'});
    await pumpEventQueue();

    expect(row('k').status, 'success');
    expect(row('k').data, {'title': 'local'});
  });

  test('setQueryData keeps the options reported by the last fetch', () async {
    tracker.onQueryFetched('k', 1, 'success',
        staleTimeMs: 5000, gcTimeMs: 60000, observerCount: 2);
    tracker.onOptimisticUpdate('k', 2);
    await pumpEventQueue();

    expect(row('k').data, 2);
    expect(row('k').staleTimeMs, 5000);
    expect(row('k').gcTimeMs, 60000);
    expect(row('k').observerCount, 2);
  });

  test('a mutation after setQueryData is not labelled optimistic', () {
    tracker.onOptimisticUpdate('todos', ['a']);
    tracker.onMutationStarted('m1', 'todos', null);

    expect(tracker.mutationHistory.single.isOptimistic, isFalse);
  });

  test('details of a row without a creation time do not throw', () {
    final event = QueryEvent(
      eventId: 'e1',
      timestampMs: 0,
      type: QueryEventType.invalidated,
      key: 'k',
    );

    expect(QueryDetail.fromEvent(event).createdAt, isNull);
  });

  test('an error row keeps the data shown before the failure', () async {
    tracker.onQueryFetched('k', {'n': 1}, 'success');
    tracker.onQueryFetching('k');
    tracker.onQueryFetched('k', null, 'error');
    await pumpEventQueue();

    expect(row('k').status, 'error');
    expect(row('k').data, {'n': 1});
  });

  test('an error after invalidate() keeps the data shown before', () async {
    tracker.onQueryFetched('k', {'n': 1}, 'success');
    tracker.onQueryInvalidated('k');
    tracker.onQueryMarkedStale('k');
    tracker.onQueryFetching('k');
    tracker.onQueryFetched('k', null, 'error');
    await pumpEventQueue();

    expect(row('k').data, {'n': 1});
  });

  test('an error row has no stale time', () {
    final event = QueryEvent.fetched(
      key: 'k',
      status: 'error',
      staleTimeMs: 1000,
    );

    expect(QueryDetail.fromEvent(event).staleAt, isNull);
  });

  test('clearing the cache removes every row', () async {
    tracker.onQueryFetched('a', 1, 'success');
    tracker.onQueryFetching('b');
    tracker.onCacheCleared();
    await pumpEventQueue();

    expect(queries.queries, isEmpty);
  });

  test('a panel opened after a removal shows no row for it', () {
    tracker.onQueryFetched('gone', 1, 'success');
    tracker.onQueryRemoved('gone');
    final late = QueriesNotifier(tracker);
    addTearDown(late.dispose);

    expect(late.queries, isEmpty);
  });

  group('with a real client', () {
    late QoraClient client;

    setUp(() => client = QoraClient(
          config: const QoraClientConfig(
            defaultOptions: QoraOptions(retryCount: 0),
          ),
          tracker: tracker,
        ));
    tearDown(() => client.dispose());

    test('a failed fetch shows an error row', () async {
      await expectLater(
        client.fetchQuery<int>(
          key: const ['todos'],
          fetcher: () async => throw StateError('boom'),
        ),
        throwsStateError,
      );
      await pumpEventQueue();

      expect(row('["todos"]').status, 'error');
      expect(queries.activeQueryCount, 0);
    });

    test('a cancelled fetch shows the previous result', () async {
      await client.fetchQuery<int>(key: const ['n'], fetcher: () async => 1);
      final token = CancelToken();
      client.invalidate(const ['n']);
      final future = client.fetchQuery<int>(
        key: const ['n'],
        fetcher: () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return 2;
        },
        cancelToken: token,
      );
      token.cancel();
      await expectLater(future, throwsA(isA<QoraCancelException>()));
      await pumpEventQueue();

      expect(row('["n"]').status, isNot('loading'));
      expect(queries.activeQueryCount, 0);
    });

    test('setQueryData with a model shows it as JSON', () async {
      client.setQueryData(const ['todo'], const _Todo('Buy milk'));
      await pumpEventQueue();

      expect(row('["todo"]').status, 'success');
      expect(row('["todo"]').data, {'title': 'Buy milk'});
    });
  });
}

class _Todo {
  const _Todo(this.title);
  final String title;
  Map<String, Object?> toJson() => {'title': title};
}

import 'dart:async';

import 'package:qora/qora.dart';
import 'package:test/test.dart';

/// Records the fetch hooks, in call order.
class _RecordingTracker implements QoraTracker {
  _RecordingTracker({this.needsSerialization = false});

  final List<String> calls = [];
  final List<Object?> written = [];
  final List<String?> dependsOn = [];

  @override
  final bool needsSerialization;

  @override
  void onQueryFetching(String key) => calls.add('fetching $key');

  @override
  void onQueryFetched(
    String key,
    Object? data,
    dynamic status, {
    int? staleTimeMs,
    int? gcTimeMs,
    int observerCount = 0,
    int? retryCount,
    String? dependsOnKey,
  }) {
    calls.add('fetched $key $status');
    dependsOn.add(dependsOnKey);
  }

  @override
  void onQueryCancelled(String key) => calls.add('cancelled $key');

  @override
  void onQueryInvalidated(String key) {}

  @override
  void onQueryRemoved(String key) {}

  @override
  void onQueryMarkedStale(String key) {}

  @override
  void onMutationStarted(String id, String key, Object? variables) {}

  @override
  void onMutationSettled(String id, bool success, Object? result) {}

  @override
  void onOptimisticUpdate(String key, Object? optimisticData) =>
      written.add(optimisticData);

  @override
  void onCacheCleared() {}

  @override
  void dispose() {}
}

void main() {
  late _RecordingTracker tracker;
  late QoraClient client;

  setUp(() {
    tracker = _RecordingTracker();
    client = QoraClient(
      config: const QoraClientConfig(
        defaultOptions: QoraOptions(retryCount: 0),
      ),
      tracker: tracker,
    );
  });

  tearDown(() => client.dispose());

  test('a failed fetch is reported to the tracker as an error', () async {
    await expectLater(
      client.fetchQuery<int>(
        key: const ['todos'],
        fetcher: () async => throw StateError('boom'),
      ),
      throwsStateError,
    );

    expect(client.getQueryState<int>(const ['todos']), isA<Failure<int>>());
    expect(tracker.calls, ['fetching ["todos"]', 'fetched ["todos"] error']);
  });

  test('a failed refetch that keeps previous data is reported as an error',
      () async {
    await client.fetchQuery<int>(key: const ['n'], fetcher: () async => 1);
    client.invalidate(const ['n']);
    await expectLater(
      client.fetchQuery<int>(
        key: const ['n'],
        fetcher: () async => throw StateError('boom'),
        options: const QoraOptions(keepPreviousData: true),
      ),
      throwsStateError,
    );

    expect(client.getQueryData<int>(const ['n']), 1);
    expect(tracker.calls.last, 'fetched ["n"] error');
  });

  test('a cancelled fetch is not reported as an error', () async {
    final token = CancelToken();
    final future = client.fetchQuery<int>(
      key: const ['c'],
      fetcher: () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 1;
      },
      cancelToken: token,
    );
    token.cancel();
    await expectLater(future, throwsA(isA<QoraCancelException>()));

    expect(tracker.calls, isNot(contains('fetched ["c"] error')));
    expect(tracker.calls, contains('cancelled ["c"]'));
  });

  test('a failed fetch reports its dependsOn key', () async {
    client.setQueryData(const ['parent'], 1);
    await expectLater(
      client.fetchQuery<int>(
        key: const ['child'],
        fetcher: () async => throw StateError('boom'),
        options: const QoraOptions(dependsOn: ['parent']),
      ),
      throwsStateError,
    );

    expect(tracker.dependsOn.last, '["parent"]');
  });

  test('a failing fetch superseded by a newer write reports nothing', () async {
    final slow = Completer<int>();
    final first = client.fetchQuery<int>(
      key: const ['s'],
      fetcher: () => slow.future,
    );
    client.invalidate(const ['s']);
    await client.fetchQuery<int>(key: const ['s'], fetcher: () async => 2);
    slow.completeError(StateError('late'));
    await expectLater(first, throwsStateError);

    expect(tracker.calls, isNot(contains('fetched ["s"] error')));
    expect(client.getQueryData<int>(const ['s']), 2);
  });

  test('a failing fetch whose query was removed reports nothing', () async {
    final slow = Completer<int>();
    final future = client.fetchQuery<int>(
      key: const ['r'],
      fetcher: () => slow.future,
    );
    client.removeQuery(const ['r']);
    slow.completeError(StateError('late'));
    await expectLater(future, throwsStateError);

    expect(tracker.calls, isNot(contains('fetched ["r"] error')));
  });

  test('a call cancelled before it starts does not cancel a running fetch',
      () async {
    final slow = Completer<int>();
    final running = client.fetchQuery<int>(
      key: const ['p'],
      fetcher: () => slow.future,
    );
    final token = CancelToken()..cancel();
    await expectLater(
      client.fetchQuery<int>(
        key: const ['p'],
        fetcher: () async => 1,
        cancelToken: token,
      ),
      throwsA(isA<QoraCancelException>()),
    );
    slow.complete(1);
    await running;

    expect(tracker.calls, isNot(contains('cancelled ["p"]')));
    expect(tracker.calls.last, 'fetched ["p"] success');
  });

  test('setQueryData sends serialized data to a tracker that asks for it', () {
    final serializing = _RecordingTracker(needsSerialization: true);
    final other = QoraClient(tracker: serializing);
    addTearDown(other.dispose);

    other.setQueryData(const ['todo'], const _Todo('Buy milk'));
    tracker.calls.clear();
    client.setQueryData(const ['todo'], const _Todo('Buy milk'));

    expect(serializing.written.single, {'title': 'Buy milk'});
    expect(tracker.written.single, isA<_Todo>());
  });

  test(
      'a call cancelled before it starts does not cancel a fetch still '
      'running after invalidate()', () async {
    final slow = Completer<int>();
    final running = client.fetchQuery<int>(
      key: const ['i'],
      fetcher: () => slow.future,
    );
    client.invalidate(const ['i']);
    final token = CancelToken()..cancel();
    await expectLater(
      client.fetchQuery<int>(
        key: const ['i'],
        fetcher: () async => 1,
        cancelToken: token,
      ),
      throwsA(isA<QoraCancelException>()),
    );
    slow.complete(1);
    await running;

    expect(tracker.calls, isNot(contains('cancelled ["i"]')));
  });

  test('a throwing toJson never breaks a fetch or setQueryData', () async {
    final serializing = _RecordingTracker(needsSerialization: true);
    final other = QoraClient(tracker: serializing);
    addTearDown(other.dispose);
    final options = QoraOptions(toJson: (_) => throw StateError('toJson'));

    final value = await other.fetchQuery<int>(
      key: const ['t'],
      fetcher: () async => 1,
      options: options,
    );
    other.setQueryData(const ['t'], 2);

    expect(value, 1);
    expect(other.getQueryData<int>(const ['t']), 2);
    expect(serializing.calls, contains('fetched ["t"] success'));
    expect(serializing.written.single, isA<Map<String, Object?>>());
  });
}

class _Todo {
  const _Todo(this.title);
  final String title;
  Map<String, Object?> toJson() => {'title': title};
}

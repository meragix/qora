import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_qora/flutter_qora.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_hooks/qora_hooks.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Wraps [child] in a minimal [MaterialApp] + [QoraScope].
Widget _app(QoraClient client, Widget child) => MaterialApp(
      home: QoraScope(client: client, child: child),
    );

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── useQueryClient ─────────────────────────────────────────────────────────

  group('useQueryClient', () {
    testWidgets('returns the QoraClient from the nearest QoraScope',
        (tester) async {
      late QoraClient captured;
      final client = QoraClient();

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            captured = useQueryClient();
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(captured, same(client));
    });
  });

  // ── useQuery ───────────────────────────────────────────────────────────────

  group('useQuery', () {
    testWidgets('starts in Initial then transitions to Success', (tester) async {
      final client = QoraClient();
      final states = <QoraState<String>>[];

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            final state = useQuery<String>(
              key: const ['greet'],
              fetcher: () async => 'hello',
            );
            states.add(state);
            return const SizedBox.shrink();
          }),
        ),
      );

      await tester.pumpAndSettle();

      expect(states.first, isA<Initial<String>>());
      expect(states.last, isA<Success<String>>());
      expect((states.last as Success<String>).data, 'hello');
    });

    testWidgets('re-subscribes when key changes', (tester) async {
      final client = QoraClient();
      final keyNotifier = ValueNotifier<String>('a');

      await tester.pumpWidget(
        _app(
          client,
          ValueListenableBuilder<String>(
            valueListenable: keyNotifier,
            builder: (_, key, __) => HookBuilder(builder: (context) {
              useQuery<String>(
                key: [key],
                fetcher: () async => 'data-$key',
              );
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(client.getQueryData<String>(['a']), 'data-a');

      keyNotifier.value = 'b';
      await tester.pumpAndSettle();
      expect(client.getQueryData<String>(['b']), 'data-b');
    });

    testWidgets('returns Failure on fetcher error', (tester) async {
      final client = QoraClient();
      QoraState<String>? lastState;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            lastState = useQuery<String>(
              key: const ['bad'],
              fetcher: () async => throw Exception('oops'),
              options: const QoraOptions(retryCount: 0),
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      await tester.pumpAndSettle();
      expect(lastState, isA<Failure<String>>());
    });
  });

  // ── useMutation ────────────────────────────────────────────────────────────

  group('useMutation', () {
    testWidgets('starts Idle then transitions through Pending to Success',
        (tester) async {
      final client = QoraClient();
      final states = <MutationState<String, String>>[];
      late MutationHandle<String, String> handle;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            handle = useMutation<String, String>(
              mutator: (v) async => 'result-$v',
            );
            states.add(handle.state);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(handle.isIdle, isTrue);

      handle.mutate('test');
      await tester.pump();
      expect(states.any((s) => s.isPending), isTrue);

      await tester.pumpAndSettle();
      expect(handle.isSuccess, isTrue);
      expect(handle.data, 'result-test');
    });

    testWidgets('reset returns to Idle after Success', (tester) async {
      final client = QoraClient();
      late MutationHandle<String, String> handle;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            handle = useMutation<String, String>(mutator: (v) async => v);
            return const SizedBox.shrink();
          }),
        ),
      );

      handle.mutate('x');
      await tester.pumpAndSettle();
      expect(handle.isSuccess, isTrue);

      handle.reset();
      await tester.pump();
      expect(handle.isIdle, isTrue);
    });

    testWidgets('transitions to isError on mutator failure', (tester) async {
      final client = QoraClient();
      late MutationHandle<String, String> handle;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            handle = useMutation<String, String>(
              mutator: (_) async => throw Exception('fail'),
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      handle.mutate('x');
      await tester.pumpAndSettle();

      expect(handle.isError, isTrue);
      expect(handle.error, isA<Exception>());
    });
  });

  // ── useInfiniteQuery ───────────────────────────────────────────────────────

  group('useInfiniteQuery', () {
    testWidgets('loads first page on mount', (tester) async {
      final client = QoraClient();
      late InfiniteQueryHandle<List<int>, int> handle;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            handle = useInfiniteQuery<List<int>, int>(
              key: const ['inf-1'],
              fetcher: (page) async => [page * 10, page * 10 + 1],
              getNextPageParam: (page) =>
                  page.last < 100 ? page.last ~/ 10 + 1 : null,
              initialPageParam: 0,
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      await tester.pumpAndSettle();

      expect(handle.pages, hasLength(1));
      expect(handle.pages.first, [0, 1]);
      expect(handle.isLoading, isFalse);
    });

    testWidgets('fetchNextPage appends a new page', (tester) async {
      final client = QoraClient();
      late InfiniteQueryHandle<List<int>, int> handle;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            handle = useInfiniteQuery<List<int>, int>(
              key: const ['inf-2'],
              fetcher: (page) async => [page],
              getNextPageParam: (page) => page.first < 2 ? page.first + 1 : null,
              initialPageParam: 0,
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      await tester.pumpAndSettle();
      expect(handle.pages, hasLength(1));

      await handle.fetchNextPage();
      await tester.pumpAndSettle();
      expect(handle.pages, hasLength(2));
    });

    testWidgets(
        'hasNextPage becomes false when getNextPageParam returns null',
        (tester) async {
      final client = QoraClient();
      late InfiniteQueryHandle<List<int>, int> handle;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            handle = useInfiniteQuery<List<int>, int>(
              key: const ['inf-3'],
              fetcher: (page) async => [page],
              getNextPageParam: (_) => null,
              initialPageParam: 0,
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      await tester.pumpAndSettle();
      await handle.fetchNextPage();
      await tester.pump();

      expect(handle.hasNextPage, isFalse);
    });
  });
}

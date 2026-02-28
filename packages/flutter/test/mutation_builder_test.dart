import 'package:flutter/material.dart';
import 'package:flutter_qora/flutter_qora.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) {
  return MaterialApp(
    home: QoraScope(
      client: QoraClient(),
      child: Scaffold(body: child),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('QoraMutationBuilder', () {
    testWidgets('renders with initial MutationIdle state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          QoraMutationBuilder<String, String, void>(
            mutationFn: (v) async => v,
            builder: (context, state, mutate) {
              return Text(state.isIdle ? 'idle' : 'other');
            },
          ),
        ),
      );

      expect(find.text('idle'), findsOneWidget);
    });

    testWidgets('transitions to success state after mutate', (tester) async {
      await tester.pumpWidget(
        _wrap(
          QoraMutationBuilder<String, String, void>(
            mutationFn: (title) async => 'created:$title',
            builder: (context, state, mutate) {
              return Column(
                children: [
                  if (state.isIdle)
                    ElevatedButton(
                      onPressed: () => mutate('hello'),
                      child: const Text('submit'),
                    ),
                  if (state.isPending) const Text('loading'),
                  if (state.isSuccess) Text('success:${state.dataOrNull}'),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('submit'), findsOneWidget);

      await tester.tap(find.text('submit'));
      await tester.pump();
      expect(find.text('loading'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('success:created:hello'), findsOneWidget);
    });

    testWidgets('transitions to failure state on error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          QoraMutationBuilder<String, String, void>(
            mutationFn: (_) async => throw Exception('boom'),
            builder: (context, state, mutate) {
              return Column(
                children: [
                  if (state.isIdle)
                    ElevatedButton(
                      onPressed: () => mutate('x'),
                      child: const Text('submit'),
                    ),
                  if (state.isError) Text('error:${state.errorOrNull}'),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('error:'), findsOneWidget);
    });

    testWidgets('success state is visible after mutate completes',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          QoraMutationBuilder<String, String, void>(
            mutationFn: (v) async => v,
            builder: (context, state, mutate) {
              return Column(
                children: [
                  if (state.isIdle)
                    ElevatedButton(
                      onPressed: () => mutate('x'),
                      child: const Text('submit'),
                    ),
                  if (state.isSuccess) const Text('done'),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('submit'));
      await tester.pumpAndSettle();

      expect(find.text('done'), findsOneWidget);
    });

    testWidgets('mutate is disabled while pending (guard pattern)',
        (tester) async {
      var mutateCallCount = 0;

      await tester.pumpWidget(
        _wrap(
          QoraMutationBuilder<String, String, void>(
            mutationFn: (v) async {
              mutateCallCount++;
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return v;
            },
            builder: (context, state, mutate) {
              return ElevatedButton(
                onPressed: state.isPending ? null : () => mutate('x'),
                child: const Text('submit'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('submit'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.text('submit'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(mutateCallCount, 1);
    });

    testWidgets('optimistic update: onMutate applies and onError rolls back',
        (tester) async {
      final client = QoraClient();
      client.setQueryData<List<String>>(['items'], ['a', 'b']);

      final log = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: QoraScope(
            client: client,
            child: Scaffold(
              body: QoraMutationBuilder<String, String, List<String>?>(
                mutationFn: (_) async => throw Exception('server error'),
                options: MutationOptions(
                  onMutate: (item) async {
                    final prev = client.getQueryData<List<String>>(['items']);
                    client.setQueryData<List<String>>(
                      ['items'],
                      [...?prev, item],
                    );
                    log.add(
                      'optimistic:${client.getQueryData<List<String>>([
                            'items'
                          ])?.join(',')}',
                    );
                    return prev;
                  },
                  onError: (error, variables, previous) async {
                    client.restoreQueryData(['items'], previous);
                    log.add(
                      'rollback:${client.getQueryData<List<String>>([
                            'items'
                          ])?.join(',')}',
                    );
                  },
                ),
                builder: (context, state, mutate) {
                  return ElevatedButton(
                    onPressed: state.isPending ? null : () => mutate('c'),
                    child: const Text('add'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();

      expect(log, ['optimistic:a,b,c', 'rollback:a,b']);
      expect(client.getQueryData<List<String>>(['items']), ['a', 'b']);
    });
  });
}

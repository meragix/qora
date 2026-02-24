import 'package:qora/qora.dart';
import 'package:test/test.dart';

void main() {
  group('MutationController', () {
    // ── Basic state transitions ──────────────────────────────────────────

    test('initial state is MutationIdle', () {
      final controller = MutationController<String, String, void>(
        mutator: (v) async => v,
      );
      addTearDown(controller.dispose);

      expect(controller.state, isA<MutationIdle<String, String>>());
      expect(controller.state.isIdle, isTrue);
    });

    test('transitions Idle → Pending → Success on successful mutate', () async {
      final states = <MutationState<String, String>>[];

      final controller = MutationController<String, String, void>(
        mutator: (title) async => 'created:$title',
      );
      addTearDown(controller.dispose);

      final sub = controller.stream.listen(states.add);
      addTearDown(sub.cancel);

      final result = await controller.mutate('hello');

      expect(result, 'created:hello');
      expect(states, [
        isA<MutationIdle<String, String>>(),
        isA<MutationPending<String, String>>(),
        isA<MutationSuccess<String, String>>(),
      ]);

      final success = states.last as MutationSuccess<String, String>;
      expect(success.data, 'created:hello');
      expect(success.variables, 'hello');
    });

    test('transitions Idle → Pending → Failure on failed mutate', () async {
      final states = <MutationState<String, String>>[];

      final controller = MutationController<String, String, void>(
        mutator: (_) async => throw Exception('network error'),
      );
      addTearDown(controller.dispose);

      final sub = controller.stream.listen(states.add);
      addTearDown(sub.cancel);

      final result = await controller.mutate('hello');

      expect(result, isNull);
      expect(states, [
        isA<MutationIdle<String, String>>(),
        isA<MutationPending<String, String>>(),
        isA<MutationFailure<String, String>>(),
      ]);

      final failure = states.last as MutationFailure<String, String>;
      expect(failure.error, isA<Exception>());
      expect(failure.variables, 'hello');
    });

    test('reset transitions any state back to MutationIdle', () async {
      final controller = MutationController<String, String, void>(
        mutator: (v) async => v,
      );
      addTearDown(controller.dispose);

      await controller.mutate('test');
      expect(controller.state, isA<MutationSuccess<String, String>>());

      controller.reset();
      expect(controller.state, isA<MutationIdle<String, String>>());
    });

    // ── MutationOptions lifecycle callbacks ──────────────────────────────

    test('onMutate is called before the mutator', () async {
      final calls = <String>[];

      final controller = MutationController<String, String, void>(
        mutator: (v) async {
          calls.add('mutator');
          return v;
        },
        options: MutationOptions(
          onMutate: (v) async {
            calls.add('onMutate');
          },
        ),
      );
      addTearDown(controller.dispose);

      await controller.mutate('x');

      expect(calls, ['onMutate', 'mutator']);
    });

    test('onSuccess is called with data, variables, and context', () async {
      String? receivedData;
      String? receivedVariables;
      String? receivedContext;

      final controller = MutationController<String, String, String>(
        mutator: (v) async => 'result:$v',
        options: MutationOptions(
          onMutate: (v) async => 'ctx:$v',
          onSuccess: (data, variables, context) async {
            receivedData = data;
            receivedVariables = variables;
            receivedContext = context;
          },
        ),
      );
      addTearDown(controller.dispose);

      await controller.mutate('hello');

      expect(receivedData, 'result:hello');
      expect(receivedVariables, 'hello');
      expect(receivedContext, 'ctx:hello');
    });

    test('onError is called with error, variables, and context', () async {
      Object? receivedError;
      String? receivedVariables;
      String? receivedContext;

      final controller = MutationController<String, String, String>(
        mutator: (_) async => throw Exception('boom'),
        options: MutationOptions(
          onMutate: (v) async => 'snapshot:$v',
          onError: (error, variables, context) async {
            receivedError = error;
            receivedVariables = variables;
            receivedContext = context;
          },
        ),
      );
      addTearDown(controller.dispose);

      await controller.mutate('hello');

      expect(receivedError, isA<Exception>());
      expect(receivedVariables, 'hello');
      expect(receivedContext, 'snapshot:hello');
    });

    test('onSettled is called after success', () async {
      TData? settledData;
      Object? settledError;

      final controller = MutationController<String, String, void>(
        mutator: (v) async => 'ok:$v',
        options: MutationOptions(
          onSettled: (data, error, variables, context) async {
            settledData = data;
            settledError = error;
          },
        ),
      );
      addTearDown(controller.dispose);

      await controller.mutate('x');

      expect(settledData, 'ok:x');
      expect(settledError, isNull);
    });

    test('onSettled is called after failure', () async {
      TData? settledData;
      Object? settledError;

      final controller = MutationController<String, String, void>(
        mutator: (_) async => throw Exception('fail'),
        options: MutationOptions(
          onSettled: (data, error, variables, context) async {
            settledData = data;
            settledError = error;
          },
        ),
      );
      addTearDown(controller.dispose);

      await controller.mutate('x');

      expect(settledData, isNull);
      expect(settledError, isA<Exception>());
    });

    // ── Optimistic update rollback ───────────────────────────────────────

    test('onMutate snapshot is forwarded to onError for rollback', () async {
      final log = <String>[];
      final client = QoraClient();
      addTearDown(client.dispose);

      // Seed cache
      client.setQueryData<List<String>>(['items'], ['a', 'b']);

      final controller = MutationController<String, String, List<String>?>(
        mutator: (_) async => throw Exception('server error'),
        options: MutationOptions(
          onMutate: (item) async {
            final prev = client.getQueryData<List<String>>(['items']);
            client.setQueryData<List<String>>(
              ['items'],
              [...?prev, item],
            );
            log.add('optimistic applied');
            return prev;
          },
          onError: (error, variables, previous) async {
            client.restoreQueryData(['items'], previous);
            log.add('rollback applied');
          },
        ),
      );
      addTearDown(controller.dispose);

      // Optimistic state before mutate
      expect(client.getQueryData<List<String>>(['items']), ['a', 'b']);

      await controller.mutate('c');

      // After rollback, original data should be restored
      expect(client.getQueryData<List<String>>(['items']), ['a', 'b']);
      expect(log, ['optimistic applied', 'rollback applied']);
    });

    // ── onMutate failure ─────────────────────────────────────────────────

    test('mutator is skipped when onMutate throws', () async {
      var mutatorCalled = false;

      final controller = MutationController<String, String, void>(
        mutator: (v) async {
          mutatorCalled = true;
          return v;
        },
        options: MutationOptions(
          onMutate: (_) async => throw Exception('snapshot failed'),
        ),
      );
      addTearDown(controller.dispose);

      final result = await controller.mutate('x');

      expect(result, isNull);
      expect(mutatorCalled, isFalse);
      expect(controller.state, isA<MutationFailure<String, String>>());
    });

    // ── Retry ────────────────────────────────────────────────────────────

    test('retries the mutator up to retryCount times', () async {
      var attempts = 0;

      final controller = MutationController<String, String, void>(
        mutator: (_) async {
          attempts++;
          if (attempts < 3) throw Exception('temporary error');
          return 'success';
        },
        options: const MutationOptions(
          retryCount: 2,
          retryDelay: Duration(milliseconds: 1),
        ),
      );
      addTearDown(controller.dispose);

      final result = await controller.mutate('x');

      expect(result, 'success');
      expect(attempts, 3);
      expect(controller.state, isA<MutationSuccess<String, String>>());
    });

    test('fails after exhausting all retries', () async {
      var attempts = 0;

      final controller = MutationController<String, String, void>(
        mutator: (_) async {
          attempts++;
          throw Exception('always fails');
        },
        options: const MutationOptions(
          retryCount: 2,
          retryDelay: Duration(milliseconds: 1),
        ),
      );
      addTearDown(controller.dispose);

      final result = await controller.mutate('x');

      expect(result, isNull);
      expect(attempts, 3); // 1 initial + 2 retries
      expect(controller.state, isA<MutationFailure<String, String>>());
    });

    // ── Stream ───────────────────────────────────────────────────────────

    test('stream replays current state to new subscribers', () async {
      final controller = MutationController<String, String, void>(
        mutator: (v) async => v,
      );
      addTearDown(controller.dispose);

      await controller.mutate('x');

      // New subscriber should immediately receive the current Success state
      final received = <MutationState<String, String>>[];
      final sub = controller.stream.listen(received.add);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received.first, isA<MutationSuccess<String, String>>());
    });

    // ── Dispose ──────────────────────────────────────────────────────────

    test('throws StateError when mutate is called after dispose', () async {
      final controller = MutationController<String, String, void>(
        mutator: (v) async => v,
      );
      controller.dispose();

      expect(
        () => controller.mutate('x'),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when reset is called after dispose', () {
      final controller = MutationController<String, String, void>(
        mutator: (v) async => v,
      );
      controller.dispose();

      expect(controller.reset, throwsA(isA<StateError>()));
    });

    // ── State helpers ────────────────────────────────────────────────────

    test('state getters are correct for each state', () {
      const idle = MutationIdle<String, String>();
      expect(idle.isIdle, isTrue);
      expect(idle.isPending, isFalse);
      expect(idle.isSuccess, isFalse);
      expect(idle.isError, isFalse);
      expect(idle.dataOrNull, isNull);
      expect(idle.errorOrNull, isNull);
      expect(idle.variablesOrNull, isNull);

      const pending = MutationPending<String, String>(variables: 'v');
      expect(pending.isPending, isTrue);
      expect(pending.variablesOrNull, 'v');

      const success = MutationSuccess<String, String>(
        data: 'result',
        variables: 'v',
      );
      expect(success.isSuccess, isTrue);
      expect(success.dataOrNull, 'result');
      expect(success.variablesOrNull, 'v');

      const failure = MutationFailure<String, String>(
        error: 'err',
        variables: 'v',
      );
      expect(failure.isError, isTrue);
      expect(failure.errorOrNull, 'err');
      expect(failure.variablesOrNull, 'v');
    });

    test('MutationState.when calls the correct callback', () {
      var called = '';

      const MutationIdle<String, String>().when(onIdle: () => called = 'idle');
      expect(called, 'idle');

      const MutationPending<String, String>(variables: 'v')
          .when(onPending: (_) => called = 'pending');
      expect(called, 'pending');

      const MutationSuccess<String, String>(data: 'd', variables: 'v')
          .when(onSuccess: (_, __) => called = 'success');
      expect(called, 'success');

      const MutationFailure<String, String>(error: 'e', variables: 'v')
          .when(onError: (_, __, ___) => called = 'error');
      expect(called, 'error');
    });

    test('MutationState.maybeWhen returns orElse for unhandled states', () {
      final result = const MutationPending<String, String>(variables: 'v')
          .maybeWhen(orElse: () => 'fallback');
      expect(result, 'fallback');
    });

    test('MutationStateExtensions.fold is exhaustive', () {
      final result =
          const MutationSuccess<String, String>(data: 'd', variables: 'v')
              .fold(
        onIdle: () => 'idle',
        onPending: (_) => 'pending',
        onSuccess: (data, _) => 'success:$data',
        onError: (_, __, ___) => 'error',
      );
      expect(result, 'success:d');
    });

    test('MutationStateExtensions.status returns correct enum', () {
      expect(
        const MutationIdle<String, String>().status,
        MutationStatus.idle,
      );
      expect(
        const MutationPending<String, String>(variables: 'v').status,
        MutationStatus.pending,
      );
      expect(
        const MutationSuccess<String, String>(data: 'd', variables: 'v')
            .status,
        MutationStatus.success,
      );
      expect(
        const MutationFailure<String, String>(error: 'e', variables: 'v')
            .status,
        MutationStatus.error,
      );
    });

    // ── Equality ─────────────────────────────────────────────────────────

    test('equal states compare as equal', () {
      expect(
        const MutationIdle<String, String>(),
        const MutationIdle<String, String>(),
      );
      expect(
        const MutationSuccess<String, String>(data: 'd', variables: 'v'),
        const MutationSuccess<String, String>(data: 'd', variables: 'v'),
      );
      expect(
        const MutationFailure<String, String>(error: 'e', variables: 'v'),
        const MutationFailure<String, String>(error: 'e', variables: 'v'),
      );
    });
  });
}

// Helper type alias for readability in tests
typedef TData = String;

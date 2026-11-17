import 'dart:async';
import 'dart:math';

import 'package:qora/qora.dart';
import 'package:test/test.dart';

final _stringSerializer = QoraSerializer<String>(
  toJson: (v) => v,
  fromJson: (json) => json as String,
);

/// Fast retries so backoff tests run in milliseconds.
const _fastRetries = MutationQueueConfig(
  initialDelay: Duration(milliseconds: 1),
  maxDelay: Duration(milliseconds: 4),
);

/// Long enough for every retry of [_fastRetries] to run.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 40));

class _Rejected implements Exception {
  const _Rejected(this.reason);
  final String reason;
  @override
  String toString() => 'Rejected($reason)';
}

class _Timeout implements Exception {
  const _Timeout();
}

/// One recorded call to a registered mutator.
typedef _Call = ({String key, String variables, MutationMeta meta});

/// A client whose registered mutators answer from [script], recording calls.
///
/// [script] returns the result for a call: a value to return, an exception
/// to throw, or a [Completer] to wait on.
class _Harness {
  _Harness({
    MutationQueueConfig queue = _fastRetries,
    int maxConcurrent = 5,
  }) : client = QoraClient(
          config: QoraClientConfig(
            mutationQueue: queue,
            reconnectStrategy: ReconnectStrategy(
              maxConcurrent: maxConcurrent,
              jitter: Duration.zero,
            ),
          ),
        ) {
    client.attachConnectivityManager(connectivity);
    addTearDown(client.dispose);
  }

  final QoraClient client;
  final connectivity = _FakeConnectivity();
  final calls = <_Call>[];
  Object? Function(_Call call) script = (call) => 'ok:${call.variables}';

  MutationQueue get queue => client.mutationQueue;

  void register(
    String key, {
    String? Function(String variables)? scope,
    bool Function(Object error)? isPermanent,
    List<Object>? invalidates,
  }) {
    client.registerMutation<String, String>(
      key,
      mutator: (variables, meta) async {
        final call = (key: key, variables: variables, meta: meta);
        calls.add(call);
        final result = script(call);
        if (result is Completer<String>) return result.future;
        if (result is Exception) throw result;
        return result! as String;
      },
      variables: _stringSerializer,
      scope: scope,
      isPermanent: isPermanent,
      invalidates: invalidates,
    );
  }

  MutationController<String, String, Object?> controller(
    String key, {
    Future<void> Function(Object error, String variables, Object? context)?
        onError,
    Future<void> Function(String data, String variables, Object? context)?
        onSuccess,
    String Function(String variables)? optimisticResponse,
    List<Object>? invalidates,
    Future<void> Function(Object key)? invalidateQuery,
    Future<Object?> Function(String variables)? onMutate,
    Future<void> Function(
      String? data,
      Object? error,
      String variables,
      Object? context,
    )? onSettled,
  }) {
    final controller = MutationController<String, String, Object?>(
      options: MutationOptions(
        mutationKey: key,
        offlineQueue: true,
        onMutate: onMutate,
        onError: onError,
        onSuccess: onSuccess,
        onSettled: onSettled,
        optimisticResponse: optimisticResponse,
        invalidates: invalidates,
      ),
      registry: client.mutationRegistry,
      mutationQueue: client.mutationQueue,
      isOnline: () => client.isOnline,
      invalidateQuery: invalidateQuery,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> goOffline() async {
    connectivity.set(NetworkStatus.offline);
    await pumpEventQueue();
  }

  Future<void> goOnline() async {
    connectivity.set(NetworkStatus.online);
    await pumpEventQueue();
  }

  List<QueuedMutationStatus> get statuses =>
      queue.entries.map((e) => e.status).toList();

  List<String> get sent => calls.map((c) => c.variables).toList();
}

void main() {
  group('routing', () {
    test('an online call goes through the queue and leaves it on success',
        () async {
      final h = _Harness()..register('todos.create');
      final controller = h.controller('todos.create');

      final result = await controller.mutate('milk');

      expect(result, 'ok:milk');
      expect(controller.state, isA<MutationSuccess<String, String>>());
      expect(h.calls.single.meta.attempt, 0);
      expect(h.queue.isEmpty, isTrue);
    });

    test('a call made offline waits, then is sent on reconnect', () async {
      final h = _Harness()..register('todos.create');
      await h.goOffline();
      final controller = h.controller(
        'todos.create',
        optimisticResponse: (v) => 'draft:$v',
      );

      final result = await controller.mutate('milk');

      expect(result, 'draft:milk', reason: 'resolves when it starts waiting');
      expect(h.calls, isEmpty);
      expect(h.statuses, [QueuedMutationStatus.queued]);
      final id = h.queue.entries.single.mutationId;

      await h.goOnline();
      await pumpEventQueue();

      expect(h.calls.single.meta.mutationId, id);
      expect(h.queue.isEmpty, isTrue);
      final state = controller.state as MutationSuccess<String, String>;
      expect(state.data, 'ok:milk');
      expect(state.isOptimistic, isFalse);
    });

    test('a registered call without offlineQueue does not use the queue',
        () async {
      final h = _Harness()..register('todos.create');
      final controller = MutationController<String, String, void>(
        options: const MutationOptions(mutationKey: 'todos.create'),
        registry: h.client.mutationRegistry,
        mutationQueue: h.client.mutationQueue,
      );
      addTearDown(controller.dispose);
      h.script = (call) {
        expect(h.queue.isEmpty, isTrue);
        return 'direct';
      };

      expect(await controller.mutate('milk'), 'direct');
    });
  });

  group('transient failures', () {
    test('are retried with the same mutationId until they succeed', () async {
      final h = _Harness()..register('todos.create');
      h.script = (call) => h.calls.length < 3 ? const _Timeout() : 'ok';
      final controller = h.controller('todos.create');

      final result = await controller.mutate('milk');
      expect(result, isNull, reason: 'resolves when it starts waiting');

      await _settle();

      expect(h.calls.map((c) => c.meta.attempt), [0, 1, 2]);
      expect(h.calls.map((c) => c.meta.mutationId).toSet(), hasLength(1));
      expect(controller.state, isA<MutationSuccess<String, String>>());
      expect(h.queue.isEmpty, isTrue);
    });

    test('turn into a failure after maxAttempts', () async {
      final h = _Harness(
        queue: const MutationQueueConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 2),
        ),
      )..register('todos.create');
      h.script = (_) => const _Timeout();
      final errors = <Object>[];
      final controller = h.controller(
        'todos.create',
        onError: (e, _, __) async => errors.add(e),
      );

      await controller.mutate('milk');
      await _settle();

      expect(h.calls, hasLength(3));
      expect(h.statuses, [QueuedMutationStatus.failed]);
      expect(h.queue.entries.single.attempts, 3);
      expect(h.queue.entries.single.lastError, isA<_Timeout>());
      expect(errors, hasLength(1));
      expect(controller.state, isA<MutationFailure<String, String>>());
    });

    test('losing the network mid-request does not spend an attempt', () async {
      final h = _Harness()..register('todos.create');
      h.script = (call) {
        if (h.calls.length == 1) {
          h.connectivity.set(NetworkStatus.offline);
          return const _Timeout();
        }
        return 'ok';
      };
      final controller = h.controller('todos.create');

      await controller.mutate('milk');
      await pumpEventQueue();
      expect(h.statuses, [QueuedMutationStatus.queued]);
      expect(h.queue.entries.single.attempts, 0);

      await h.goOnline();
      await pumpEventQueue();

      expect(h.calls.map((c) => c.meta.attempt), [0, 0]);
      expect(controller.state, isA<MutationSuccess<String, String>>());
    });

    test('a waiting head holds the global lane', () async {
      final h = _Harness(
        queue: const MutationQueueConfig(
          initialDelay: Duration(milliseconds: 30),
          maxDelay: Duration(milliseconds: 30),
        ),
      )..register('todos.create');
      h.script = (call) => call.variables == 'a' && h.calls.length == 1
          ? const _Timeout()
          : 'ok';

      unawaited(h.controller('todos.create').mutate('a'));
      unawaited(h.controller('todos.create').mutate('b'));
      await pumpEventQueue();
      expect(h.sent, ['a'], reason: 'b waits behind a');

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(h.sent, ['a', 'a', 'b']);
    });
  });

  group('permanent failures', () {
    test('without a scope: failed, and the global lane continues', () async {
      final h = _Harness()
        ..register(
          'todos.create',
          isPermanent: (e) => e is _Rejected,
        );
      h.script =
          (call) => call.variables == 'bad' ? const _Rejected('invalid') : 'ok';

      await h.controller('todos.create').mutate('bad');
      await h.controller('todos.create').mutate('good');
      await pumpEventQueue();

      expect(h.sent, ['bad', 'good']);
      expect(h.statuses, [QueuedMutationStatus.failed]);
      expect(h.queue.entries.single.attempts, 1);
    });

    test('in a scope: blocked, the rest of the scope held, others go on',
        () async {
      final h = _Harness()
        ..register(
          'todos.save',
          scope: (v) => v.split(':').first,
          isPermanent: (e) => e is _Rejected,
        );
      h.script = (call) =>
          call.variables == 'a:create' ? const _Rejected('invalid') : 'ok';

      await h.controller('todos.save').mutate('a:create');
      await h.controller('todos.save').mutate('a:update');
      await h.controller('todos.save').mutate('b:create');
      await pumpEventQueue();

      expect(h.sent, ['a:create', 'b:create']);
      expect(h.statuses, [
        QueuedMutationStatus.blocked,
        QueuedMutationStatus.held,
      ]);
    });

    test('the client-level isPermanent applies when the key has none',
        () async {
      final h = _Harness(
        queue: MutationQueueConfig(
          initialDelay: const Duration(milliseconds: 1),
          isPermanent: (e) => e is _Rejected,
        ),
      )
        ..register('todos.create')
        ..register('todos.retryAll', isPermanent: (_) => false);
      h.script = (_) => const _Rejected('invalid');

      await h.controller('todos.create').mutate('a');
      await h.controller('todos.retryAll').mutate('b');
      await _settle();

      expect(h.calls.where((c) => c.key == 'todos.create'), hasLength(1));
      expect(h.calls.where((c) => c.key == 'todos.retryAll'), hasLength(5));
    });

    test('a throwing isPermanent counts as permanent', () async {
      final h = _Harness()
        ..register(
          'todos.create',
          isPermanent: (_) => throw StateError('cannot classify'),
        );
      h.script = (_) => const _Timeout();

      await h.controller('todos.create').mutate('a');
      await pumpEventQueue();

      expect(h.calls, hasLength(1));
      expect(h.statuses, [QueuedMutationStatus.failed]);
    });
  });

  group('ordering', () {
    test('a scope sends one call at a time, in order; scopes run in parallel',
        () async {
      final h = _Harness()..register('todos.save', scope: (v) => v[0]);
      final gate = Completer<String>();
      h.script = (call) => call.variables == 'a1' ? gate : 'ok';

      unawaited(h.controller('todos.save').mutate('a1'));
      unawaited(h.controller('todos.save').mutate('a2'));
      unawaited(h.controller('todos.save').mutate('b1'));
      await pumpEventQueue();

      expect(h.sent, ['a1', 'b1']);
      expect(h.statuses, [
        QueuedMutationStatus.sending,
        QueuedMutationStatus.queued,
      ]);

      gate.complete('ok');
      await pumpEventQueue();
      expect(h.sent, ['a1', 'b1', 'a2']);
      expect(h.queue.isEmpty, isTrue);
    });

    test('maxConcurrent bounds requests across lanes', () async {
      final h = _Harness(maxConcurrent: 1)
        ..register('todos.save', scope: (v) => v);
      final gate = Completer<String>();
      h.script = (call) => call.variables == 'a' ? gate : 'ok';

      unawaited(h.controller('todos.save').mutate('a'));
      unawaited(h.controller('todos.save').mutate('b'));
      await pumpEventQueue();
      expect(h.sent, ['a']);

      gate.complete('ok');
      await pumpEventQueue();
      expect(h.sent, ['a', 'b']);
    });
  });

  group('decisions', () {
    late _Harness h;
    var reject = true;

    setUp(() {
      reject = true;
      h = _Harness()
        ..register(
          'todos.save',
          scope: (v) => v.split(':').first,
          isPermanent: (e) => e is _Rejected,
        );
      h.script = (call) => reject && call.variables.endsWith('create')
          ? const _Rejected('invalid')
          : 'ok:${call.variables}';
    });

    Future<String> blockScopeA() async {
      await h.controller('todos.save').mutate('a:create');
      await h.controller('todos.save').mutate('a:update');
      await pumpEventQueue();
      return h.queue.entries.first.mutationId;
    }

    test('retry resends as-is under the same id, then drains held calls',
        () async {
      final succeeded = <String>[];
      await h
          .controller(
            'todos.save',
            onSuccess: (data, _, __) async => succeeded.add(data),
          )
          .mutate('a:create');
      await h.controller('todos.save').mutate('a:update');
      await pumpEventQueue();
      final id = h.queue.entries.first.mutationId;

      reject = false;
      h.queue.retry(id);
      await pumpEventQueue();

      expect(h.calls[1].meta.mutationId, id);
      expect(h.calls[1].meta.attempt, 0);
      expect(h.sent, ['a:create', 'a:create', 'a:update']);
      expect(
        succeeded,
        isEmpty,
        reason: 'the call site settled once, with onError, when it failed',
      );
      expect(h.queue.isEmpty, isTrue);
    });

    test('retry with variables replaces the call under a new id', () async {
      final id = await blockScopeA();

      reject = false;
      h.queue.retry(id, variables: 'a:create-fixed');
      await pumpEventQueue();

      expect(h.sent, ['a:create', 'a:create-fixed', 'a:update']);
      expect(h.calls[1].meta.mutationId, isNot(id));
      expect(h.queue.isEmpty, isTrue);
    });

    test('retry rejects variables of another type', () async {
      final id = await blockScopeA();
      expect(() => h.queue.retry(id, variables: 42), throwsArgumentError);
    });

    test('only blocked or failed calls can be retried', () async {
      await blockScopeA();
      final heldId = h.queue.entries[1].mutationId;
      expect(() => h.queue.retry(heldId), throwsStateError);
      expect(() => h.queue.retry('unknown'), throwsStateError);
    });

    test('discarding a blocked call blocks the calls it held', () async {
      final id = await blockScopeA();

      h.queue.discard(id);
      await pumpEventQueue();

      expect(h.sent, ['a:create'], reason: 'the update is not sent');
      expect(h.statuses, [QueuedMutationStatus.blocked]);
      expect(h.queue.entries.single.lastError, isNull);
    });

    test('discardScope removes the whole chain', () async {
      await blockScopeA();
      h.queue.discardScope('a');
      expect(h.queue.isEmpty, isTrue);
    });

    test('a retried failed call goes back to the head of the global lane',
        () async {
      final g = _Harness()
        ..register('notes.save', isPermanent: (e) => e is _Rejected);
      final gate = Completer<String>();
      var rejectFirst = true;
      g.script = (call) {
        if (call.variables == 'x' && rejectFirst) {
          return const _Rejected('invalid');
        }
        return call.variables == 'y' ? gate : 'ok';
      };
      await g.controller('notes.save').mutate('x');
      unawaited(g.controller('notes.save').mutate('y'));
      unawaited(g.controller('notes.save').mutate('z'));
      await pumpEventQueue();
      expect(g.sent, ['x', 'y']);

      rejectFirst = false;
      g.queue.retry(g.queue.entries.first.mutationId);
      await pumpEventQueue();
      expect(
        g.sent,
        ['x', 'y'],
        reason: 'one request per lane: y is in flight',
      );

      gate.complete('ok');
      await pumpEventQueue();

      expect(g.sent, ['x', 'y', 'x', 'z']);
    });

    test('a call discarded in flight is not retried', () async {
      final g = _Harness()..register('notes.save');
      final gate = Completer<String>();
      g.script = (_) => gate;
      unawaited(g.controller('notes.save').mutate('x'));
      await pumpEventQueue();

      g.queue.discard(g.queue.entries.single.mutationId);
      expect(g.queue.isEmpty, isTrue);
      gate.completeError(const _Timeout());
      await _settle();

      expect(g.calls, hasLength(1));
    });

    test('clear empties the queue', () async {
      await blockScopeA();
      await h.goOffline();
      await h.controller('todos.save').mutate('b:update');

      h.queue.clear();
      await h.goOnline();

      expect(h.queue.isEmpty, isTrue);
      expect(h.sent, ['a:create']);
    });
  });

  group('call site contract', () {
    test('a retry that fails again does not run the callbacks twice', () async {
      final h = _Harness()
        ..register('todos.create', isPermanent: (e) => e is _Rejected);
      h.script = (_) => const _Rejected('invalid');
      final errors = <Object>[];
      final controller = h.controller(
        'todos.create',
        onError: (e, _, __) async => errors.add(e),
      );

      await controller.mutate('milk');
      await pumpEventQueue();
      h.queue.retry(h.queue.entries.single.mutationId);
      await pumpEventQueue();

      expect(h.calls, hasLength(2));
      expect(errors, hasLength(1));
    });

    test('a call behind a head waiting for a retry resolves', () async {
      final h = _Harness(
        queue: const MutationQueueConfig(
          initialDelay: Duration(milliseconds: 30),
          maxDelay: Duration(milliseconds: 30),
        ),
      )..register('todos.save', scope: (v) => v[0]);
      h.script = (call) => call.variables == 'a1' && h.calls.length == 1
          ? const _Timeout()
          : 'ok';

      final first = h.controller('todos.save').mutate('a1');
      final second = h.controller('todos.save').mutate('a2');
      var secondDone = false;
      unawaited(second.then((_) => secondDone = true));
      await first;
      await pumpEventQueue();

      expect(secondDone, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(h.sent, ['a1', 'a1', 'a2']);
    });

    test('a throwing scope fails the call and rolls back', () async {
      final h = _Harness()
        ..register('todos.create', scope: (_) => throw StateError('bad'));
      final errors = <Object>[];
      final controller = h.controller(
        'todos.create',
        onError: (e, _, __) async => errors.add(e),
      );

      expect(await controller.mutate('milk'), isNull);

      expect(errors.single, isA<StateError>());
      expect(controller.state, isA<MutationFailure<String, String>>());
      expect(h.queue.isEmpty, isTrue);
    });

    test('disposing the client completes pending calls', () async {
      final h = _Harness()..register('todos.save', scope: (v) => v[0]);
      final gate = Completer<String>();
      h.script = (call) => call.variables == 'a1' ? gate : 'ok';

      var done = 0;
      unawaited(h.controller('todos.save').mutate('a1').then((_) => done++));
      unawaited(h.controller('todos.save').mutate('a2').then((_) => done++));
      await pumpEventQueue();

      h.client.dispose();
      gate.complete('ok');
      await pumpEventQueue();

      expect(done, 2);
    });

    test('NetworkMode.always bypasses the queue', () async {
      final h = _Harness()..register('todos.create');
      final controller = MutationController<String, String, void>(
        options: const MutationOptions(
          mutationKey: 'todos.create',
          offlineQueue: true,
          networkMode: NetworkMode.always,
        ),
        registry: h.client.mutationRegistry,
        mutationQueue: h.client.mutationQueue,
        isOnline: () => h.client.isOnline,
      );
      addTearDown(controller.dispose);
      h.script = (_) {
        expect(h.queue.isEmpty, isTrue);
        return 'direct';
      };

      expect(await controller.mutate('milk'), 'direct');
    });

    test('discarding a held call blocks the calls behind it', () async {
      final h = _Harness()
        ..register(
          'todos.save',
          scope: (v) => v[0],
          isPermanent: (e) => e is _Rejected,
        );
      h.script =
          (call) => call.variables == 'a1' ? const _Rejected('invalid') : 'ok';
      for (final v in ['a1', 'a2', 'a3']) {
        await h.controller('todos.save').mutate(v);
      }
      await pumpEventQueue();
      expect(h.statuses, [
        QueuedMutationStatus.blocked,
        QueuedMutationStatus.held,
        QueuedMutationStatus.held,
      ]);

      h.queue.discard(h.queue.entries[1].mutationId);

      expect(h.queue.entries.map((e) => e.variables), ['a1', 'a3']);
      expect(h.statuses, [
        QueuedMutationStatus.blocked,
        QueuedMutationStatus.blocked,
      ]);
    });
  });

  group('second review', () {
    test('a throwing onSettled cannot leave mutate pending', () async {
      final h = _Harness()..register('todos.create');
      final controller = h.controller(
        'todos.create',
        onSettled: (_, __, ___, ____) async => throw StateError('unmounted'),
      );

      final errors = <Object>[];
      final done = runZonedGuarded(
        () => controller.mutate('milk'),
        (e, _) => errors.add(e),
      )!;
      await done.timeout(const Duration(milliseconds: 200));
    });

    test('a slow onMutate keeps the call in its place in the scope', () async {
      final h = _Harness()..register('todos.save', scope: (_) => 'todo:1');
      final create = h.controller(
        'todos.save',
        onMutate: (_) => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      final update = h.controller('todos.save');

      unawaited(create.mutate('create'));
      unawaited(update.mutate('update'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(h.sent, ['create', 'update']);
    });

    test('discarding a waiting call runs onError so the rollback happens',
        () async {
      final h = _Harness();
      h.register('todos.create');
      await h.goOffline();
      final errors = <Object>[];
      final controller = h.controller(
        'todos.create',
        onError: (e, _, __) async => errors.add(e),
      );
      await controller.mutate('milk');

      h.queue.discard(h.queue.entries.single.mutationId);
      await pumpEventQueue();

      expect(errors.single, isA<MutationDiscardedException>());
      expect(controller.state, isA<MutationFailure<String, String>>());
    });

    test('going offline resolves a call waiting behind an in-flight one',
        () async {
      final h = _Harness()..register('todos.save', scope: (_) => 's');
      final gate = Completer<String>();
      h.script = (call) => call.variables == 'a1' ? gate : 'ok';
      unawaited(h.controller('todos.save').mutate('a1'));
      var secondDone = false;
      unawaited(
        h.controller('todos.save').mutate('a2').then((_) => secondDone = true),
      );
      await pumpEventQueue();
      expect(secondDone, isFalse);

      await h.goOffline();

      expect(secondDone, isTrue);
      gate.complete('ok');
    });

    test('a call discarded while onMutate runs settles with its context',
        () async {
      final h = _Harness()..register('todos.create');
      await h.goOffline();
      final mutateGate = Completer<String>();
      final rolledBack = <Object?>[];
      final controller = h.controller(
        'todos.create',
        onMutate: (_) => mutateGate.future,
        onError: (e, _, context) async => rolledBack.add((e, context)),
      );

      final done = controller.mutate('milk');
      await pumpEventQueue();
      expect(h.queue.entries, isEmpty, reason: 'onMutate still running');
      h.queue.clear();
      mutateGate.complete('snapshot');
      await done.timeout(const Duration(milliseconds: 200));

      final (error, context) = rolledBack.single! as (Object, Object?);
      expect(error, isA<MutationDiscardedException>());
      expect(context, 'snapshot');
      expect(h.queue.isEmpty, isTrue);
    });

    test('a throwing onMutate gives its place back to the scope', () async {
      final h = _Harness()..register('todos.save', scope: (_) => 'todo:1');
      final failing = h.controller(
        'todos.save',
        onMutate: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          throw StateError('no snapshot');
        },
      );
      final next = h.controller('todos.save');

      unawaited(failing.mutate('create'));
      unawaited(next.mutate('update'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(failing.state, isA<MutationFailure<String, String>>());
      expect(h.sent, ['update']);
      expect(h.queue.isEmpty, isTrue);
    });
  });

  group('sync status', () {
    test('entriesStream follows a call from queued to sent', () async {
      final h = _Harness()..register('todos.create');
      final gate = Completer<String>();
      h.script = (call) => gate;
      final seen = <List<QueuedMutationStatus>>[];
      final sub = h.queue.entriesStream
          .listen((entries) => seen.add([for (final e in entries) e.status]));
      addTearDown(sub.cancel);
      await h.goOffline();

      await h.controller('todos.create').mutate('milk');
      await pumpEventQueue();
      await h.goOnline();
      await pumpEventQueue();
      gate.complete('ok');
      await pumpEventQueue();

      expect(seen, [
        [QueuedMutationStatus.queued],
        [QueuedMutationStatus.sending],
        <QueuedMutationStatus>[],
      ]);
    });

    test('changes made in one run are reported once', () async {
      final h = _Harness()..register('todos.create');
      await h.goOffline();
      for (final v in ['a', 'b', 'c']) {
        await h.controller('todos.create').mutate(v);
      }
      final seen = <int>[];
      final sub = h.queue.entriesStream.listen((e) => seen.add(e.length));
      addTearDown(sub.cancel);

      for (final e in h.queue.entries) {
        h.queue.discard(e.mutationId);
      }
      h.queue.refresh();
      await pumpEventQueue();
      h.queue.refresh();
      await pumpEventQueue();

      expect(seen, [0]);
    });

    test('a retried call with no caller left reports to mutationEvents',
        () async {
      final h = _Harness()
        ..register('todos.create', isPermanent: (e) => e is _Rejected);
      h.script = (call) => const _Rejected('invalid');
      await h.controller('todos.create').mutate('milk');
      await _settle();
      final id = h.queue.entries.single.mutationId;
      final events = <MutationUpdate>[];
      final sub = h.client.mutationEvents.listen(events.add);
      addTearDown(sub.cancel);

      h.script = (call) => 'ok';
      h.queue.retry(id);
      await _settle();

      expect(events.map((e) => (e.mutatorId, e.status)), [
        ('queue:$id', MutationStatus.pending),
        ('queue:$id', MutationStatus.success),
      ]);
      expect(events.last.metadata?['mutationKey'], 'todos.create');
      expect(h.client.activeMutations, isEmpty);
    });

    test('discarding a call reported as pending reports how it ended',
        () async {
      final h = _Harness()
        ..register('todos.create', isPermanent: (e) => e is _Rejected);
      h.script = (call) => const _Rejected('invalid');
      await h.controller('todos.create').mutate('milk');
      await _settle();
      final id = h.queue.entries.single.mutationId;
      h.script = (call) => const _Timeout();
      h.queue.retry(id);
      await pumpEventQueue();
      expect(h.client.activeMutations, hasLength(1));

      h.queue.discard(id);

      expect(h.client.activeMutations, isEmpty);
    });

    test('a call discarded in flight reports one outcome, even if it succeeds',
        () async {
      final h = _Harness()
        ..register('todos.create', isPermanent: (e) => e is _Rejected);
      h.script = (call) => const _Rejected('invalid');
      await h.controller('todos.create').mutate('milk');
      await _settle();
      final id = h.queue.entries.single.mutationId;
      final events = <MutationUpdate>[];
      final sub = h.client.mutationEvents.listen(events.add);
      addTearDown(sub.cancel);
      final gate = Completer<String>();
      h.script = (call) => gate;
      h.queue.retry(id);
      await pumpEventQueue();

      h.queue.discard(id);
      gate.complete('ok');
      await _settle();

      expect(events.map((e) => (e.mutatorId, e.status)), [
        ('queue:$id', MutationStatus.pending),
        ('queue:$id', MutationStatus.error),
      ]);
    });

    test('a call discarded in flight by its caller reports nothing', () async {
      final h = _Harness()..register('todos.create');
      final gate = Completer<String>();
      h.script = (call) => gate;
      final events = <MutationUpdate>[];
      final sub = h.client.mutationEvents.listen(events.add);
      addTearDown(sub.cancel);
      unawaited(h.controller('todos.create').mutate('milk'));
      await pumpEventQueue();

      h.queue.discard(h.queue.entries.single.mutationId);
      gate.complete('ok');
      await _settle();

      expect(events.where((e) => e.mutatorId.startsWith('queue:')), isEmpty);
    });

    test('a call with no caller reports pending once across its attempts',
        () async {
      final h = _Harness()
        ..register('todos.create', isPermanent: (e) => e is _Rejected);
      h.script = (call) => const _Rejected('invalid');
      await h.controller('todos.create').mutate('milk');
      await _settle();
      final id = h.queue.entries.single.mutationId;
      final events = <MutationUpdate>[];
      final sub = h.client.mutationEvents.listen(events.add);
      addTearDown(sub.cancel);
      var attempts = 0;
      h.script = (call) => ++attempts < 3 ? const _Timeout() : 'ok';

      h.queue.retry(id);
      await _settle();

      expect(attempts, 3);
      expect(events.map((e) => (e.mutatorId, e.status)), [
        ('queue:$id', MutationStatus.pending),
        ('queue:$id', MutationStatus.success),
      ]);
    });
  });

  group('MutationQueueConfig.delayAfter', () {
    test('doubles from initialDelay, capped at maxDelay, half random', () {
      const config = MutationQueueConfig();
      final random = Random(1);
      for (final (failures, base) in [
        (1, 1),
        (2, 2),
        (3, 4),
        (4, 8),
        (6, 30),
      ]) {
        for (var i = 0; i < 50; i++) {
          final d = config.delayAfter(failures, random);
          expect(
            d.inMicroseconds,
            inInclusiveRange(base * 500000, base * 1000000),
            reason: 'after $failures failures',
          );
        }
      }
    });

    test('stays finite for huge delays and many failures', () {
      const config = MutationQueueConfig(
        initialDelay: Duration(days: 1),
        maxDelay: Duration(days: 365),
      );
      final d = config.delayAfter(80, Random(1));
      expect(d, lessThanOrEqualTo(const Duration(days: 365)));
      expect(d, greaterThanOrEqualTo(const Duration(days: 182)));
    });
  });

  group('callbacks', () {
    test('run after the controller is disposed, so a rollback still happens',
        () async {
      final h = _Harness()
        ..register('todos.create', isPermanent: (e) => e is _Rejected);
      h.script = (_) => const _Rejected('invalid');
      await h.goOffline();
      final rolledBack = <String>[];
      final controller = h.controller(
        'todos.create',
        onError: (_, variables, __) async => rolledBack.add(variables),
      );

      await controller.mutate('milk');
      controller.dispose();
      await h.goOnline();
      await pumpEventQueue();

      expect(rolledBack, ['milk']);
    });

    test('registered invalidations run before the call site ones', () async {
      final h = _Harness()
        ..register(
          'todos.create',
          invalidates: [
            ['todos'],
          ],
        );
      final invalidated = <Object>[];
      final controller = h.controller(
        'todos.create',
        invalidates: [
          ['stats'],
        ],
        invalidateQuery: (key) async => invalidated.add(key),
      );

      await controller.mutate('milk');

      expect(invalidated, [
        ['todos'],
        ['stats'],
      ]);
    });
  });
}

class _FakeConnectivity implements ConnectivityManager {
  final _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status = NetworkStatus.online;

  void set(NetworkStatus status) {
    _status = status;
    _controller.add(status);
  }

  @override
  Stream<NetworkStatus> get statusStream => _controller.stream;

  @override
  NetworkStatus get currentStatus => _status;

  @override
  Future<void> start() async {}

  @override
  void dispose() {}
}

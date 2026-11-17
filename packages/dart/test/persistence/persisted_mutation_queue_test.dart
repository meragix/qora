import 'dart:async';
import 'dart:convert';

import 'package:qora/qora.dart';
import 'package:test/test.dart';

class _NewTodo {
  const _NewTodo(this.id, this.title);
  final String id;
  final String title;

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  static _NewTodo fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return _NewTodo(map['id'] as String, map['title'] as String);
  }

  @override
  String toString() => '$id:$title';
}

final _todoSerializer = QoraSerializer<_NewTodo>(
  toJson: (v) => v.toJson(),
  fromJson: _NewTodo.fromJson,
);

class _Rejected implements Exception {
  const _Rejected();
  @override
  String toString() => 'Rejected';
}

/// An in-memory adapter whose queue writes can be held or made to fail.
class _Storage implements StorageAdapter {
  final data = <String, String>{};

  /// When set, a write of a queue record waits for it.
  Completer<void>? gate;

  /// When set, a write of a queue record throws it.
  Object? failWith;

  /// Number of next queue record writes that throw.
  int failNext = 0;

  /// Every queue record written, in order.
  final written = <Map<String, dynamic>>[];

  /// When set, a read of a queue record waits for it.
  Completer<void>? readGate;

  /// When set, a delete of a queue record waits for it.
  Completer<void>? deleteGate;

  /// When set, reading a queue record throws.
  bool failReads = false;

  /// Keys whose next read throws.
  final failReadOf = <String>{};

  /// When set, a read of a query entry waits for it.
  Completer<void>? queryReadGate;

  /// When set, reading a query entry throws.
  bool failQueryReads = false;

  /// When set, deleting a queue record throws.
  bool failDeletes = false;

  /// When set, deleting a query entry throws.
  bool failQueryDeletes = false;

  Map<String, Map<String, dynamic>> get records => {
        for (final e in data.entries)
          if (e.key.startsWith('qora:mutation:'))
            e.key: jsonDecode(e.value) as Map<String, dynamic>,
      };

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async {
    if (failReadOf.remove(key)) throw StateError('io');
    if (key.startsWith('[')) {
      // Read before waiting: a delete meanwhile does not change the result.
      final value = data[key];
      if (queryReadGate case final gate?) await gate.future;
      if (failQueryReads) throw StateError('io');
      return value;
    }
    if (key.startsWith('qora:mutation:')) {
      if (failReads) throw StateError('io');
      final value = data[key];
      if (readGate case final gate?) await gate.future;
      return value;
    }
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (key.startsWith('qora:mutation:')) {
      if (gate case final gate?) await gate.future;
      if (failWith case final error?) throw error;
      if (failNext > 0) {
        failNext--;
        throw StateError('disk full');
      }
    }
    data[key] = value;
    if (key.startsWith('qora:mutation:')) {
      written.add(jsonDecode(value) as Map<String, dynamic>);
    }
  }

  @override
  Future<void> delete(String key) async {
    if (key.startsWith('qora:mutation:')) {
      if (deleteGate case final gate?) await gate.future;
      if (failDeletes) throw StateError('io');
    }
    if (key.startsWith('[') && failQueryDeletes) throw StateError('io');
    data.remove(key);
  }

  @override
  Future<List<String>> keys() async => data.keys.toList();

  @override
  Future<void> clear() async => data.clear();

  @override
  Future<void> dispose() async {}
}

/// One app start: a client on [storage] with `todos.save` registered.
class _App {
  _App(this.storage, {bool online = true})
      : client = PersistQoraClient(
          storage: storage,
          config: const QoraClientConfig(
            mutationQueue: MutationQueueConfig(
              initialDelay: Duration(milliseconds: 1),
              maxDelay: Duration(milliseconds: 4),
            ),
          ),
        ) {
    connectivity.set(online ? NetworkStatus.online : NetworkStatus.offline);
    client.attachConnectivityManager(connectivity);
    client.registerMutation<String, _NewTodo>(
      'todos.save',
      mutator: (variables, meta) async {
        sent.add((variables.toString(), meta.mutationId));
        final result = script(variables);
        if (result is Exception) throw result;
        return result! as String;
      },
      variables: _todoSerializer,
      scope: (v) => v.id == 'none' ? null : 'todo:${v.id}',
      isPermanent: (error) => error is _Rejected,
      invalidates: const [
        ['todos'],
      ],
    );
    addTearDown(client.dispose);
  }

  final _Storage storage;
  final PersistQoraClient client;
  final connectivity = _FakeConnectivity();
  final sent = <(String, String)>[];
  Object? Function(_NewTodo variables) script = (v) => 'ok';

  MutationQueue get queue => client.mutationQueue;

  MutationController<String, _NewTodo, Object?> controller({
    Future<Object?> Function(_NewTodo variables)? onMutate,
    String Function(_NewTodo variables)? optimisticResponse,
    Future<void> Function(Object error, _NewTodo variables, Object? context)?
        onError,
  }) {
    final controller = MutationController<String, _NewTodo, Object?>(
      options: MutationOptions(
        mutationKey: 'todos.save',
        offlineQueue: true,
        onMutate: onMutate,
        optimisticResponse: optimisticResponse,
        onError: onError,
      ),
      registry: client.mutationRegistry,
      mutationQueue: client.mutationQueue,
      isOnline: () => client.isOnline,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> goOnline() async {
    connectivity.set(NetworkStatus.online);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('storing calls', () {
    test('a call is stored with its record before mutate returns', () async {
      final storage = _Storage();
      final app = _App(storage, online: false);

      await app.controller().mutate(const _NewTodo('1', 'milk'));

      final record = storage.records.values.single;
      final entry = app.queue.entries.single;
      expect(record['version'], 1);
      expect(record['mutationId'], entry.mutationId);
      expect(record['key'], 'todos.save');
      expect(record['scope'], 'todo:1');
      expect(record['variables'], {'id': '1', 'title': 'milk'});
      expect(record['attempts'], 0);
      expect(record['status'], 'queued');
    });

    test('the optimistic state waits for the call to be stored', () async {
      final storage = _Storage()..gate = Completer<void>();
      final app = _App(storage, online: false);
      final controller = app.controller(optimisticResponse: (v) => 'draft');

      final done = controller.mutate(const _NewTodo('1', 'milk'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isA<MutationPending<String, _NewTodo>>());

      storage.gate!.complete();
      expect(await done, 'draft');
      final state = controller.state as MutationSuccess<String, _NewTodo>;
      expect(state.isOptimistic, isTrue);
    });

    test('a call that cannot be stored fails instead of looking saved',
        () async {
      final storage = _Storage()..failWith = StateError('disk full');
      final app = _App(storage, online: false);
      final errors = <Object>[];
      final controller = app.controller(
        optimisticResponse: (v) => 'draft',
        onError: (e, _, __) async => errors.add(e),
      );
      final states = <MutationState<String, _NewTodo>>[];
      controller.stream.listen(states.add);

      expect(await controller.mutate(const _NewTodo('1', 'milk')), isNull);
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isA<StateError>());
      expect(controller.state, isA<MutationFailure<String, _NewTodo>>());
      expect(
        states.whereType<MutationSuccess<String, _NewTodo>>(),
        isEmpty,
        reason: 'never shown as saved',
      );
      expect(app.queue.isEmpty, isTrue);
      expect(storage.records, isEmpty);
    });

    test('the calls behind an unstored one in its scope wait for a decision',
        () async {
      final storage = _Storage()..failNext = 1;
      final app = _App(storage);

      final create = app.controller().mutate(const _NewTodo('1', 'create'));
      final update = app.controller().mutate(const _NewTodo('1', 'update'));
      await Future.wait([create, update]);

      expect(app.sent, isEmpty, reason: 'the update targets no record');
      final entry = app.queue.entries.single;
      expect(entry.variables.toString(), '1:update');
      expect(entry.status, QueuedMutationStatus.blocked);
      expect(storage.records.values.single['status'], 'blocked');
    });

    test('a sent call deletes its record', () async {
      final storage = _Storage();
      final app = _App(storage, online: false);
      await app.controller().mutate(const _NewTodo('1', 'milk'));
      expect(storage.records, hasLength(1));

      await app.goOnline();

      expect(app.sent, hasLength(1));
      expect(storage.records, isEmpty);
    });

    test('a failed attempt updates attempts and error, not the payload',
        () async {
      final storage = _Storage();
      final app = _App(storage);
      var failures = 0;
      final gate = Completer<void>();
      app.script = (v) {
        if (failures++ == 0) throw const _Timeout();
        gate.complete();
        return 'ok';
      };
      await app.controller().mutate(const _NewTodo('1', 'milk'));
      await gate.future;

      final before =
          storage.written.firstWhere((record) => record['attempts'] == 1);
      expect(before['attempts'], 1);
      expect(before['lastError'], 'Timeout');
      expect(before['variables'], {'id': '1', 'title': 'milk'});
      expect(app.sent.map((s) => s.$2).toSet(), hasLength(1));
    });

    test('a permanent failure stores the blocked status', () async {
      final storage = _Storage();
      final app = _App(storage);
      app.script = (v) => const _Rejected();

      await app.controller().mutate(const _NewTodo('1', 'milk'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final record = storage.records.values.single;
      expect(record['status'], 'blocked');
      expect(record['attempts'], 1);
      expect(record['lastError'], 'Rejected');
    });

    test('discarding a call while it is being stored leaves no record',
        () async {
      final storage = _Storage()..gate = Completer<void>();
      final app = _App(storage, online: false);
      final errors = <Object>[];
      final done = app
          .controller(onError: (e, _, __) async => errors.add(e))
          .mutate(const _NewTodo('1', 'milk'));
      await Future<void>.delayed(Duration.zero);
      expect(app.queue.entries, isEmpty, reason: 'not stored yet');

      app.queue.discardScope('todo:1');
      storage.gate!.complete();
      await done;
      await Future<void>.delayed(Duration.zero);

      expect(storage.records, isEmpty);
      expect(errors.single, isA<MutationDiscardedException>());
    });

    test('retry with variables rewrites the record under a new id', () async {
      final storage = _Storage();
      final app = _App(storage);
      app.script = (v) => const _Rejected();
      await app.controller().mutate(const _NewTodo('1', 'milk'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final oldId = app.queue.entries.single.mutationId;
      final storageKey = storage.records.keys.single;

      app.queue.retry(oldId, variables: const _NewTodo('1', 'oat milk'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final record = storage.records[storageKey]!;
      expect(record['mutationId'], isNot(oldId));
      expect(record['variables'], {'id': '1', 'title': 'oat milk'});
    });
  });

  group('after a restart', () {
    test('hydrate restores the queue and replays it under the same id',
        () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'milk'));
      final id = first.queue.entries.single.mutationId;
      first.client.dispose();
      expect(storage.records, hasLength(1), reason: 'dispose keeps records');

      final second = _App(storage, online: false);
      await second.client.hydrate();

      final entry = second.queue.entries.single;
      expect(entry.mutationId, id);
      expect(entry.scope, 'todo:1');
      expect((entry.variables! as _NewTodo).title, 'milk');
      expect(entry.status, QueuedMutationStatus.queued);

      await second.goOnline();
      expect(second.sent, [('1:milk', id)]);
      expect(storage.records, isEmpty);
    });

    test('statuses survive a restart, and held calls stay held', () async {
      final storage = _Storage();
      final first = _App(storage);
      first.script = (v) => v.title == 'update' ? 'ok' : const _Rejected();
      await first.controller().mutate(const _NewTodo('1', 'create'));
      await first.controller().mutate(const _NewTodo('1', 'update'));
      await first.controller().mutate(const _NewTodo('none', 'like'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      first.client.dispose();

      final second = _App(storage);
      await second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(
        second.queue.entries.map((e) => (e.variables.toString(), e.status)),
        [
          ('1:create', QueuedMutationStatus.blocked),
          ('1:update', QueuedMutationStatus.held),
          ('none:like', QueuedMutationStatus.failed),
        ],
      );
      expect(second.queue.entries.first.lastError, 'Rejected');
      expect(second.sent, isEmpty);
    });

    test('restored calls go before the calls made before hydrate', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'create'));
      first.client.dispose();

      final second = _App(storage, online: false);
      await second.controller().mutate(const _NewTodo('1', 'update'));
      await second.client.hydrate();
      await second.client.hydrate();

      expect(second.queue.entries.map((e) => e.variables.toString()), [
        '1:create',
        '1:update',
      ]);
      expect(storage.records, hasLength(2));

      await second.goOnline();
      expect(second.sent.map((s) => s.$1), ['1:create', '1:update']);
    });

    test('a call stored after hydrate sorts after the restored ones', () async {
      // A record written with a clock ahead of this one.
      const restoredKey = 'qora:mutation:09000000000000000000';
      final storage = _Storage();
      storage.data[restoredKey] = jsonEncode({
        'version': 1,
        'mutationId': 'm1',
        'key': 'todos.save',
        'scope': 'todo:1',
        'variables': {'id': '1', 'title': 'create'},
        'enqueuedAt': 0,
        'attempts': 0,
        'lastError': null,
        'status': 'queued',
      });

      final app = _App(storage, online: false);
      await app.client.hydrate();
      await app.controller().mutate(const _NewTodo('1', 'update'));

      final keys = storage.records.keys.toList()..sort();
      expect(keys, hasLength(2));
      expect(keys.first, restoredKey);
    });

    test('a restored call reports its outcome to mutationEvents', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'milk'));
      final id = first.queue.entries.single.mutationId;
      first.client.dispose();

      final second = _App(storage);
      second.script = (v) => const _Rejected();
      final events = <MutationUpdate>[];
      second.client.mutationEvents.listen(events.add);
      await second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(events.map((e) => (e.mutatorId, e.status)), [
        ('queue:$id', MutationStatus.pending),
        ('queue:$id', MutationStatus.error),
      ]);
      expect(events.last.error, isA<_Rejected>());
      expect(second.queue.entries.single.status, QueuedMutationStatus.blocked);
    });

    test('a replayed call runs the registered invalidations', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'milk'));
      first.client.dispose();

      final second = _App(storage, online: false);
      var fetches = 0;
      final sub = second.client.watchQuery<int>(
        key: const ['todos'],
        fetcher: () async => ++fetches,
      ).listen((_) {});
      addTearDown(sub.cancel);
      await second.goOnline();
      final before = fetches;
      await second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fetches, greaterThan(before));
    });

    test('unknown keys are kept, corrupt records deleted, app keys untouched',
        () async {
      final storage = _Storage();
      storage.data
        ..['qora:mutation:00000000000000000001'] = jsonEncode({
          'version': 1,
          'mutationId': 'x',
          'key': 'posts.like',
          'scope': null,
          'variables': 'p1',
          'enqueuedAt': 0,
          'attempts': 0,
          'lastError': null,
          'status': 'queued',
        })
        ..['qora:mutation:00000000000000000002'] = '{not json'
        ..['settings.theme'] = 'dark';

      final app = _App(storage, online: false);
      await app.client.hydrate();

      expect(app.queue.isEmpty, isTrue);
      expect(
        storage.data.keys,
        unorderedEquals([
          'qora:mutation:00000000000000000001',
          'settings.theme',
        ]),
      );
    });
  });

  group('persistence review', () {
    test('a slow onMutate keeps the call order after a restart', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      final create = first
          .controller(
            onMutate: (_) =>
                Future<void>.delayed(const Duration(milliseconds: 10)),
          )
          .mutate(const _NewTodo('1', 'create'));
      final update = first.controller().mutate(const _NewTodo('1', 'update'));
      await Future.wait([create, update]);
      first.client.dispose();

      final second = _App(storage, online: false);
      await second.client.hydrate();

      expect(second.queue.entries.map((e) => e.variables.toString()), [
        '1:create',
        '1:update',
      ]);
    });

    test('a logout during hydrate restores nothing', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'create'));
      first.client.dispose();

      final second = _App(storage);
      storage.readGate = Completer<void>();
      final hydrating = second.client.hydrate();
      await Future<void>.delayed(Duration.zero);
      await second.client.clearStorage();
      storage.readGate!.complete();
      await hydrating;
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(second.queue.isEmpty, isTrue);
      expect(second.sent, isEmpty);
      expect(storage.records, isEmpty);
    });

    test('a restored call waits for a call of its scope already in flight',
        () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'create'));
      first.client.dispose();

      final second = _App(storage);
      final gate = Completer<String>();
      var inFlight = 0;
      var maxInFlight = 0;
      second.script = (v) {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        return 'ok';
      };
      // Holds the first request so the restored one could overlap it.
      second.client.registerMutation<String, _NewTodo>(
        'todos.held',
        mutator: (v, meta) async {
          second.sent.add((v.toString(), meta.mutationId));
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          final result = await gate.future;
          inFlight--;
          return result;
        },
        variables: _todoSerializer,
        scope: (v) => 'todo:${v.id}',
      );
      unawaited(
        MutationController<String, _NewTodo, Object?>(
          options: const MutationOptions(
            mutationKey: 'todos.held',
            offlineQueue: true,
          ),
          registry: second.client.mutationRegistry,
          mutationQueue: second.client.mutationQueue,
          isOnline: () => second.client.isOnline,
        ).mutate(const _NewTodo('1', 'update')),
      );
      await Future<void>.delayed(Duration.zero);
      await second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(second.sent.map((s) => s.$1), ['1:update']);

      gate.complete('ok');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(second.sent.map((s) => s.$1), ['1:update', '1:create']);
      expect(maxInFlight, 1);
    });

    test('concurrent hydrate calls restore each call once', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'create'));
      first.client.dispose();

      final second = _App(storage, online: false);
      await Future.wait([second.client.hydrate(), second.client.hydrate()]);

      expect(second.queue.entries, hasLength(1));
    });

    test('a call removed while its delete is pending is not restored',
        () async {
      final storage = _Storage();
      final app = _App(storage, online: false);
      await app.controller().mutate(const _NewTodo('1', 'create'));
      storage.deleteGate = Completer<void>();

      app.queue.discard(app.queue.entries.single.mutationId);
      await app.client.hydrate();
      storage.deleteGate!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(app.queue.isEmpty, isTrue);
      expect(storage.records, isEmpty);
    });

    test('a record that cannot be restored holds the rest of its scope',
        () async {
      final storage = _Storage();
      Map<String, dynamic> record(String title, {int version = 1}) => {
            'version': version,
            'mutationId': title,
            'key': 'todos.save',
            'scope': 'todo:1',
            'variables': {'id': '1', 'title': title},
            'enqueuedAt': 0,
            'attempts': 0,
            'lastError': null,
            'status': 'queued',
          };
      storage.data
        ..['qora:mutation:00000000000000000001'] =
            jsonEncode(record('create', version: 2))
        ..['qora:mutation:00000000000000000002'] = jsonEncode(record('update'));

      final app = _App(storage);
      await app.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(app.sent, isEmpty);
      expect(storage.records, hasLength(2));
    });

    test('every attempt sends the stored payload, not the live object',
        () async {
      final storage = _Storage();
      final app = _App(storage, online: false);
      final input = _MutableTodo('1', 'create');
      final controller = MutationController<String, _NewTodo, Object?>(
        options: const MutationOptions(
          mutationKey: 'todos.save',
          offlineQueue: true,
        ),
        registry: app.client.mutationRegistry,
        mutationQueue: app.client.mutationQueue,
        isOnline: () => app.client.isOnline,
      );
      addTearDown(controller.dispose);
      await controller.mutate(input);

      input.title = 'changed after mutate';
      await app.goOnline();

      expect(app.sent.single.$1, '1:create');
    });

    test('an unreadable record stops the restore, and is kept', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'create'));
      first.client.dispose();
      storage.data['settings.theme'] = 'dark';

      final second = _App(storage, online: false);
      storage.failReads = true;
      await second.client.hydrate();

      expect(second.queue.isEmpty, isTrue);
      expect(storage.records, hasLength(1), reason: 'kept for a next try');
    });

    test('a retry is stored before it is sent', () async {
      final storage = _Storage();
      final app = _App(storage);
      app.script = (v) => const _Rejected();
      await app.controller().mutate(const _NewTodo('1', 'create'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final id = app.queue.entries.single.mutationId;
      app.sent.clear();
      app.script = (v) => 'ok';
      storage.gate = Completer<void>();

      app.queue.retry(id, variables: const _NewTodo('1', 'fixed'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(app.sent, isEmpty, reason: 'its record is not rewritten yet');

      storage.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(app.sent.map((s) => s.$1), ['1:fixed']);
    });

    test('a retry that cannot be stored waits for a decision again', () async {
      final storage = _Storage();
      final app = _App(storage);
      app.script = (v) => const _Rejected();
      await app.controller().mutate(const _NewTodo('1', 'create'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final id = app.queue.entries.single.mutationId;
      app.sent.clear();
      storage.failNext = 1;

      app.queue.retry(id, variables: const _NewTodo('1', 'fixed'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(app.sent, isEmpty);
      final entry = app.queue.entries.single;
      expect(entry.status, QueuedMutationStatus.blocked);
      expect(entry.lastError, isA<StateError>());
    });
  });

  group('second persistence review', () {
    // A stored query entry, so hydrate has a query phase before the queue.
    void storeQuery(_Storage storage) =>
        storage.data['["todos"]'] = jsonEncode({
          'typeName': 'X',
          'data': 1,
          'persistedAtMs': DateTime.now().millisecondsSinceEpoch,
        });

    test('a logout while hydrate reads the cache restores nothing', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'userA'));
      first.client.dispose();
      storeQuery(storage);

      final second = _App(storage);
      storage
        ..queryReadGate = Completer<void>()
        ..deleteGate = Completer<void>();
      final hydrating = second.client.hydrate();
      await Future<void>.delayed(Duration.zero);
      final clearing = second.client.clearStorage();
      await Future<void>.delayed(Duration.zero);
      storage.queryReadGate!.complete();
      await hydrating;
      storage.deleteGate!.complete();
      await clearing;
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(second.sent, isEmpty);
      expect(second.queue.isEmpty, isTrue);
    });

    test('hydrate after clear() waits for the storage to be cleared', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'userA'));
      first.client.dispose();

      final second = _App(storage);
      storage.deleteGate = Completer<void>();
      second.client.clear();
      final hydrating = second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      storage.deleteGate!.complete();
      await hydrating;
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(second.sent, isEmpty);
      expect(second.queue.isEmpty, isTrue);
    });

    test('clear() settles the queue before it empties the cache', () async {
      final storage = _Storage();
      final app = _App(storage, online: false);
      app.client.setQueryData<List<String>>(['todos'], ['userA']);
      final controller = MutationController<String, _NewTodo, List<String>?>(
        options: MutationOptions(
          mutationKey: 'todos.save',
          offlineQueue: true,
          onMutate: (v) async {
            final previous = app.client.getQueryData<List<String>>(['todos']);
            app.client.setQueryData<List<String>>(
              ['todos'],
              [...?previous, v.title],
            );
            return previous;
          },
          onError: (_, __, previous) async =>
              app.client.restoreQueryData<List<String>>(['todos'], previous),
        ),
        registry: app.client.mutationRegistry,
        mutationQueue: app.client.mutationQueue,
        isOnline: () => app.client.isOnline,
      );
      addTearDown(controller.dispose);
      await controller.mutate(const _NewTodo('1', 'milk'));

      app.client.clear();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(app.client.getQueryData<List<String>>(['todos']), isNull);
    });

    test('a discarded call whose delete fails is not restored', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'discard-me'));
      storage.failDeletes = true;
      first.queue.discard(first.queue.entries.single.mutationId);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      first.client.dispose();
      storage.failDeletes = false;

      final second = _App(storage);
      await second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(second.sent, isEmpty);
      expect(second.queue.isEmpty, isTrue);
      expect(storage.records, isEmpty, reason: 'deleted by the restore');
    });

    test('an unreadable record is never overtaken by a later one', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'create'));
      await first.controller().mutate(const _NewTodo('1', 'update'));
      first.client.dispose();
      storage.failReadOf.add((storage.records.keys.toList()..sort()).first);

      final second = _App(storage);
      await second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(second.sent, isEmpty);

      await second.client.hydrate(); // the read works this time
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(second.sent.map((s) => s.$1), ['1:create', '1:update']);
    });

    test('an unreadable query entry does not stop the queue', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'create'));
      first.client.dispose();
      storeQuery(storage);

      final second = _App(storage);
      storage.failQueryReads = true;
      await second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(second.sent.map((s) => s.$1), ['1:create']);
    });

    test('a retry with variables that cannot be stored keeps the old call',
        () async {
      final storage = _Storage();
      final app = _App(storage);
      app.script = (v) => const _Rejected();
      await app.controller().mutate(const _NewTodo('1', 'create'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final before = app.queue.entries.single;
      storage.failNext = 1;

      app.queue.retry(before.mutationId, variables: const _NewTodo('1', 'x'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final after = app.queue.entries.single;
      expect(after.mutationId, before.mutationId, reason: 'as stored');
      expect(after.variables.toString(), '1:create');
      expect(after.status, QueuedMutationStatus.blocked);
      expect(storage.records.values.single['mutationId'], before.mutationId);
    });

    test('entries show the variables that are sent', () async {
      final storage = _Storage();
      final app = _App(storage, online: false);
      final todo = _MutableTodo('1', 'milk');
      await app.controller().mutate(todo);
      todo.title = 'changed';

      expect(app.queue.entries.single.variables.toString(), '1:milk');
    });
  });

  group('third persistence review', () {
    test('a second hydrate keeps the stored order within a scope', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      for (final v in ['create', 'update', 'delete']) {
        await first.controller().mutate(_NewTodo('1', v));
      }
      first.client.dispose();
      storage.failReadOf.add((storage.records.keys.toList()..sort())[1]);

      final second = _App(storage, online: false);
      await second.client.hydrate(); // restores create, stops at update
      await second.client.hydrate(); // restores update and delete
      await second.goOnline();

      expect(
        second.sent.map((s) => s.$1),
        ['1:create', '1:update', '1:delete'],
      );
    });

    test('a clearStorage whose deletes fail restores nothing after', () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'userA'));
      first.client.dispose();

      final second = _App(storage);
      storage.failDeletes = true;
      await expectLater(second.client.clearStorage(), throwsStateError);
      storage.failDeletes = false;
      await second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(second.sent, isEmpty);
      expect(storage.records, isEmpty, reason: 'tombstone deleted');
    });

    test('a query entry that cannot be deleted does not stop the queue',
        () async {
      final storage = _Storage();
      final first = _App(storage, online: false);
      await first.controller().mutate(const _NewTodo('1', 'create'));
      first.client.dispose();
      storage
        ..data['["todos"]'] = 'not json'
        ..failQueryDeletes = true;

      final second = _App(storage);
      await second.client.hydrate();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(second.sent.map((s) => s.$1), ['1:create']);
    });

    test('a failed retry write is not undone over a later rewrite', () async {
      final storage = _Storage();
      storage.data['qora:mutation:00000000000000000001'] = jsonEncode({
        'version': 1,
        'mutationId': 'r-1',
        'key': 'todos.save',
        'scope': 'todo:1',
        'variables': {'id': '1', 'title': 'restored'},
        'enqueuedAt': 0,
        'attempts': 0,
        'status': 'queued',
      });
      final app = _App(storage, online: false);
      await app.controller().mutate(const _NewTodo('1', 'a'));
      await app.controller().mutate(const _NewTodo('1', 'b'));
      app.queue.discard(app.queue.entries.first.mutationId);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final entry = app.queue.entries.single;
      storage
        ..gate = Completer<void>()
        ..failNext = 1;

      app.queue.retry(entry.mutationId, variables: const _NewTodo('1', 'x'));
      await app.client.hydrate(); // restores r-1 ahead of it
      app.queue.discard('r-1'); // blocks it again: its record is rewritten
      storage.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final inMemory = app.queue.entries.single;
      final stored = storage.records.values.single;
      expect(stored['mutationId'], inMemory.mutationId);
      expect(inMemory.variables.toString(), '1:x');
    });

    test('a logout while hydrate reads the cache does not restore it',
        () async {
      final storage = _Storage();
      storage.data['["todos"]'] = jsonEncode({
        'typeName': 'X',
        'data': 'userA',
        'persistedAtMs': DateTime.now().millisecondsSinceEpoch,
      });
      final app = _App(storage);
      app.client.registerSerializer<String>(
        QoraSerializer<String>(toJson: (v) => v, fromJson: (j) => j as String),
        name: 'X',
      );
      storage.queryReadGate = Completer<void>();
      final hydrating = app.client.hydrate();
      await Future<void>.delayed(Duration.zero);

      app.client.clear();
      storage.queryReadGate!.complete();
      await hydrating;

      expect(app.client.getQueryData<String>(['todos']), isNull);
    });
  });

  group('logout', () {
    test('clearStorage empties the queue in memory and in storage', () async {
      final storage = _Storage();
      storage.data['settings.theme'] = 'dark';
      storage.data['qora:mutation:00000000000000000001'] = '{"version":9}';
      final app = _App(storage, online: false);
      final errors = <Object>[];
      await app
          .controller(onError: (e, _, __) async => errors.add(e))
          .mutate(const _NewTodo('1', 'milk'));

      await app.client.clearStorage();
      await Future<void>.delayed(Duration.zero);

      expect(app.queue.isEmpty, isTrue);
      expect(storage.data.keys, ['settings.theme']);
      expect(errors.single, isA<MutationDiscardedException>());

      await app.goOnline();
      expect(app.sent, isEmpty);
    });
  });
}

/// Variables an app could change after calling mutate.
class _MutableTodo implements _NewTodo {
  _MutableTodo(this.id, this.title);
  @override
  final String id;
  @override
  String title;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  @override
  String toString() => '$id:$title';
}

class _Timeout implements Exception {
  const _Timeout();
  @override
  String toString() => 'Timeout';
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

import 'dart:async';

import 'package:qora/qora.dart';
import 'package:qora/src/utils/mutation_id.dart';
import 'package:test/test.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final _stringSerializer = QoraSerializer<String>(
  toJson: (v) => v,
  fromJson: (json) => json as String,
);

/// Registers `'todos.create'` on [client], recording every call.
List<(String, MutationMeta)> _registerRecording(
  QoraClient client, {
  int failFirst = 0,
  List<Object>? invalidates,
  List<QueryTag>? invalidatesTags,
}) {
  final calls = <(String, MutationMeta)>[];
  client.registerMutation<String, String>(
    'todos.create',
    mutator: (title, meta) async {
      calls.add((title, meta));
      if (calls.length <= failFirst) throw StateError('attempt failed');
      return 'created:$title';
    },
    variables: _stringSerializer,
    invalidates: invalidates,
    invalidatesTags: invalidatesTags,
  );
  return calls;
}

MutationController<String, String, void> _controllerFor(
  QoraClient client, {
  MutationOptions<String, String, void>? options,
  Future<void> Function(Object key)? invalidateQuery,
  Future<void> Function(List<QueryTag> tags)? invalidateTags,
}) {
  final controller = MutationController<String, String, void>(
    options: options ??
        const MutationOptions<String, String, void>(
          mutationKey: 'todos.create',
        ),
    registry: client.mutationRegistry,
    invalidateQuery: invalidateQuery,
    invalidateTags: invalidateTags,
    isOnline: () => client.isOnline,
    offlineQueue: client.offlineMutationQueue,
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('generateMutationId', () {
    test('returns distinct version 4 UUIDs', () {
      final ids = List.generate(1000, (_) => generateMutationId());
      expect(ids.every(_uuidV4.hasMatch), isTrue);
      expect(ids.toSet(), hasLength(1000));
    });
  });

  group('registered mutations', () {
    late QoraClient client;

    setUp(() {
      client = QoraClient();
      addTearDown(client.dispose);
    });

    test('a call site with a mutationKey runs the registered mutator',
        () async {
      final calls = _registerRecording(client);
      final controller = _controllerFor(client);

      final result = await controller.mutate('Buy milk');

      expect(result, 'created:Buy milk');
      expect(controller.state, isA<MutationSuccess<String, String>>());
      expect(calls, hasLength(1));
      expect(calls.single.$1, 'Buy milk');
      expect(calls.single.$2.attempt, 0);
      expect(_uuidV4.hasMatch(calls.single.$2.mutationId), isTrue);
    });

    test('retries of one call share its mutationId', () async {
      final calls = _registerRecording(client, failFirst: 2);
      final controller = _controllerFor(
        client,
        options: const MutationOptions<String, String, void>(
          mutationKey: 'todos.create',
          retryCount: 2,
          retryDelay: Duration.zero,
        ),
      );

      final result = await controller.mutate('Buy milk');

      expect(result, 'created:Buy milk');
      expect(calls.map((c) => c.$2.attempt), [0, 1, 2]);
      expect(calls.map((c) => c.$2.mutationId).toSet(), hasLength(1));
    });

    test('separate calls get separate mutationIds', () async {
      final calls = _registerRecording(client);
      final controller = _controllerFor(client);

      await controller.mutate('a');
      await controller.mutate('b');

      expect(calls[0].$2.mutationId, isNot(calls[1].$2.mutationId));
    });

    test('a call queued offline replays through the registered mutator',
        () async {
      final calls = _registerRecording(client);
      final connectivity = _FakeConnectivity();
      client.attachConnectivityManager(connectivity);
      await pumpEventQueue();
      connectivity.set(NetworkStatus.offline);
      await pumpEventQueue();

      final controller = _controllerFor(
        client,
        options: const MutationOptions<String, String, void>(
          mutationKey: 'todos.create',
          offlineQueue: true,
        ),
      );

      await controller.mutate('Buy milk');
      expect(calls, isEmpty);
      expect(client.offlineMutationQueue.length, 1);

      connectivity.set(NetworkStatus.online);
      await pumpEventQueue();

      expect(calls, hasLength(1));
      expect(calls.single.$1, 'Buy milk');
      expect(_uuidV4.hasMatch(calls.single.$2.mutationId), isTrue);
      expect(controller.state, isA<MutationSuccess<String, String>>());
    });

    test('retries of a replayed call share its mutationId', () async {
      final calls = _registerRecording(client, failFirst: 1);
      final connectivity = _FakeConnectivity();
      client.attachConnectivityManager(connectivity);
      await pumpEventQueue();
      connectivity.set(NetworkStatus.offline);
      await pumpEventQueue();

      final controller = _controllerFor(
        client,
        options: const MutationOptions<String, String, void>(
          mutationKey: 'todos.create',
          offlineQueue: true,
          retryCount: 1,
          retryDelay: Duration.zero,
        ),
      );

      await controller.mutate('Buy milk');
      connectivity.set(NetworkStatus.online);
      await pumpEventQueue();

      expect(calls.map((c) => c.$2.attempt), [0, 1]);
      expect(calls.map((c) => c.$2.mutationId).toSet(), hasLength(1));
      expect(controller.state, isA<MutationSuccess<String, String>>());
    });

    test('call-site callbacks still run', () async {
      _registerRecording(client);
      String? succeededWith;
      final controller = _controllerFor(
        client,
        options: MutationOptions<String, String, void>(
          mutationKey: 'todos.create',
          onSuccess: (data, _, __) async => succeededWith = data,
        ),
      );

      await controller.mutate('Buy milk');

      expect(succeededWith, 'created:Buy milk');
    });

    test('registered invalidations run before the call site ones', () async {
      _registerRecording(
        client,
        invalidates: [
          ['todos'],
        ],
      );
      final invalidated = <Object>[];
      final controller = _controllerFor(
        client,
        options: const MutationOptions<String, String, void>(
          mutationKey: 'todos.create',
          invalidates: [
            ['stats'],
          ],
        ),
        invalidateQuery: (key) async => invalidated.add(key),
      );

      await controller.mutate('Buy milk');

      expect(invalidated, [
        ['todos'],
        ['stats'],
      ]);
    });

    test('registered tags are invalidated before the call site ones', () async {
      _registerRecording(client, invalidatesTags: [const QueryTag('todo')]);
      final invalidated = <List<QueryTag>>[];
      final controller = _controllerFor(
        client,
        options: const MutationOptions<String, String, void>(
          mutationKey: 'todos.create',
          invalidatesTags: [QueryTag('stats')],
        ),
        invalidateTags: (tags) async => invalidated.add(tags),
      );

      await controller.mutate('Buy milk');

      expect(invalidated.expand((t) => t), [
        const QueryTag('todo'),
        const QueryTag('stats'),
      ]);
    });

    test('registered invalidations do not run on failure', () async {
      _registerRecording(
        client,
        failFirst: 1,
        invalidates: [
          ['todos'],
        ],
      );
      final invalidated = <Object>[];
      final controller = _controllerFor(
        client,
        invalidateQuery: (key) async => invalidated.add(key),
      );

      await controller.mutate('Buy milk');

      expect(controller.state, isA<MutationFailure<String, String>>());
      expect(invalidated, isEmpty);
    });

    test('the mutator getter calls the registered mutator', () async {
      final calls = _registerRecording(client);
      final controller = _controllerFor(client);

      expect(await controller.mutator('direct'), 'created:direct');
      expect(calls.single.$2.attempt, 0);
    });
  });

  group('registration errors', () {
    late QoraClient client;

    setUp(() {
      client = QoraClient();
      addTearDown(client.dispose);
    });

    test('registering a key twice throws', () {
      _registerRecording(client);
      expect(() => _registerRecording(client), throwsStateError);
    });

    test('registering on a disposed client throws', () {
      final disposed = QoraClient()..dispose();
      expect(() => _registerRecording(disposed), throwsStateError);
    });

    test('a mutator and a mutationKey together throw', () {
      _registerRecording(client);
      expect(
        () => MutationController<String, String, void>(
          mutator: (v) async => v,
          options: const MutationOptions(mutationKey: 'todos.create'),
          registry: client.mutationRegistry,
        ),
        throwsArgumentError,
      );
    });

    test('neither a mutator nor a mutationKey throws', () {
      expect(
        () => MutationController<String, String, void>(),
        throwsArgumentError,
      );
    });

    test('an unregistered key throws', () {
      expect(
        () => MutationController<String, String, void>(
          options: const MutationOptions(mutationKey: 'missing'),
          registry: client.mutationRegistry,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No mutation is registered under "missing"'),
          ),
        ),
      );
    });

    test('a mutationKey without a registry throws', () {
      expect(
        () => MutationController<String, String, void>(
          options: const MutationOptions(mutationKey: 'todos.create'),
        ),
        throwsStateError,
      );
    });

    test('a key used with other types throws', () {
      _registerRecording(client);
      expect(
        () => MutationController<int, String, void>(
          options: const MutationOptions(mutationKey: 'todos.create'),
          registry: client.mutationRegistry,
        ),
        throwsStateError,
      );
    });

    test('a wider variables type throws', () {
      _registerRecording(client);
      expect(
        () => MutationController<String, Object, void>(
          options: const MutationOptions(mutationKey: 'todos.create'),
          registry: client.mutationRegistry,
        ),
        throwsStateError,
      );
    });

    test('a supertype of the data type is accepted', () async {
      _registerRecording(client);
      final controller = MutationController<Object, String, void>(
        options: const MutationOptions(mutationKey: 'todos.create'),
        registry: client.mutationRegistry,
      );
      addTearDown(controller.dispose);

      expect(await controller.mutate('Buy milk'), 'created:Buy milk');
    });

    test('the registry lists its keys in registration order', () {
      _registerRecording(client);
      client.registerMutation<void, String>(
        'todos.delete',
        mutator: (_, __) async {},
        variables: _stringSerializer,
      );

      expect(client.mutationRegistry.keys, ['todos.create', 'todos.delete']);
      expect(client.mutationRegistry.contains('todos.delete'), isTrue);
      expect(client.mutationRegistry.contains('missing'), isFalse);
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_flutter/qora_flutter.dart'
    show ConnectivityManager, MutationStatus, NetworkStatus;
import 'package:qora_hooks/qora_hooks.dart';

class _FakeConnectivity implements ConnectivityManager {
  final _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status = NetworkStatus.online;

  @override
  Stream<NetworkStatus> get statusStream => _controller.stream;

  @override
  NetworkStatus get currentStatus => _status;

  @override
  Future<void> start() async {}

  @override
  void dispose() => _controller.close();

  void set(NetworkStatus status) {
    _status = status;
    _controller.add(status);
  }
}

void main() {
  late QoraClient client;
  late _FakeConnectivity network;
  late List<String> sent;
  late MutationHandle<String, String> handle;

  Widget app({MutationOptions<String, String, void>? options}) => MaterialApp(
        home: QoraScope(
          client: client,
          child: HookBuilder(builder: (context) {
            handle = useMutation<String, String>(
              mutator: (v) async {
                sent.add(v);
                return v;
              },
              options: options,
            );
            return Text(handle.state.runtimeType.toString());
          }),
        ),
      );

  setUp(() {
    client = QoraClient();
    network = _FakeConnectivity();
    client.attachConnectivityManager(network);
    sent = [];
  });

  tearDown(() {
    network.dispose();
    client.dispose();
  });

  testWidgets('queues the call while offline and sends it on reconnect',
      (tester) async {
    await tester.pumpWidget(
      app(options: const MutationOptions(offlineQueue: true)),
    );

    network.set(NetworkStatus.offline);
    await tester.pump();

    await tester.runAsync(() => handle.mutateAsync('a'));
    await tester.pump();
    await tester.pump();
    expect(sent, isEmpty);
    expect(client.offlineMutationQueue.length, 1);
    expect(handle.isPending, isTrue);

    network.set(NetworkStatus.online);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump();

    expect(sent, ['a']);
    expect(client.offlineMutationQueue.isEmpty, isTrue);
    expect(handle.isSuccess, isTrue);
  });

  testWidgets('emits an optimistic success while queued', (tester) async {
    await tester.pumpWidget(
      app(
        options: MutationOptions(
          offlineQueue: true,
          optimisticResponse: (v) => 'draft:$v',
        ),
      ),
    );

    network.set(NetworkStatus.offline);
    await tester.pump();

    await tester.runAsync(() => handle.mutateAsync('a'));
    await tester.pump();
    await tester.pump();

    final state = handle.state;
    expect(state, isA<MutationSuccess<String, String>>());
    expect((state as MutationSuccess<String, String>).isOptimistic, isTrue);
    expect(state.data, 'draft:a');
    expect(sent, isEmpty);
  });

  testWidgets('sends immediately when offlineQueue is not set', (tester) async {
    await tester.pumpWidget(app());

    network.set(NetworkStatus.offline);
    await tester.pump();

    await tester.runAsync(() => handle.mutateAsync('a'));
    await tester.pump();
    await tester.pump();

    expect(sent, ['a']);
    expect(client.offlineMutationQueue.isEmpty, isTrue);
  });

  testWidgets('reports the mutation to the client tracker', (tester) async {
    final events = <MutationStatus>[];
    final sub = client.mutationEvents.listen((e) => events.add(e.status));
    addTearDown(sub.cancel);
    await tester.pumpWidget(app());

    await tester.runAsync(() => handle.mutateAsync('a'));
    await tester.pump();
    await tester.pump();

    expect(events,
        containsAllInOrder([MutationStatus.pending, MutationStatus.success]));
  });
}

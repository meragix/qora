import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_flutter/qora_flutter.dart'
    show MutationController, QoraSerializer;
import 'package:qora_hooks/qora_hooks.dart';

final _stringSerializer = QoraSerializer<String>(
  toJson: (v) => v,
  fromJson: (json) => json as String,
);

QoraClient _client(Completer<String> Function() reply) {
  final client = QoraClient()
    ..registerMutation<String, String>(
      'todos.create',
      mutator: (title, meta) => reply().future,
      variables: _stringSerializer,
    );
  return client;
}

Future<void> _mutate(QoraClient client, String title) {
  final controller = MutationController<String, String, void>(
    options: const MutationOptions(
      mutationKey: 'todos.create',
      offlineQueue: true,
    ),
    registry: client.mutationRegistry,
    mutationQueue: client.mutationQueue,
    isOnline: () => client.isOnline,
  );
  addTearDown(controller.dispose);
  return controller.mutate(title);
}

Widget _app(QoraClient client) => MaterialApp(
      home: QoraScope(
        client: client,
        child: HookBuilder(
          builder: (context) {
            final queue = useMutationQueue();
            return Text(
              queue.isEmpty
                  ? 'synced'
                  : queue.map((e) => '${e.variables}:${e.status.name}').join(),
            );
          },
        ),
      ),
    );

void main() {
  testWidgets('useMutationQueue rebuilds as a call is sent, then done',
      (tester) async {
    final reply = Completer<String>();
    final client = _client(() => reply);
    addTearDown(client.dispose);

    await tester.pumpWidget(_app(client));
    expect(find.text('synced'), findsOneWidget);

    unawaited(_mutate(client, 'milk'));
    await tester.pump();
    expect(find.text('milk:sending'), findsOneWidget);

    reply.complete('ok');
    await tester.pump();
    await tester.pump();
    expect(find.text('synced'), findsOneWidget);
  });

  testWidgets('useMutationQueue starts from the calls already queued',
      (tester) async {
    final client = _client(Completer<String>.new);
    addTearDown(client.dispose);
    unawaited(_mutate(client, 'milk'));
    await tester.pump();

    await tester.pumpWidget(_app(client));

    expect(find.text('milk:sending'), findsOneWidget);
  });

  testWidgets('useMutationQueue follows a new client', (tester) async {
    final first = _client(Completer<String>.new);
    final second = _client(Completer<String>.new);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    unawaited(_mutate(first, 'milk'));
    await tester.pump();
    await tester.pumpWidget(_app(first));
    expect(find.text('milk:sending'), findsOneWidget);

    await tester.pumpWidget(_app(second));

    expect(find.text('synced'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    second.dispose();
  });
}

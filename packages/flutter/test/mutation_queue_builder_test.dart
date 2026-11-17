import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_flutter/qora_flutter.dart';

final _stringSerializer = QoraSerializer<String>(
  toJson: (v) => v,
  fromJson: (json) => json as String,
);

QoraClient _client(Completer<String> Function() reply) => QoraClient()
  ..registerMutation<String, String>(
    'todos.create',
    mutator: (title, meta) => reply().future,
    variables: _stringSerializer,
  );

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

String _describe(List<QueuedMutation> entries) => entries.isEmpty
    ? 'synced'
    : entries.map((e) => '${e.variables}:${e.status.name}').join();

Widget _app(QoraClient client, {QoraClient? explicit}) => MaterialApp(
      home: QoraScope(
        client: client,
        child: MutationQueueBuilder(
          client: explicit,
          builder: (context, entries, _) => Text(_describe(entries)),
        ),
      ),
    );

void main() {
  testWidgets('rebuilds as a call is sent, then done', (tester) async {
    final reply = Completer<String>();
    final client = _client(() => reply);

    await tester.pumpWidget(_app(client));
    expect(find.text('synced'), findsOneWidget);

    unawaited(_mutate(client, 'milk'));
    await tester.pump();
    expect(find.text('milk:sending'), findsOneWidget);

    reply.complete('ok');
    await tester.pump();
    await tester.pump();
    expect(find.text('synced'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('starts from the calls already queued', (tester) async {
    final client = _client(Completer<String>.new);
    unawaited(_mutate(client, 'milk'));
    await tester.pump();

    await tester.pumpWidget(_app(client));

    expect(find.text('milk:sending'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('follows a new scope client, and an explicit client',
      (tester) async {
    final first = _client(Completer<String>.new);
    final second = _client(Completer<String>.new);
    unawaited(_mutate(first, 'milk'));
    await tester.pump();
    await tester.pumpWidget(_app(first));
    expect(find.text('milk:sending'), findsOneWidget);

    await tester.pumpWidget(_app(second));
    expect(find.text('synced'), findsOneWidget);

    await tester.pumpWidget(_app(second, explicit: first));
    expect(find.text('milk:sending'), findsOneWidget);

    // The old subscription is gone: a change in second does not rebuild.
    unawaited(_mutate(second, 'eggs'));
    await tester.pump();
    await tester.pump();
    expect(second.mutationQueue.entries, hasLength(1));
    expect(find.text('milk:sending'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    first.dispose();
    second.dispose();
  });

  testWidgets('passes child through unchanged', (tester) async {
    final client = _client(Completer<String>.new);
    const child = Text('child');
    await tester.pumpWidget(
      MaterialApp(
        home: QoraScope(
          client: client,
          child: MutationQueueBuilder(
            builder: (context, entries, child) => child!,
            child: child,
          ),
        ),
      ),
    );

    expect(find.text('child'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });
}

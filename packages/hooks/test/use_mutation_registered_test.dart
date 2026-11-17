import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_flutter/qora_flutter.dart'
    show MutationMeta, QoraSerializer, QueuedMutationStatus;
import 'package:qora_hooks/qora_hooks.dart';

final _stringSerializer = QoraSerializer<String>(
  toJson: (v) => v,
  fromJson: (json) => json as String,
);

void main() {
  late QoraClient client;
  late List<MutationMeta> metas;
  late MutationHandle<String, String> handle;

  setUp(() {
    client = QoraClient();
    metas = [];
    client.registerMutation<String, String>(
      'todos.create',
      mutator: (title, meta) async {
        metas.add(meta);
        return 'created:$title';
      },
      variables: _stringSerializer,
    );
  });

  tearDown(() => client.dispose());

  testWidgets('useMutation runs the registered mutator without a mutator',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QoraScope(
          client: client,
          child: HookBuilder(
            builder: (context) {
              handle = useMutation<String, String>(
                options: const MutationOptions(mutationKey: 'todos.create'),
              );
              return Text(handle.state.dataOrNull ?? 'none');
            },
          ),
        ),
      ),
    );

    await tester.runAsync(() => handle.mutateAsync('milk'));
    await tester.pump();

    expect(find.text('created:milk'), findsOneWidget);
    expect(metas, hasLength(1));
  });

  testWidgets('a mutator dropped after the first build fails clearly',
      (tester) async {
    Object? error;
    Widget build({required bool withMutator}) => MaterialApp(
          home: QoraScope(
            client: client,
            child: HookBuilder(
              builder: (context) {
                handle = useMutation<String, String>(
                  mutator: withMutator ? (title) async => title : null,
                  options: MutationOptions(
                    onError: (e, _, __) async => error = e,
                  ),
                );
                return const SizedBox();
              },
            ),
          ),
        );

    await tester.pumpWidget(build(withMutator: true));
    await tester.pumpWidget(build(withMutator: false));

    await tester.runAsync(() => handle.mutateAsync('milk'));

    expect(
      error,
      isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('first built with a mutator'),
      ),
    );
  });

  testWidgets('useMutation sends offlineQueue calls through the queue',
      (tester) async {
    final gate = Completer<String>();
    client.registerMutation<String, String>(
      'todos.slow',
      mutator: (title, meta) => gate.future,
      variables: _stringSerializer,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QoraScope(
          client: client,
          child: HookBuilder(
            builder: (context) {
              handle = useMutation<String, String>(
                options: const MutationOptions(
                  mutationKey: 'todos.slow',
                  offlineQueue: true,
                ),
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    handle.mutate('milk');
    await tester.pump();
    expect(client.mutationQueue.entries.single.status,
        QueuedMutationStatus.sending);

    gate.complete('done');
    await tester.pump();
    expect(client.mutationQueue.isEmpty, isTrue);
  });
}

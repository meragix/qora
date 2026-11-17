import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora/qora.dart';
import 'package:qora_devtools_overlay/qora_devtools_overlay.dart';

class _Todo {
  const _Todo(this.title);
  final String title;
  Map<String, Object?> toJson() => {'title': title};
}

void main() {
  late OverlayTracker tracker;
  late QoraClient client;

  setUp(() {
    tracker = OverlayTracker();
    client = QoraClient(tracker: tracker);
    client.registerMutation<void, _Todo>(
      'todos.save',
      mutator: (todo, meta) async => throw StateError('refused by server'),
      variables: QoraSerializer(
        toJson: (todo) => todo.toJson(),
        fromJson: (json) => _Todo((json as Map)['title'] as String),
      ),
      isPermanent: (_) => true,
    );
  });

  tearDown(() => client.dispose());

  Future<void> openPanel(WidgetTester tester, {QoraClient? withClient}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QoraInspector(
      tracker: tracker,
      client: withClient,
      child: const SizedBox.expand(),
    ));
    await tester.tap(find.text('Q'));
    await tester.pumpAndSettle();
  }

  Future<void> queueRefusedTodo(WidgetTester tester) async {
    final controller = MutationController<void, _Todo, void>(
      options: const MutationOptions(
        mutationKey: 'todos.save',
        offlineQueue: true,
      ),
      registry: client.mutationRegistry,
      mutationQueue: client.mutationQueue,
      tracker: client,
    );
    addTearDown(controller.dispose);
    await tester.runAsync(() => controller.mutate(const _Todo('Buy milk')));
    await tester.pumpAndSettle();
  }

  testWidgets('the Queue tab lists a failed call with its error',
      (tester) async {
    await openPanel(tester, withClient: client);
    await queueRefusedTodo(tester);

    await tester.tap(find.text('QUEUE'));
    await tester.pumpAndSettle();
    expect(find.text('todos.save'), findsOneWidget);
    expect(find.textContaining('failed'), findsOneWidget);

    await tester.tap(find.text('todos.save'));
    await tester.pumpAndSettle();
    expect(find.text('QUEUE INSPECTOR'), findsOneWidget);
    expect(find.text('LAST ERROR'), findsOneWidget);
    expect(find.textContaining('refused by server'), findsWidgets);
    expect(find.textContaining('Buy milk'), findsOneWidget);
    expect(find.text(client.mutationQueue.entries.single.mutationId),
        findsOneWidget);
  });

  testWidgets('a call that leaves the queue says so in the inspector',
      (tester) async {
    await openPanel(tester, withClient: client);
    await queueRefusedTodo(tester);
    await tester.tap(find.text('QUEUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('todos.save'));
    await tester.pumpAndSettle();

    client.mutationQueue
        .discard(client.mutationQueue.entries.single.mutationId);
    await tester.pumpAndSettle();

    expect(find.textContaining('This call left the queue'), findsOneWidget);
  });

  testWidgets('without a client, the Queue tab says how to enable it',
      (tester) async {
    await openPanel(tester);
    await tester.tap(find.text('QUEUE'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pass client:'), findsOneWidget);
  });

  testWidgets('no action or tab that does nothing is shown', (tester) async {
    await openPanel(tester, withClient: client);
    tracker.onQueryFetched('["todos"]', ['a'], 'success');
    tracker.onMutationStarted('m1', '["todos"]', null);
    tracker.onMutationStarted('m2', '["users"]', null);
    // 0.3.0 showed Retry on a failed mutation, Pause and Cancel on a
    // pending one.
    tracker.onMutationSettled('m2', false, 'refused');
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('todos').first);
    await tester.pumpAndSettle();
    expect(find.text('Invalidate'), findsOneWidget);
    expect(find.text('Refetch'), findsNothing);
    expect(find.text('Is Invalidated:'), findsNothing);

    await tester.tap(find.text('MUTATIONS'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('users').first);
    await tester.pumpAndSettle();
    expect(find.text('MUTATION INSPECTOR'), findsOneWidget);
    expect(find.text('ERROR'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    await tester.tap(find.textContaining('todos').first);
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Retry Count'), findsNothing);

    expect(find.text('WIDGET TREE'), findsNothing);
    expect(find.text('DATA DIFF'), findsNothing);
  });
}

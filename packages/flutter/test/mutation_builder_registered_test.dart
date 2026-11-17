import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_flutter/qora_flutter.dart';

final _stringSerializer = QoraSerializer<String>(
  toJson: (v) => v,
  fromJson: (json) => json as String,
);

void main() {
  group('QoraMutationBuilder with a registered mutation', () {
    late QoraClient client;
    late List<MutationMeta> metas;

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

    testWidgets('runs the registered mutator when no mutator is passed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QoraScope(
            client: client,
            child: QoraMutationBuilder<String, String, void>(
              options: const MutationOptions(mutationKey: 'todos.create'),
              builder: (context, state, mutate) => Column(
                children: [
                  TextButton(
                    onPressed: () => mutate('milk'),
                    child: const Text('submit'),
                  ),
                  Text(state.dataOrNull ?? 'none'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('submit'));
      await tester.pumpAndSettle();

      expect(find.text('created:milk'), findsOneWidget);
      expect(metas, hasLength(1));
      expect(metas.single.attempt, 0);
    });

    testWidgets('throws when the key is not registered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QoraScope(
            client: client,
            child: QoraMutationBuilder<String, String, void>(
              options: const MutationOptions(mutationKey: 'missing'),
              builder: (context, state, mutate) => const SizedBox(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('throws when given both a mutator and a key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QoraScope(
            client: client,
            child: QoraMutationBuilder<String, String, void>(
              mutator: (title) async => title,
              options: const MutationOptions(mutationKey: 'todos.create'),
              builder: (context, state, mutate) => const SizedBox(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isA<ArgumentError>());
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_hooks/qora_hooks.dart';

Widget _app(QoraClient client, Widget child) => MaterialApp(
      home: QoraScope(client: client, child: child),
    );

void main() {
  group('useQuery select', () {
    testWidgets('skips rebuilds while the selected value is unchanged',
        (tester) async {
      final client = QoraClient();
      client.setQueryData<List<String>>(const ['items'], ['a', 'b']);
      var builds = 0;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            builds++;
            final state = useQuery<List<String>>(
              key: const ['items'],
              options: const QoraOptions(staleTime: Duration(minutes: 5)),
              fetcher: () async => ['a', 'b'],
              select: (items) => items.length,
            );
            return Text(state.dataOrNull?.join() ?? '-');
          }),
        ),
      );
      await tester.pumpAndSettle();
      final before = builds;

      client.setQueryData<List<String>>(const ['items'], ['x', 'y']);
      await tester.pumpAndSettle();
      expect(builds, before);

      client.setQueryData<List<String>>(const ['items'], ['x', 'y', 'z']);
      await tester.pumpAndSettle();
      expect(builds, before + 1);
      expect(find.text('xyz'), findsOneWidget);
    });

    testWidgets('a Failure with the same selected value still rebuilds',
        (tester) async {
      final client = QoraClient();
      var fail = false;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            final state = useQuery<List<String>>(
              key: const ['items'],
              options: const QoraOptions(retryCount: 0),
              fetcher: () async {
                if (fail) throw StateError('boom');
                return ['a', 'b'];
              },
              select: (items) => items.length,
            );
            return Text(state is Failure<List<String>> ? 'failure' : 'ok');
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ok'), findsOneWidget);

      fail = true;
      client.invalidate(const ['items']);
      await tester.pumpAndSettle();

      expect(find.text('failure'), findsOneWidget);
    });
  });
}

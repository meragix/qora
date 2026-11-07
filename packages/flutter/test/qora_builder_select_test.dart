import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_flutter/qora_flutter.dart';

Widget _wrap({required Widget child, QoraClient? client}) {
  return MaterialApp(
    home: QoraScope(
      client: client ?? QoraClient(),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('QoraBuilder select', () {
    testWidgets('rebuilds only when selected value changes', (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);
      var buildCount = 0;

      client.setQueryData<List<String>>(['items'], ['a', 'b']);

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraBuilder<List<String>>(
            queryKey: ['items'],
            fetcher: () async => ['a', 'b'],
            select: (items) => items.length,
            builder: (context, state, fetchStatus) {
              buildCount++;
              return Text('len:${state.dataOrNull?.length ?? 0}');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      final prev = buildCount;

      client.setQueryData<List<String>>(['items'], ['x', 'y']);
      await tester.pumpAndSettle();
      expect(buildCount, equals(prev),
          reason: 'same selected value should skip rebuild');

      client.setQueryData<List<String>>(['items'], ['a', 'b', 'c']);
      await tester.pumpAndSettle();
      expect(buildCount, equals(prev + 1),
          reason: 'different selected value should trigger rebuild');
    });

    testWidgets('select handles null data gracefully', (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);

      client.setQueryData<List<String>>(['items'], []);

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraBuilder<List<String>>(
            queryKey: ['items'],
            fetcher: () async => [],
            select: (items) => items.length,
            builder: (context, state, fetchStatus) {
              return Text('len:${state.dataOrNull?.length ?? -1}');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('len:0'), findsOneWidget);
    });

    testWidgets('a Failure with the same selected value still rebuilds',
        (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);
      var fail = false;

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraBuilder<List<String>>(
            queryKey: ['items'],
            options: const QoraOptions(retryCount: 0),
            fetcher: () async {
              if (fail) throw StateError('boom');
              return ['a', 'b'];
            },
            select: (items) => items.length,
            builder: (context, state, _) => Text(
              state is Failure<List<String>> ? 'failure' : 'ok',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ok'), findsOneWidget);

      fail = true;
      client.invalidate(['items']);
      await tester.pumpAndSettle();

      expect(find.text('failure'), findsOneWidget);
    });

    testWidgets('a skipped rebuild never leaves stale data behind',
        (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);
      client.setQueryData<List<String>>(['items'], ['a', 'b']);
      late StateSetter rebuildParent;

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: StatefulBuilder(builder: (context, setState) {
            rebuildParent = setState;
            return QoraBuilder<List<String>>(
              queryKey: ['items'],
              options: const QoraOptions(staleTime: Duration(minutes: 5)),
              fetcher: () async => ['a', 'b'],
              select: (items) => items.length,
              builder: (context, state, _) =>
                  Text(state.dataOrNull?.join() ?? '-'),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ab'), findsOneWidget);

      client.setQueryData<List<String>>(['items'], ['x', 'y']);
      await tester.pumpAndSettle();
      expect(find.text('ab'), findsOneWidget, reason: 'same length: skipped');

      rebuildParent(() {});
      await tester.pump();
      expect(find.text('xy'), findsOneWidget,
          reason: 'the next rebuild must show the latest data');
    });
  });
}

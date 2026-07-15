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
  });
}

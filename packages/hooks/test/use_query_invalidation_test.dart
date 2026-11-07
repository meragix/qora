import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_hooks/qora_hooks.dart';

Widget _app(QoraClient client, Widget child) => MaterialApp(
      home: QoraScope(client: client, child: child),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  group('useQuery invalidation', () {
    testWidgets('refetches after invalidate instead of staying in Loading',
        (tester) async {
      final client = QoraClient();
      var calls = 0;

      await tester.pumpWidget(
        _app(
          client,
          HookBuilder(builder: (context) {
            final state = useQuery<String>(
              key: const ['k'],
              fetcher: () async => 'v${++calls}',
            );
            return Text(state.dataOrNull ?? '-');
          }),
        ),
      );
      await _settle(tester);
      expect(find.text('v1'), findsOneWidget);

      client.invalidate(const ['k']);
      await _settle(tester);

      expect(calls, 2);
      expect(find.text('v2'), findsOneWidget);
    });

    testWidgets('invalidation refetch uses the latest fetcher closure',
        (tester) async {
      final client = QoraClient();
      var version = 'a';
      late StateSetter rebuild;

      await tester.pumpWidget(
        _app(
          client,
          StatefulBuilder(builder: (context, setState) {
            rebuild = setState;
            final captured = version;
            return HookBuilder(builder: (context) {
              final state = useQuery<String>(
                key: const ['k'],
                fetcher: () async => captured,
              );
              return Text(state.dataOrNull ?? '-');
            });
          }),
        ),
      );
      await _settle(tester);
      expect(find.text('a'), findsOneWidget);

      rebuild(() => version = 'b');
      await _settle(tester);
      client.invalidate(const ['k']);
      await _settle(tester);

      expect(find.text('b'), findsOneWidget);
    });
  });
}

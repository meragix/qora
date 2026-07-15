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
  group('QoraBuilder with initialData', () {
    testWidgets('initialData marked fresh shows data without loading',
        (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraBuilder<String>(
            queryKey: ['fresh-seed'],
            fetcher: () async => 'network',
            options: QoraOptions(
              initialData: 'pre-seeded',
              initialDataUpdatedAt: DateTime.now(),
              staleTime: const Duration(minutes: 5),
            ),
            builder: (context, state, fetchStatus) {
              if (state is Success<String>) {
                return Text(state.data);
              }
              return Text(state.runtimeType.toString());
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('pre-seeded'), findsOneWidget,
          reason: 'Fresh initialData should show data on first render');
      expect(find.text('Loading<String>'), findsNothing);
    });

    testWidgets('initialData marked fresh skips the network', (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);

      var fetchCount = 0;

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraBuilder<String>(
            queryKey: ['fresh-seed'],
            fetcher: () async {
              fetchCount++;
              return 'network';
            },
            options: QoraOptions(
              initialData: 'fresh-cached',
              initialDataUpdatedAt: DateTime.now(),
              staleTime: const Duration(minutes: 5),
            ),
            builder: (context, state, fetchStatus) {
              return Text(state.dataOrNull ?? 'null');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('fresh-cached'), findsOneWidget);
      expect(fetchCount, 0,
          reason: 'fresh initialData should skip the network');
    });
  });
}

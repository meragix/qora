import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_hooks/qora_hooks.dart';

Widget _app(QoraClient client, Widget child) => MaterialApp(
      home: QoraScope(client: client, child: child),
    );

void main() {
  testWidgets('useFetchStatus follows fetching then idle', (tester) async {
    final client = QoraClient();
    final seen = <FetchStatus>[];

    await tester.pumpWidget(
      _app(
        client,
        HookBuilder(builder: (context) {
          useQuery<String>(
            key: const ['k'],
            fetcher: () async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return 'v';
            },
          );
          final status = useFetchStatus(const ['k']);
          if (seen.isEmpty || seen.last != status) seen.add(status);
          return Text(status.name);
        }),
      ),
    );

    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('fetching'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('idle'), findsOneWidget);
    expect(seen, containsAllInOrder([FetchStatus.fetching, FetchStatus.idle]));
  });

  testWidgets('useFetchStatus is scoped to its key', (tester) async {
    final client = QoraClient();

    await tester.pumpWidget(
      _app(
        client,
        HookBuilder(builder: (context) {
          useQuery<String>(
            key: const ['a'],
            fetcher: () async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return 'v';
            },
          );
          return Text(useFetchStatus(const ['b']).name);
        }),
      ),
    );

    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('idle'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
  });
}

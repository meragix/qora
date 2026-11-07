import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_flutter/qora_flutter.dart';

Widget _app(QoraClient client, Widget child) => MaterialApp(
      home: QoraScope(client: client, child: child),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

String _label<T>(QoraState<T> state) => switch (state) {
      Initial() => 'initial',
      Loading(:final previousData) => 'loading:$previousData',
      Success(:final data) => 'success:$data',
      Failure(:final previousData) => 'failure:$previousData',
    };

void main() {
  group('QoraBuilder lifecycle', () {
    testWidgets('renders cached data on the very first frame', (tester) async {
      final client = QoraClient();
      client.setQueryData<String>(['k'], 'cached');

      await tester.pumpWidget(
        _app(
          client,
          QoraBuilder<String>(
            queryKey: ['k'],
            fetcher: () async => 'cached',
            builder: (_, state, __) => Text(_label(state)),
          ),
        ),
      );

      // No extra pump: first frame only.
      expect(find.text('success:cached'), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('refetches after invalidate and shows fresh data',
        (tester) async {
      final client = QoraClient();
      var calls = 0;

      await tester.pumpWidget(
        _app(
          client,
          QoraBuilder<String>(
            queryKey: ['k'],
            fetcher: () async => 'v${++calls}',
            builder: (_, state, __) => Text(_label(state)),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('success:v1'), findsOneWidget);

      client.invalidate(['k']);
      await _settle(tester);

      expect(calls, 2);
      expect(find.text('success:v2'), findsOneWidget);
    });

    testWidgets(
        'fetcher failing synchronously after invalidate runs once and '
        'surfaces Failure (no refetch loop)', (tester) async {
      final client = QoraClient();
      var calls = 0;
      var fail = false;

      await tester.pumpWidget(
        _app(
          client,
          QoraBuilder<String>(
            queryKey: ['k'],
            options: const QoraOptions(retryCount: 0),
            fetcher: () async {
              calls++;
              if (fail) throw StateError('no token');
              return 'ok';
            },
            builder: (_, state, __) => Text(_label(state)),
          ),
        ),
      );
      await _settle(tester);
      final before = calls;

      fail = true;
      client.invalidate(['k']);
      await _settle(tester);

      expect(calls - before, 1);
      expect(find.text('failure:ok'), findsOneWidget);
    });

    testWidgets('parent rebuild with an equal key does not refetch',
        (tester) async {
      final client = QoraClient();
      var calls = 0;
      late StateSetter rebuildParent;

      await tester.pumpWidget(
        _app(
          client,
          StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return QoraBuilder<String>(
                // New list instance on every build, same content.
                queryKey: ['users', 1],
                fetcher: () async => 'v${++calls}',
                builder: (_, state, __) => Text(_label(state)),
              );
            },
          ),
        ),
      );
      await _settle(tester);
      expect(calls, 1);

      for (var i = 0; i < 3; i++) {
        rebuildParent(() {});
        await _settle(tester);
      }

      expect(calls, 1, reason: 'staleTime is zero: a resubscribe would fetch');
    });

    testWidgets('key change fetches the new key', (tester) async {
      final client = QoraClient();
      var id = 1;
      late StateSetter rebuildParent;

      await tester.pumpWidget(
        _app(
          client,
          StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              final current = id;
              return QoraBuilder<String>(
                queryKey: ['users', current],
                fetcher: () async => 'user$current',
                builder: (_, state, __) => Text(_label(state)),
              );
            },
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('success:user1'), findsOneWidget);

      rebuildParent(() => id = 2);
      await _settle(tester);
      expect(find.text('success:user2'), findsOneWidget);
    });

    testWidgets('enabled: false does not fetch; enabling it does',
        (tester) async {
      final client = QoraClient();
      var calls = 0;
      var enabled = false;
      late StateSetter rebuildParent;

      await tester.pumpWidget(
        _app(
          client,
          StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return QoraBuilder<String>(
                queryKey: ['k'],
                enabled: enabled,
                fetcher: () async => 'v${++calls}',
                builder: (_, state, __) => Text(_label(state)),
              );
            },
          ),
        ),
      );
      await _settle(tester);
      expect(calls, 0);
      expect(find.text('initial'), findsOneWidget);

      rebuildParent(() => enabled = true);
      await _settle(tester);
      expect(calls, 1);
      expect(find.text('success:v1'), findsOneWidget);
    });

    testWidgets('refetchOnMount: false skips the mount fetch for cached data',
        (tester) async {
      final client = QoraClient();
      client.setQueryData<String>(['k'], 'cached');
      var calls = 0;

      await tester.pumpWidget(
        _app(
          client,
          QoraBuilder<String>(
            queryKey: ['k'],
            options: const QoraOptions(refetchOnMount: false),
            fetcher: () async => 'v${++calls}',
            builder: (_, state, __) => Text(_label(state)),
          ),
        ),
      );
      await _settle(tester);

      expect(calls, 0);
      expect(find.text('success:cached'), findsOneWidget);
    });

    testWidgets('invalidation refetch uses the latest fetcher closure',
        (tester) async {
      final client = QoraClient();
      var version = 'a';
      late StateSetter rebuildParent;

      await tester.pumpWidget(
        _app(
          client,
          StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              final captured = version;
              return QoraBuilder<String>(
                queryKey: ['k'],
                fetcher: () async => captured,
                builder: (_, state, __) => Text(_label(state)),
              );
            },
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('success:a'), findsOneWidget);

      rebuildParent(() => version = 'b');
      await _settle(tester);
      client.invalidate(['k']);
      await _settle(tester);

      expect(find.text('success:b'), findsOneWidget);
    });
  });

  group('QoraStateBuilder', () {
    testWidgets('renders cached data on the very first frame', (tester) async {
      final client = QoraClient();
      client.setQueryData<String>(['k'], 'cached');

      await tester.pumpWidget(
        _app(
          client,
          QoraStateBuilder<String>(
            queryKey: ['k'],
            builder: (_, state) => Text(_label(state)),
          ),
        ),
      );

      expect(find.text('success:cached'), findsOneWidget);
      await _settle(tester);
    });
  });
}

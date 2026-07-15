import 'dart:async';

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
  group('QoraBuilder isValidating / isLoading', () {
    testWidgets('isLoading is true on first fetch, isValidating is false',
        (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);

      final completer = Completer<String>();

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraBuilder<String>(
            queryKey: ['test'],
            fetcher: () => completer.future,
            builder: (context, state, fetchStatus) {
              return Text(
                state.isValidating ? 'validating' : 'loading',
              );
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('loading'), findsOneWidget);
      expect(find.text('validating'), findsNothing);

      completer.complete('data');
      await tester.pumpAndSettle();
    });

    testWidgets('isValidating is true on background refetch with stale data',
        (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);

      client.setQueryData<String>(['test'], 'cached');

      final completer = Completer<String>();

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraBuilder<String>(
            queryKey: ['test'],
            fetcher: () => completer.future,
            builder: (context, state, fetchStatus) {
              if (state.isValidating) return const Text('validating');
              if (state.isSuccess) {
                return Text((state as Success<String>).data);
              }
              return const Text('other');
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('validating'), findsOneWidget,
          reason: 'Should be validating on background refetch');

      completer.complete('fresh');
      await tester.pumpAndSettle();
    });

    testWidgets('isLoading remains true during background refetch',
        (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);

      client.setQueryData<String>(['test'], 'cached');

      final completer = Completer<String>();

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraBuilder<String>(
            queryKey: ['test'],
            fetcher: () => completer.future,
            builder: (context, state, fetchStatus) {
              return Text(
                  'loading=${state.isLoading} validating=${state.isValidating}');
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('loading=true validating=true'), findsOneWidget);

      completer.complete('fresh');
      await tester.pumpAndSettle();
    });

    testWidgets('returns false for non-Loading states', (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);

      client.setQueryData<String>(['test'], 'cached');

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraBuilder<String>(
            queryKey: ['test'],
            fetcher: () async => 'fresh',
            builder: (context, state, fetchStatus) {
              return Text(
                'loading=${state.isLoading} validating=${state.isValidating} success=${state.isSuccess}',
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('loading=false validating=false success=true'),
          findsOneWidget);
    });

    testWidgets('QoraStateBuilder exposes isValidating', (tester) async {
      final client = QoraClient();
      addTearDown(client.dispose);

      client.setQueryData<String>(['test'], 'cached');

      await tester.pumpWidget(
        _wrap(
          client: client,
          child: QoraStateBuilder<String>(
            queryKey: ['test'],
            builder: (context, state) {
              return Text('validating=${state.isValidating}');
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('validating=false'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_flutter/qora_flutter.dart';

Widget _wrapAuto({
  bool enableLifecycle = true,
  bool enableConnectivity = true,
  QoraClient? client,
  required Widget child,
}) {
  return MaterialApp(
    home: QoraScope.auto(
      client: client ?? QoraClient(),
      enableLifecycle: enableLifecycle,
      enableConnectivity: enableConnectivity,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('QoraScope.auto', () {
    testWidgets('provides QoraClient to descendants', (tester) async {
      await tester.pumpWidget(
        _wrapAuto(
          child: Builder(
            builder: (context) {
              QoraScope.of(context);
              return const Text('ok');
            },
          ),
        ),
      );

      expect(find.text('ok'), findsOneWidget);
    });

    testWidgets('binds connectivityManager when enableConnectivity is true',
        (tester) async {
      await tester.pumpWidget(
        _wrapAuto(
          enableConnectivity: true,
          child: Builder(
            builder: (context) {
              final cm = QoraScope.connectivityManagerOf(context);
              return Text(cm != null ? 'bound' : 'null');
            },
          ),
        ),
      );

      expect(find.text('bound'), findsOneWidget);
    });

    testWidgets(
        'does not bind connectivityManager when enableConnectivity is false',
        (tester) async {
      await tester.pumpWidget(
        _wrapAuto(
          enableConnectivity: false,
          child: Builder(
            builder: (context) {
              final cm = QoraScope.connectivityManagerOf(context);
              return Text(cm == null ? 'null' : 'bound');
            },
          ),
        ),
      );

      expect(find.text('null'), findsOneWidget);
    });

    testWidgets('renders without error when both managers are enabled',
        (tester) async {
      await tester.pumpWidget(
        _wrapAuto(
          enableLifecycle: true,
          enableConnectivity: true,
          child: const Text('rendered'),
        ),
      );

      expect(find.text('rendered'), findsOneWidget);
    });

    testWidgets('renders without error when all managers are disabled',
        (tester) async {
      await tester.pumpWidget(
        _wrapAuto(
          enableLifecycle: false,
          enableConnectivity: false,
          child: const Text('rendered'),
        ),
      );

      expect(find.text('rendered'), findsOneWidget);
    });

    testWidgets('auto() is a drop-in replacement for manual wiring',
        (tester) async {
      final client = QoraClient(
        config: const QoraClientConfig(debugMode: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QoraScope.auto(
            client: client,
            enableConnectivity: false,
            child: Builder(
              builder: (context) {
                final resolved = QoraScope.of(context);
                return Text(identical(resolved, client) ? 'match' : 'diff');
              },
            ),
          ),
        ),
      );

      expect(find.text('match'), findsOneWidget);
    });
  });

  group('QoraScope manual wiring (backward compat)', () {
    testWidgets('provides QoraClient to descendants', (tester) async {
      final client = QoraClient();

      await tester.pumpWidget(
        MaterialApp(
          home: QoraScope(
            client: client,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  final resolved = QoraScope.of(context);
                  return Text(identical(resolved, client) ? 'match' : 'diff');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('match'), findsOneWidget);
    });

    testWidgets('maybeOf returns null without QoraScope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final client = QoraScope.maybeOf(context);
              return Text(client == null ? 'null' : 'present');
            },
          ),
        ),
      );

      expect(find.text('null'), findsOneWidget);
    });

    testWidgets('of throws FlutterError without QoraScope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              try {
                QoraScope.of(context);
                return const Text('no error');
              } on FlutterError {
                return const Text('error');
              }
            },
          ),
        ),
      );

      expect(find.text('error'), findsOneWidget);
    });
  });
}

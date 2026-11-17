import 'package:ex_04_offline_first/features/todos/data/todo_api.dart';
import 'package:ex_04_offline_first/main.dart';
import 'package:ex_04_offline_first/shared/connectivity/simulated_connectivity_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_flutter/qora_flutter.dart';

/// Longer than one API round trip.
const _roundTrip = Duration(milliseconds: 700);

class _Device {
  final storage = InMemoryStorageAdapter();
  final network = SimulatedNetwork();
  late final api = TodoApi(network);

  Widget get app =>
      OfflineTodoApp(storage: storage, network: network, api: api);
}

extension on WidgetTester {
  Future<void> settle([Duration duration = _roundTrip]) async {
    for (var i = 0; i < 5; i++) {
      await pump(duration ~/ 5);
    }
  }

  Future<void> start(_Device device) async {
    await device.storage.init();
    await pumpWidget(device.app);
    await pump(); // client hydrated, QoraScope mounted, first fetch sent
    await settle();
  }

  Future<void> addTodo(String title) async {
    await tap(find.text('Add Todo'));
    await pump();
    await enterText(find.byType(TextField), title);
    await tap(find.text('Add'));
    await pump();
  }

  Future<void> toggleNetwork() async {
    final goOnline = find.byTooltip('Go online');
    await tap(
      goOnline.evaluate().isEmpty
          ? find.byTooltip('Simulate offline')
          : goOnline,
    );
    await pump();
  }

  Future<void> restart() async {
    await tap(find.byIcon(Icons.restart_alt));
    await pump(); // old client disposed with its QoraScope
    await pump(); // new client hydrated
    await settle();
  }

  Future<void> shutDown() async {
    await pumpWidget(const SizedBox());
  }
}

Finder _pending(String title) => find.descendant(
  of: find.widgetWithText(ListTile, title),
  matching: find.byKey(const ValueKey('pending')),
);

Finder _needsAttention(String title) => find.descendant(
  of: find.widgetWithText(ListTile, title),
  matching: find.byKey(const ValueKey('needsAttention')),
);

void main() {
  testWidgets('a todo created offline survives a restart, then syncs', (
    tester,
  ) async {
    final device = _Device();
    await tester.start(device);
    expect(find.text('Buy groceries'), findsOneWidget);

    await tester.toggleNetwork(); // offline
    await tester.addTodo('Buy milk');
    await tester.settle();
    expect(_pending('Buy milk'), findsOneWidget);

    await tester.restart();
    expect(_pending('Buy milk'), findsOneWidget);
    expect(
      device.api.serverTodos.map((t) => t.title),
      isNot(contains('Buy milk')),
    );

    await tester.toggleNetwork(); // online
    await tester.settle();
    await tester.settle();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(_pending('Buy milk'), findsNothing);
    expect(device.api.serverTodos.map((t) => t.title), contains('Buy milk'));
    await tester.shutDown();
  });

  testWidgets('a write killed in flight is sent again and applied once', (
    tester,
  ) async {
    final device = _Device();
    await tester.start(device);

    await tester.addTodo('Call mom');
    await tester.pump(const Duration(milliseconds: 100)); // request in flight
    await tester.restart(); // the server still applies the first request
    await tester.settle();

    expect(find.text('Call mom'), findsOneWidget);
    expect(_pending('Call mom'), findsNothing);
    final titles = device.api.serverTodos.map((t) => t.title);
    expect(titles.where((t) => t == 'Call mom'), hasLength(1));
    await tester.shutDown();
  });

  testWidgets('a refused write waits for a decision, and discard drops it', (
    tester,
  ) async {
    final device = _Device();
    await tester.start(device);

    await tester.toggleNetwork(); // offline
    await tester.addTodo('Please reject me');
    await tester.tap(find.byType(Checkbox).last); // queued behind the create
    await tester.pump();
    await tester.toggleNetwork(); // online
    await tester.settle();

    expect(_needsAttention('Please reject me'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sync_problem));
    await tester.pumpAndSettle();
    expect(find.textContaining('Refused: 422'), findsOneWidget);
    expect(find.text('Waiting for the write above'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    // The held toggle becomes blocked in turn: discard it too.
    expect(find.text('A write before it was discarded'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Everything is synced'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // close the panel
    await tester.pumpAndSettle();
    expect(find.text('Please reject me'), findsNothing);
    await tester.shutDown();
  });
}

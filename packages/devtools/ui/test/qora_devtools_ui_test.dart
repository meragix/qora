import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_devtools_ui/src/ui/qora_devtools_app.dart';

void main() {
  testWidgets('renders tab scaffold', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: QoraDevToolsApp()),
    );

    expect(find.text('Qora DevTools'), findsOneWidget);
    expect(find.text('QUERIES'), findsOneWidget);
    expect(find.text('MUTATIONS'), findsOneWidget);
    expect(
        find.text('No queries yet.\nPress Refresh or wait for live updates.'),
        findsOneWidget);
  });
}

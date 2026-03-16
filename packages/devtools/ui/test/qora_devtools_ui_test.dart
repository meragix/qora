import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_devtools_ui/src/ui/qora_devtools_app.dart';

void main() {
  testWidgets('renders tab scaffold', (tester) async {
    await tester.pumpWidget(const QoraDevToolsApp());

    expect(find.text('Qora DevTools'), findsOneWidget);
    expect(find.text('Cache'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Optimistic'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

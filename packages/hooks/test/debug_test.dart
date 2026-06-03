import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_flutter/qora_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qora_hooks/qora_hooks.dart';

Widget _app(QoraClient client, Widget child) => MaterialApp(
      home: QoraScope(client: client, child: child),
    );

void main() {
  testWidgets('debug mutation', (tester) async {
    final states = <MutationState<String, String>>[];
    late MutationHandle<String, String> handle;
    final client = QoraClient();

    await tester.pumpWidget(
      _app(
        client,
        HookBuilder(builder: (context) {
          handle = useMutation<String, String>(
            mutator: (v) async {
              await Future<void>.delayed(const Duration(milliseconds: 10));
              return 'result-$v';
            },
          );
          debugPrint(
              'BUILD: state=${handle.state.runtimeType} isSuccess=${handle.isSuccess} isPending=${handle.isPending}');
          states.add(handle.state);
          return const SizedBox.shrink();
        }),
      ),
    );

    debugPrint(
        'BEFORE MUTATE: ${handle.state.runtimeType} isSuccess=${handle.isSuccess}');
    expect(handle.isIdle, isTrue);

    handle.mutate('test');

    debugPrint('AFTER MUTATE (pre pump): ${handle.state.runtimeType}');
    await tester.pump();
    debugPrint(
        'AFTER PUMP 1: handle=${handle.state.runtimeType} isSuccess=${handle.isSuccess} isPending=${handle.isPending}');
    debugPrint('  states: ${states.map((s) => s.runtimeType).join(", ")}');
    expect(states.any((s) => s.isPending), isTrue);

    await tester.pump(const Duration(milliseconds: 10));
    debugPrint(
        'AFTER PUMP 10ms: handle=${handle.state.runtimeType} isSuccess=${handle.isSuccess}');
    debugPrint('  states: ${states.map((s) => s.runtimeType).join(", ")}');

    expect(handle.isSuccess, isTrue);
    expect(handle.data, 'result-test');
  });
}

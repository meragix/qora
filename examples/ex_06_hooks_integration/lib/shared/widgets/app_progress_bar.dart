import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_hooks/qora_hooks.dart';

/// A thin [LinearProgressIndicator] that appears whenever any query is
/// actively fetching — with no coupling to specific queries.
///
/// Place this at the top of your app's [Scaffold] or [AppBar] to give
/// users a global loading signal:
///
/// ```dart
/// appBar: AppBar(
///   bottom: PreferredSize(
///     preferredSize: const Size.fromHeight(2),
///     child: AppProgressBar(),
///   ),
/// ),
/// ```
///
/// [useIsFetching] only rebuilds this widget when the fetch count **crosses
/// zero**: not on every count change.  If five queries are running and one
/// finishes, this widget does not rebuild — saving unnecessary renders.
class AppProgressBar extends HookWidget {
  const AppProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isFetching = useIsFetching();

    return AnimatedOpacity(
      opacity: isFetching ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: const LinearProgressIndicator(minHeight: 2),
    );
  }
}

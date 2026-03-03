import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_flutter/qora_flutter.dart';

import 'use_query_client.dart';

/// Returns `true` when at least one query managed by the nearest [QoraClient]
/// is actively fetching (i.e. a network request is in flight).
///
/// Initialises synchronously from [QoraClient.isFetchingCount] — no loading
/// flash on the first frame. Rebuilds only when the count crosses the zero
/// boundary, not on every individual increment or decrement.
///
/// ```dart
/// class AppLoadingBar extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final isFetching = useIsFetching();
///     return AnimatedOpacity(
///       opacity: isFetching ? 1.0 : 0.0,
///       duration: const Duration(milliseconds: 200),
///       child: const LinearProgressIndicator(),
///     );
///   }
/// }
/// ```
bool useIsFetching() {
  final client = useQueryClient();

  // Initialise from the synchronous snapshot — avoids a stale first frame.
  final count = useState(client.isFetchingCount);

  useEffect(() {
    final sub = client.fetchingCountStream.listen((c) => count.value = c);
    return sub.cancel;
  }, [client]);

  return count.value > 0;
}

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../utils/query_key.dart';
import 'use_query_client.dart';

/// Subscribes to a [QoraClient] query and returns the current [QoraState].
///
/// Automatically triggers a fetch on mount and rebuilds the widget on every
/// state change. Re-subscribes whenever [key] changes.
///
/// The initial state is read from the cache synchronously — if the key is
/// already cached, the widget renders with data on the first frame.
///
/// ```dart
/// class UserScreen extends HookWidget {
///   final String userId;
///   const UserScreen({super.key, required this.userId});
///
///   @override
///   Widget build(BuildContext context) {
///     final state = useQuery<User>(
///       key: ['users', userId],
///       fetcher: () => Api.getUser(userId),
///       options: const QoraOptions(staleTime: Duration(minutes: 5)),
///     );
///
///     return switch (state) {
///       Initial()            => const SizedBox.shrink(),
///       Loading()            => const CircularProgressIndicator(),
///       Success(:final data) => UserCard(data),
///       Failure(:final error) => ErrorView(error),
///     };
///   }
/// }
/// ```
///
/// Use [select] to derive a computed value from the data and avoid
/// unnecessary rebuilds:
///
/// ```dart
/// final count = useQuery<List<User>>(
///   key: ['users'],
///   fetcher: () => api.getUsers(),
///   select: (users) => users.length,
/// );
/// // Only rebuilds when count changes.
/// ```
QoraState<T> useQuery<T>({
  required List<Object?> key,
  required Future<T> Function() fetcher,
  QoraOptions? options,
  Object? Function(T data)? select,
}) {
  final client = useQueryClient();

  // Initialise from cache — avoids a loading flash when data is already fresh.
  final state = useState<QoraState<T>>(client.getQueryState<T>(key));
  final lastSelected = useRef<Object?>(null);

  // Re-subscribe whenever the key changes.
  useEffect(() {
    final sub = client
        .watchQuery<T>(
      key: key,
      fetcher: fetcher,
      options: options,
    )
        .listen((newState) {
      if (select != null) {
        final data = newState.dataOrNull;
        if (data != null) {
          final newSelected = select(data);
          if (lastSelected.value == newSelected) return;
          lastSelected.value = newSelected;
        }
      }
      state.value = newState;
    });

    return sub.cancel;
  }, [QueryKey(key)]);

  return state.value;
}

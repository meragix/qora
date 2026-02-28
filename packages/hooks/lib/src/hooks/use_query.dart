import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora/qora.dart';

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
QoraState<T> useQuery<T>({
  required List<Object?> key,
  required Future<T> Function() fetcher,
  QoraOptions? options,
}) {
  final client = useQueryClient();

  // Initialise from cache — avoids a loading flash when data is already fresh.
  final state = useState<QoraState<T>>(client.getQueryState<T>(key));

  // Re-subscribe whenever the key changes.
  useEffect(() {
    final sub = client
        .watchQuery<T>(
          key: key,
          fetcher: fetcher,
          options: options,
        )
        .listen((newState) => state.value = newState);

    return sub.cancel;
  }, [Object.hashAll(key)]);

  return state.value;
}

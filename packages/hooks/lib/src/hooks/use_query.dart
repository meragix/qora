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
/// Use [select] as a rebuild filter: the widget rebuilds only when the state
/// kind or the selected value changes. The returned state is always the
/// latest one; [select] decides *when* to rebuild, not *what* is returned.
///
/// ```dart
/// final state = useQuery<List<User>>(
///   key: ['users'],
///   fetcher: () => api.getUsers(),
///   select: (users) => users.length, // rebuild only when the count changes
/// );
/// final count = state.dataOrNull?.length ?? 0;
/// ```
QoraState<T> useQuery<T>({
  required List<Object?> key,
  required Future<T> Function() fetcher,
  QoraOptions? options,
  Object? Function(T data)? select,
}) {
  final client = useQueryClient();
  final queryKey = QueryKey(key);

  // Eagerly seed initialData/placeholderData into the cache before the first
  // render so widgets see the pre-populated state instead of an Initial flash.
  final mergedOptions = client.config.defaultOptions.merge(options);
  if (mergedOptions.initialData != null ||
      mergedOptions.placeholderData != null) {
    client.prepopulateCache<T>(key, mergedOptions);
  }

  // Latest state, updated on every emission. A rebuild is requested through
  // [rebuildTick]; [select] can skip it without ever returning stale data.
  final latest = useRef<QoraState<T>>(client.getQueryState<T>(key));
  final subscribedKey = useRef<QueryKey>(queryKey);
  if (subscribedKey.value != queryKey) {
    // Key changed: read the new key's cache synchronously for this frame.
    subscribedKey.value = queryKey;
    latest.value = client.getQueryState<T>(key);
  }
  final rebuildTick = useState(0);

  // Keep the latest callbacks so background refetches (invalidation,
  // polling) never run a stale closure captured on the first subscription.
  final fetcherRef = useRef(fetcher);
  fetcherRef.value = fetcher;
  final selectRef = useRef(select);
  selectRef.value = select;
  final snapshot = useRef<(Type, Object?)?>(null);

  bool selectionChanged(QoraState<T> next) {
    final selector = selectRef.value;
    if (selector == null) return true;
    final data = next.dataOrNull;
    final current = (next.runtimeType, data == null ? null : selector(data));
    final changed = current != snapshot.value;
    snapshot.value = current;
    return changed;
  }

  // Re-subscribe whenever the key changes.
  useEffect(() {
    selectionChanged(latest.value);
    final sub = client
        .watchQuery<T>(
      key: key,
      fetcher: () => fetcherRef.value(),
      options: options,
    )
        .listen((newState) {
      latest.value = newState;
      if (selectionChanged(newState)) rebuildTick.value++;
    });

    return sub.cancel;
  }, [queryKey]);

  return latest.value;
}

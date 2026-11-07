import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_flutter/qora_flutter.dart';

import '../utils/query_key.dart';
import 'use_query_client.dart';

/// Returns the [FetchStatus] of the query identified by [key]: the second axis
/// of query state, independent from the [QoraState] returned by `useQuery`.
///
/// - [FetchStatus.fetching]: a request is in flight (first load or
///   background revalidation).
/// - [FetchStatus.paused]: the device is offline and the fetch waits for the
///   network.
/// - [FetchStatus.idle]: nothing in progress.
///
/// Use it to show a subtle refresh indicator over stale data, or an
/// "offline" badge, without inspecting the data state:
///
/// ```dart
/// final state = useQuery<User>(key: ['users', id], fetcher: () => api.getUser(id));
/// final fetchStatus = useFetchStatus(['users', id]);
///
/// return Stack(children: [
///   if (state.dataOrNull case final user?) UserCard(user),
///   if (fetchStatus == FetchStatus.fetching) const LinearProgressIndicator(),
///   if (fetchStatus == FetchStatus.paused) const OfflineBadge(),
/// ]);
/// ```
FetchStatus useFetchStatus(List<Object?> key) {
  final client = useQueryClient();
  final status = useState(FetchStatus.idle);

  useEffect(() {
    final sub = client.watchFetchStatus(key).listen((s) => status.value = s);
    return sub.cancel;
  }, [client, QueryKey(key)]);

  return status.value;
}

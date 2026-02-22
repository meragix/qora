/// Qora — async state management for Dart, inspired by TanStack Query.
///
/// ## Quick start
///
/// ```dart
/// import 'package:qora/qora.dart';
///
/// // 1. Create a client (one per app / DI scope)
/// final client = QoraClient(
///   config: QoraClientConfig(
///     defaultOptions: QoraOptions(staleTime: Duration(minutes: 5)),
///     debugMode: true,
///   ),
/// );
///
/// // 2a. One-shot fetch (with caching, deduplication, and retry)
/// final user = await client.fetchQuery<User>(
///   key: ['users', userId],
///   fetcher: () => api.getUser(userId),
/// );
///
/// // 2b. Reactive stream (auto-fetches, polls, emits all state transitions)
/// client.watchQuery<List<Post>>(
///   key: ['posts'],
///   fetcher: api.getPosts,
///   options: QoraOptions(refetchInterval: Duration(seconds: 30)),
/// ).listen((state) {
///   switch (state) {
///     case Success(:final data):  render(data);
///     case Failure(:final error): showError(error);
///     default: {}
///   }
/// });
///
/// // 3. Optimistic update
/// final snapshot = client.getQueryData<User>(['users', userId]);
/// client.setQueryData(['users', userId], updated);
/// try {
///   await api.updateUser(userId, payload);
/// } catch (_) {
///   client.restoreQueryData(['users', userId], snapshot);
/// }
///
/// // 4. Invalidate after mutation
/// await api.createPost(payload);
/// client.invalidate(['posts']);
/// ```
library;

export 'src/cache/cached_entry.dart';
export 'src/client/qora_client.dart';
export 'src/config/qora_client_config.dart';
export 'src/config/qora_options.dart';
export 'src/cache/query_cache.dart';
export 'src/key/qora_key.dart';
export 'src/managers/connectivity_manager.dart';
export 'src/managers/lifecycle_manager.dart';
export 'src/state/state.dart';
export 'src/utils/qora_exception.dart';
export 'src/utils/query_function.dart';

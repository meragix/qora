/// flutter_hooks integration for Qora.
///
/// Provides [useQuery], [useMutation], [useQueryClient], and [useInfiniteQuery]
/// — the hook-based counterparts of [QoraBuilder] and [QoraMutationBuilder].
///
/// ## Quick start
///
/// ```dart
/// // Wrap your app with QoraScope (from flutter_qora):
/// runApp(
///   QoraScope(
///     client: QoraClient(),
///     child: MyApp(),
///   ),
/// );
///
/// // Then use hooks inside any HookWidget:
/// class UserScreen extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final state = useQuery<User>(
///       key: ['users', '42'],
///       fetcher: () => api.getUser('42'),
///     );
///     return switch (state) {
///       Loading() => const CircularProgressIndicator(),
///       Success(:final data) => Text(data.name),
///       Failure(:final error) => Text('$error'),
///       _ => const SizedBox.shrink(),
///     };
///   }
/// }
/// ```
library;

export 'src/hooks/use_query_client.dart';
export 'src/hooks/use_query.dart';
export 'src/hooks/use_mutation.dart' show MutationHandle, useMutation;
export 'src/hooks/use_infinite_query.dart'
    show InfiniteQueryHandle, useInfiniteQuery;

/// Flutter integration layer for Qora.
///
/// Provides widgets, managers, and extensions for using [QoraClient] in
/// Flutter applications.
///
/// ## Core components
///
/// - [QoraScope] — `InheritedWidget` that provides a [QoraClient] to the
///   entire widget tree.
/// - [QoraBuilder] — subscribes to a query, auto-fetches on mount, and
///   rebuilds on every state change.
/// - [QoraStateBuilder] — observe-only variant; rebuilds on state changes
///   without triggering a fetch.
/// - `context.qora` — shorthand for `QoraScope.of(context)`.
///
/// ## Optional managers
///
/// - [FlutterLifecycleManager] — invalidates queries when the app resumes
///   from background (requires no extra dependency).
/// - [FlutterConnectivityManager] — invalidates queries when the device
///   reconnects to the network (requires `connectivity_plus`).
///
/// ## Quick start
///
/// ```dart
/// void main() {
///   final client = QoraClient(
///     config: const QoraClientConfig(
///       defaultOptions: QoraOptions(
///         staleTime: Duration(minutes: 5),
///         cacheTime: Duration(minutes: 10),
///       ),
///       debugMode: kDebugMode,
///       maxCacheSize: 200,
///     ),
///   );
///
///   runApp(
///     QoraScope(
///       client: client,
///       lifecycleManager: FlutterLifecycleManager(qoraClient: client),
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// ```dart
/// class UserProfile extends StatelessWidget {
///   final int userId;
///   const UserProfile({required this.userId, super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return QoraBuilder<User>(
///       queryKey: ['users', userId],
///       queryFn: () => api.getUser(userId),
///       builder: (context, state) {
///         return switch (state) {
///           Initial()                    => const SizedBox.shrink(),
///           Loading(:final previousData) =>
///               previousData != null
///                   ? UserCard(previousData)
///                   : const CircularProgressIndicator(),
///           Success(:final data)         => UserCard(data),
///           Failure(:final error)        => ErrorBanner(error),
///         };
///       },
///     );
///   }
/// }
/// ```
///
/// ```dart
/// // Invalidate after a mutation
/// ElevatedButton(
///   onPressed: () async {
///     await api.deleteUser(userId);
///     context.qora.invalidate(['users', userId]);
///   },
///   child: const Text('Delete'),
/// )
/// ```
library;

// Re-export the core Qora package so consumers only need one import.
export 'package:qora/qora.dart';

// Widgets
export 'src/widgets/qora_scope.dart';
export 'src/widgets/qora_builder.dart';
export 'src/widgets/mutation_builder.dart';

// Extensions
export 'src/extensions/build_context_extension.dart';

// Platform managers (optional — wire into QoraScope as needed)
export 'src/managers/flutter_lifecycle_manager.dart';
export 'src/managers/flutter_connectivity_manager.dart';

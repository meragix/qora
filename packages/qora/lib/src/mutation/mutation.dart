/// Mutation support for Qora.
///
/// Provides [MutationController] for managing server-side write operations
/// with full lifecycle support: optimistic updates, rollback, and retry.
///
/// ## Quick start
///
/// ```dart
/// final controller = MutationController<Post, String, List<Post>?>(
///   mutator: (title) => api.createPost(title),
///   options: MutationOptions(
///     onMutate: (title) async {
///       final prev = client.getQueryData<List<Post>>(['posts']);
///       client.setQueryData<List<Post>>(['posts'], [...?prev, Post.optimistic(title)]);
///       return prev;
///     },
///     onError: (err, vars, prev) async => client.restoreQueryData(['posts'], prev),
///     onSuccess: (post, vars, _) async => client.invalidate(['posts']),
///   ),
/// );
///
/// // Execute the mutation
/// await controller.mutate('New Post');
///
/// // Reset to idle after showing success/error
/// controller.reset();
///
/// // Always dispose when done
/// controller.dispose();
/// ```
library;

export 'mutation_controller.dart';
export 'mutation_event.dart';
export 'mutation_options.dart';
export 'mutation_state.dart';
export 'mutation_state_extensions.dart';
export 'mutation_tracker.dart';

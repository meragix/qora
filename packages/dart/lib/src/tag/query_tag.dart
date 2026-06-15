import 'package:meta/meta.dart';

/// A tag that associates query cache entries with a logical category.
///
/// Tags decouple cache invalidation from query keys. A query declares which
/// tags it provides (via [QoraOptions.providesTags]), and mutations declare
/// which tags they invalidate (via [MutationOptions.invalidatesTags]).
///
/// When a mutation invalidates a tag, every query that provides that tag is
/// automatically refetched: regardless of its query key.
///
/// ## Basic usage
///
/// ```dart
/// // Query provides tags
/// client.watchQuery<Post>(
///   key: ['post', postId],
///   fetcher: () => api.getPost(postId),
///   options: QoraOptions(
///     providesTags: [QueryTag('post', postId.toString())],
///   ),
/// );
///
/// // Mutation invalidates tags
/// MutationOptions(
///   invalidatesTags: [QueryTag('post')], // refetches ALL post queries
/// )
/// ```
///
/// ## Wildcard matching
///
/// Invalidating `QueryTag('post')` (no [id]) refetches ALL queries that
/// provide any tag of type `'post'`: regardless of their individual ids.
/// Invalidating `QueryTag('post', '123')` only refetches queries that
/// provide the specific `'post:123'` tag.
@immutable
class QueryTag {
  /// The logical category (e.g. `'post'`, `'user'`, `'comment'`).
  final String type;

  /// Optional identifier within the category (e.g. the entity's primary key).
  ///
  /// When `null`, this tag matches all ids of the given [type].
  /// When set, only exact matches are invalidated.
  final String? id;

  /// The serialised form used internally for registry lookups.
  ///
  /// Format: `type` when [id] is null, or `type:id` otherwise.
  String get serialised => id != null ? '$type:$id' : type;

  const QueryTag(this.type, [this.id]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryTag && type == other.type && id == other.id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'QueryTag($type${id != null ? ', $id' : ''})';
}

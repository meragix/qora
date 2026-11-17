import 'package:meta/meta.dart';
import 'package:qora/src/persistence/qora_serializer.dart';
import 'package:qora/src/tag/query_tag.dart';

import 'mutation_meta.dart';

/// The mutator of a registered mutation.
///
/// Unlike a call site's mutator, it receives a [MutationMeta] carrying the
/// call's stable `mutationId`, to send as an idempotency key.
typedef RegisteredMutator<TData, TVariables> = Future<TData> Function(
  TVariables variables,
  MutationMeta meta,
);

/// A mutation registered under a key with [MutationRegistry.register].
///
/// Everything a registered call needs must be reachable from here or from
/// its variables: a queued call may outlive the widget that made it.
@immutable
final class MutationRegistration<TData, TVariables> {
  /// The key call sites name in `MutationOptions.mutationKey`.
  final String key;

  /// Runs the write. Used for every call made with [key], in the session
  /// that made it and on any later replay.
  final RegisteredMutator<TData, TVariables> mutator;

  /// Converts the variables to and from JSON, so a queued call can be stored.
  final QoraSerializer<TVariables> variables;

  /// Query keys invalidated after every successful call, in addition to the
  /// call site's `MutationOptions.invalidates`.
  final List<Object>? invalidates;

  /// Tags invalidated after every successful call, in addition to the call
  /// site's `MutationOptions.invalidatesTags`.
  final List<QueryTag>? invalidatesTags;

  /// Returns the scope of a queued call, or `null` for the global lane.
  ///
  /// Queued calls in one scope are sent in order, one at a time, and a call
  /// that fails for good holds the rest of its scope. Different scopes do
  /// not wait for each other. Return the narrowest value that covers the
  /// dependencies, usually the record's ID, or the parent's ID for children.
  final String? Function(TVariables variables)? scope;

  /// Whether an error rejects a queued call for good, instead of being
  /// retried. Overrides `MutationQueueConfig.isPermanent`. When neither is
  /// set, every error is transient.
  final bool Function(Object error)? isPermanent;

  /// Creates a registration. Prefer [MutationRegistry.register] or
  /// `QoraClient.registerMutation`, which build it for you.
  const MutationRegistration({
    required this.key,
    required this.mutator,
    required this.variables,
    this.invalidates,
    this.invalidatesTags,
    this.scope,
    this.isPermanent,
  });

  /// The variables type this mutation was registered with.
  Type get variablesType => TVariables;

  /// Runs [mutator] with the given identity.
  Future<TData> run(TVariables variables, MutationMeta meta) =>
      mutator(variables, meta);

  /// Whether [variables] can be passed to this mutation.
  @internal
  bool accepts(Object? variables) => variables is TVariables;

  /// [variables] `toJson` for the queue, which holds variables without
  /// their type.
  @internal
  Object? encodeVariables(Object? value) =>
      variables.toJson(value as TVariables);

  /// [variables] `fromJson`, typed for [runErased].
  @internal
  Object? decodeVariables(Object? json) => variables.fromJson(json);

  /// [run] for the queue, which holds variables without their type.
  @internal
  Future<Object?> runErased(Object? variables, MutationMeta meta) =>
      Future.sync(() => mutator(variables as TVariables, meta));

  /// [scope] for the queue, which holds variables without their type.
  @internal
  String? scopeOf(Object? variables) => scope?.call(variables as TVariables);
}

/// The mutations a client knows by key.
///
/// A call site opts in with `MutationOptions(mutationKey: ...)` and passes no
/// mutator: the registered one runs instead. Register every key at startup,
/// before any call site uses it.
final class MutationRegistry {
  final Map<String, MutationRegistration<Object?, Object?>> _entries = {};

  /// Registers [registration] under its key.
  ///
  /// Throws a [StateError] if the key is already registered: two mutators
  /// for one key would make replays ambiguous.
  void register<TData, TVariables>(
    MutationRegistration<TData, TVariables> registration,
  ) {
    if (_entries.containsKey(registration.key)) {
      throw StateError(
        'A mutation is already registered under "${registration.key}". '
        'Each mutation key can be registered once per client.',
      );
    }
    _entries[registration.key] = registration;
  }

  /// Whether a mutation is registered under [key].
  bool contains(String key) => _entries.containsKey(key);

  /// The registered keys, in registration order.
  Iterable<String> get keys => _entries.keys;

  /// Returns the registration for [key], or `null` if none exists.
  ///
  /// [TVariables] must be exactly the registered variables type, and [TData]
  /// the registered data type or one of its supertypes. Anything else throws
  /// a [StateError], so a mismatch fails when the call site is set up rather
  /// than with a type error inside the mutator.
  MutationRegistration<TData, TVariables>? lookup<TData, TVariables>(
    String key,
  ) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.variablesType != TVariables ||
        entry is! MutationRegistration<TData, TVariables>) {
      throw StateError(
        'The mutation "$key" is registered as ${entry.runtimeType}, '
        'but was used as MutationRegistration<$TData, $TVariables>.',
      );
    }
    return entry;
  }

  /// The registration for [key] without its types, for the queue.
  @internal
  MutationRegistration<Object?, Object?>? entryOf(String key) => _entries[key];
}

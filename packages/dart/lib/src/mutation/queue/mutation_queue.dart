import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:qora/src/persistence/storage_adapter.dart';
import 'package:qora/src/tag/query_tag.dart';
import 'package:qora/src/utils/mutation_id.dart';

import '../mutation_meta.dart';
import '../mutation_registry.dart';
import '../mutation_state.dart';
import 'mutation_discarded_exception.dart';
import 'mutation_queue_config.dart';
import 'queued_mutation.dart';

/// What the call site that queued a call hears about it.
///
/// Implemented by `MutationController`. Every method may be called after
/// the controller was disposed; the controller ignores state changes then,
/// but still runs its callbacks so an `onError` rollback reaches the cache.
@internal
abstract interface class QueuedCallListener {
  /// The call is in the queue for good: stored, when the queue persists.
  /// Called once, before the call can be sent.
  void onQueued();

  /// The call is waiting: offline, behind a held scope, or before a retry.
  /// May be called several times.
  void onParked();

  /// The call succeeded. The listener runs the registration's invalidations
  /// and its own callbacks.
  Future<void> onSuccess(Object? data, Object? variables);

  /// The call failed for good and is now `blocked` or `failed`.
  Future<void> onFailure(
    Object error,
    StackTrace stackTrace,
    Object? variables,
  );

  /// The call left the queue without being sent: the app discarded or
  /// cleared it ([reason] set), or the queue was disposed ([reason] null).
  Future<void> onDropped(MutationDiscardedException? reason);
}

/// The queue of registered mutations.
///
/// Holds every call made with `MutationOptions(mutationKey: ...,
/// offlineQueue: true)`, online or not, so that calls in one scope are sent
/// in order. Read it through `QoraClient.mutationQueue`.
///
/// Calls without a scope share the global lane. Calls with a scope form a
/// lane per scope. Lanes are sent concurrently, up to
/// `ReconnectStrategy.maxConcurrent` requests at a time; inside a lane, one
/// call is in flight at a time, in the order they were made.
///
/// See [MutationQueueConfig] for how failures are retried, and
/// [QueuedMutationStatus] for the statuses an entry goes through.
///
/// With `PersistQoraClient`, each call is stored in the client's
/// `StorageAdapter` before it counts as queued, and `hydrate()` restores
/// the queue after a restart.
final class MutationQueue {
  final MutationRegistry _registry;
  final MutationQueueConfig _config;
  final bool Function() _isOnline;
  final int _maxConcurrent;
  final Future<void> Function(Object key)? _invalidateQuery;
  final Future<void> Function(List<QueryTag> tags)? _invalidateTags;
  final Random _random;
  final void Function(String message)? _log;
  final void Function(
    String id,
    MutationState<Object?, Object?> state,
    Map<String, Object?> metadata,
  )? _track;

  final List<_Entry> _entries = [];
  int _sending = 0;
  bool _isDisposed = false;

  StorageAdapter? _storage;

  late final StreamController<List<QueuedMutation>> _changes =
      StreamController<List<QueuedMutation>>.broadcast(
    // A new listener already knows the current entries (it reads them).
    onListen: () => _lastSignature = _signatureOf(entries),
  );
  bool _changeScheduled = false;

  /// What the last snapshot sent on [entriesStream] showed, to skip
  /// snapshots that show nothing new. `null` when no listener saw one.
  List<Object?>? _lastSignature;

  /// Last sequence number given to a stored call. Microseconds since the
  /// epoch, kept increasing, so storage keys sort in call order.
  int _lastSequence = 0;

  /// Bumped by [clear]: a restore that started before a logout must not
  /// bring back the previous user's calls.
  int _generation = 0;

  /// The restore in progress, shared by concurrent `hydrate()` calls.
  Future<void>? _restoring;

  /// Records whose delete has not completed yet: a restore must not read
  /// them back.
  final Map<String, Future<void>> _pendingDeletes = {};

  /// Creates a queue. Owned by `QoraClient`; read it with
  /// `QoraClient.mutationQueue` instead of creating one.
  @internal
  MutationQueue({
    required MutationRegistry registry,
    required bool Function() isOnline,
    MutationQueueConfig config = const MutationQueueConfig(),
    int maxConcurrent = 5,
    Future<void> Function(Object key)? invalidateQuery,
    Future<void> Function(List<QueryTag> tags)? invalidateTags,
    Random? random,
    void Function(String message)? log,
    void Function(
      String id,
      MutationState<Object?, Object?> state,
      Map<String, Object?> metadata,
    )? track,
  })  : _registry = registry,
        _isOnline = isOnline,
        _config = config,
        _maxConcurrent = maxConcurrent < 1 ? 1 : maxConcurrent,
        _invalidateQuery = invalidateQuery,
        _invalidateTags = invalidateTags,
        _random = random ?? Random(),
        _log = log,
        _track = track;

  // ── Reading ──────────────────────────────────────────────────────────────

  /// The queued calls, in the order they were made.
  ///
  /// A call appears once it is in the queue for good: after its `onMutate`
  /// ran and, with `PersistQoraClient`, once it is stored. It leaves the
  /// queue when it succeeds or when the app discards it. `blocked` and
  /// `failed` entries stay until the app decides.
  List<QueuedMutation> get entries {
    final blockedScopes = <String>{};
    final result = <QueuedMutation>[];
    for (final e in _entries) {
      // Computed for every entry: a reserved call still holds its scope.
      final status = _statusOf(e, blockedScopes);
      if (_isVisible(e)) result.add(e.snapshot(status));
    }
    return List.unmodifiable(result);
  }

  /// The new [entries] each time they change: a call queued, sent, retried,
  /// failed, discarded or done.
  ///
  /// Changes made in one synchronous run are reported once. Read [entries]
  /// for the current value, then listen for the next ones:
  ///
  /// ```dart
  /// StreamBuilder<List<QueuedMutation>>(
  ///   initialData: client.mutationQueue.entries,
  ///   stream: client.mutationQueue.entriesStream,
  ///   builder: (context, snapshot) => SyncBadge(snapshot.data!),
  /// )
  /// ```
  Stream<List<QueuedMutation>> get entriesStream => _changes.stream;

  /// Number of queued calls, all statuses included.
  int get length => _entries.where(_isVisible).length;

  /// Whether no call is queued.
  bool get isEmpty => length == 0;

  static bool _isVisible(_Entry e) => e.ready && !e.dropWhenSettled;

  QueuedMutationStatus _statusOf(_Entry e, Set<String> blockedScopes) {
    final scope = e.scope;
    if (e.sending) return QueuedMutationStatus.sending;
    if (e.needsDecision) {
      if (scope == null) return QueuedMutationStatus.failed;
      blockedScopes.add(scope);
      return QueuedMutationStatus.blocked;
    }
    if (scope != null && blockedScopes.contains(scope)) {
      return QueuedMutationStatus.held;
    }
    return QueuedMutationStatus.queued;
  }

  // ── Decisions ────────────────────────────────────────────────────────────

  /// Sends a `blocked` or `failed` call again.
  ///
  /// Without [variables], the call is resent as-is under the same
  /// `mutationId`, so server-side deduplication still applies. Use this when
  /// it ran out of attempts on transient errors: the server may already have
  /// applied it.
  ///
  /// With [variables], the call is replaced in place by one with these
  /// variables under a new `mutationId`; the queue never holds two versions
  /// of the same write. Its scope does not change. To change a record that
  /// has a blocked write, retry that write with new variables instead of
  /// calling `mutate` again, which would queue a second write held behind
  /// the first.
  ///
  /// The attempt count starts over. A `blocked` call stays at the head of its
  /// scope, and the calls it held are sent after it succeeds. A `failed` call
  /// goes back to the head of the global lane.
  ///
  /// Throws a [StateError] if no call has this id or if it is not `blocked`
  /// or `failed`, and an [ArgumentError] if [variables] do not match the
  /// registered variables type. With persistence, an error thrown by the
  /// registered `toJson` propagates and the call is left as it was.
  void retry(String mutationId, {Object? variables = _keep}) {
    final entry = _find(mutationId);
    void Function()? undo;
    if (!entry.needsDecision) {
      throw StateError(
        'Only a blocked or failed mutation can be retried; "$mutationId" is '
        'still in the queue.',
      );
    }
    if (!identical(variables, _keep)) {
      if (!entry.registration.accepts(variables)) {
        throw ArgumentError.value(
          variables,
          'variables',
          'does not match the variables type of "${entry.key}"',
        );
      }
      // Encoded before anything changes: a throwing toJson or fromJson
      // leaves the call as it was.
      final stored = _storage == null
          ? null
          : jsonEncode(entry.registration.encodeVariables(variables));
      final payload = stored == null
          ? variables
          : entry.registration.decodeVariables(jsonDecode(stored));
      final previous = (
        entry.variables,
        entry.payload,
        entry.storedVariables,
        entry.mutationId,
      );
      // Storage still holds the previous call: if the new one cannot be
      // written, memory goes back to it, so a restart shows the same call.
      undo = () => entry
        ..variables = previous.$1
        ..payload = previous.$2
        ..storedVariables = previous.$3
        ..mutationId = previous.$4;
      entry
        ..variables = variables
        ..payload = payload
        ..storedVariables = stored
        ..mutationId = generateMutationId();
    }
    entry
      ..needsDecision = false
      ..attempts = 0
      ..lastError = null;

    if (entry.scope == null) {
      // Back to the head of the global lane, which it had left.
      _entries.remove(entry);
      // Behind a request still in flight: one request per lane.
      final head = _entries.indexWhere(
        (e) => e.scope == null && !e.needsDecision && !e.sending,
      );
      _entries.insert(head == -1 ? _entries.length : head, entry);
    }
    _log?.call('Mutation queue: retry ${entry.key} ($mutationId)');
    _persistThenSend(entry, undo: undo);
  }

  /// Rewrites [e]'s record, and only then lets it be sent: after a restart,
  /// the stored payload and `mutationId` must be the ones that were sent.
  /// If the record cannot be rewritten, the call waits for a decision again.
  void _persistThenSend(_Entry e, {void Function()? undo}) {
    final storage = _storage;
    final storageKey = e.storageKey;
    if (storage == null || storageKey == null) {
      _pump();
      return;
    }
    final record = _record(e);
    e.writing = true;
    final write = e.storeOp.then((_) => storage.write(storageKey, record));
    final op = write.then((_) {}, onError: (Object _) {});
    e.storeOp = op;
    _pump();
    write.then(
      (_) {
        e.writing = false;
        _pump();
      },
      onError: (Object error) {
        e.writing = false;
        if (_isDisposed || !_entries.contains(e)) return;
        _log?.call('Mutation queue: could not store the retry of ${e.key} '
            '(${e.mutationId}): $error');
        // A later write was chained: it stores the current call, so memory
        // keeps it.
        if (identical(e.storeOp, op)) undo?.call();
        e
          ..needsDecision = true
          ..lastError = error;
        _pump();
      },
    );
  }

  /// Removes a call from the queue.
  ///
  /// The calls behind it in its scope may depend on it (an update of a
  /// record whose create is discarded), so they become `blocked` for the
  /// app to decide on each. A call whose request is in flight is removed
  /// once the request settles; it is not retried.
  ///
  /// Throws a [StateError] if no call has this id.
  void discard(String mutationId) {
    final entry = _find(mutationId);
    _drop(entry, settle: true);
    _unpersist(entry, discarded: true);
    _blockFollowers(entry);
    _removeIfIdle(entry);
    _log?.call('Mutation queue: discarded ${entry.key} ($mutationId)');
    _pump();
  }

  /// Removes every call of [scope] from the queue.
  void discardScope(String scope) {
    for (final e in _entries.where((e) => e.scope == scope).toList()) {
      _drop(e, settle: true);
      _unpersist(e, discarded: true);
      _removeIfIdle(e);
    }
    _log?.call('Mutation queue: discarded scope $scope');
    _pump();
  }

  /// Removes every call from the queue, whatever its status.
  ///
  /// Use it on logout: a queued write belongs to the user who made it. Call
  /// it before clearing the cache: the `onError` rollbacks it runs write to
  /// the cache. `PersistQoraClient.clear` does both, in that order.
  void clear() {
    _generation++;
    for (final e in _entries.toList()) {
      _drop(e, settle: true);
      _unpersist(e, discarded: true);
      _removeIfIdle(e);
    }
    _pump();
  }

  // ── Internal API ─────────────────────────────────────────────────────────

  /// Takes the next place in the queue for a call of the mutation
  /// registered under [key] and returns its `mutationId`.
  ///
  /// Synchronous, so calls keep the order in which `mutate` was called even
  /// when their `onMutate` take different times. The call is not sent until
  /// [release]; until then it holds its lane.
  @internal
  String reserve({
    required String key,
    required Object? variables,
    QueuedCallListener? listener,
  }) {
    _assertNotDisposed();
    final registration = _registry.entryOf(key);
    if (registration == null) {
      throw StateError('No mutation is registered under "$key".');
    }
    final entry = _Entry(
      mutationId: generateMutationId(),
      key: key,
      scope: registration.scopeOf(variables),
      variables: variables,
      registration: registration,
      listener: listener,
    );
    // The place in storage follows the order of the calls, as in memory.
    if (_storage != null) entry.storageKey = _nextStorageKey();
    _entries.add(entry);
    return entry.mutationId;
  }

  /// Lets a reserved call be sent. Returns `false` if the call left the
  /// queue meanwhile (discarded or cleared).
  ///
  /// With storage attached, the call is stored first. If it cannot be
  /// stored, it leaves the queue and the error is rethrown: a write must
  /// never look saved while it only exists in memory. The calls behind it in
  /// its scope then wait for a decision, as after a discard.
  @internal
  Future<bool> release(String mutationId) async {
    _assertNotDisposed();
    final entry = _findOrNull(mutationId);
    if (entry == null) return false;
    final storage = _storage;
    if (storage != null) {
      try {
        final stored =
            jsonEncode(entry.registration.encodeVariables(entry.variables));
        entry
          ..storedVariables = stored
          // What a replay after a restart sends, so send it now too.
          ..payload = entry.registration.decodeVariables(jsonDecode(stored));
        final write = storage.write(entry.storageKey!, _record(entry));
        entry.storeOp = write.then((_) {}, onError: (Object _) {});
        await write;
      } catch (error) {
        if (!identical(_findOrNull(mutationId), entry)) return false;
        _log?.call('Mutation queue: could not store ${entry.key} '
            '($mutationId): $error');
        _unpersist(entry);
        _blockFollowers(entry);
        _entries.remove(entry);
        _pump();
        rethrow;
      }
      _assertNotDisposed();
      // Discarded while it was being stored; the discard deletes the record.
      if (!identical(_findOrNull(mutationId), entry)) return false;
      entry.ready = true;
      // Blocked while it was being stored: the record must say so.
      if (entry.needsDecision) _persist(entry);
    }
    entry.ready = true;
    entry.listener?.onQueued();
    _log?.call('Mutation queue: queued ${entry.key} ($mutationId)');
    _pump();
    return true;
  }

  /// Stores every call from now on in [storage]. Called by
  /// `PersistQoraClient` before any call is made.
  @internal
  void attachStorage(StorageAdapter storage) => _storage = storage;

  /// Whether [storageKey] holds a call stored by a mutation queue.
  @internal
  static bool isStorageKey(String storageKey) =>
      storageKey.startsWith(_storagePrefix);

  /// Restores the calls stored under [storageKeys] that are not in the
  /// queue yet, ahead of the calls made in this session that are not sent
  /// yet, then sends what can be sent. Concurrent calls share one restore.
  ///
  /// A record that is not valid JSON, or the tombstone of a discarded call,
  /// is deleted. A record of an unknown
  /// format version, of a key that is not registered, or whose variables
  /// `fromJson` rejects is left in storage and skipped, so a write is never
  /// lost to a missing registration; `PersistQoraClient.clearStorage`
  /// removes it. The later records of its scope are skipped too, so they are
  /// never sent before it. A record that cannot be read stops the restore
  /// there: its scope is unknown, so no later record may overtake it. The
  /// next restore tries again.
  ///
  /// If [clear] ran after [generation] was read, or runs meanwhile (a
  /// logout), nothing is restored.
  @internal
  Future<void> restore(Iterable<String> storageKeys, {int? generation}) {
    final storage = _storage;
    if (storage == null || _isDisposed) return Future<void>.value();
    if (generation != null && generation != _generation) {
      return Future<void>.value();
    }
    return _restoring ??= _restore(storage, storageKeys.toList())
        .whenComplete(() => _restoring = null);
  }

  /// Changes each time [clear] runs. Read it before reading the storage keys
  /// passed to [restore].
  @internal
  int get generation => _generation;

  Future<void> _restore(StorageAdapter storage, List<String> allKeys) async {
    final generation = _generation;
    final known = {for (final e in _entries) e.storageKey};
    final keys = allKeys.where(isStorageKey).toList()..sort();
    // Skipped records keep their place: new calls sort after them too.
    for (final key in keys) {
      final sequence = int.tryParse(key.substring(_storagePrefix.length));
      if (sequence != null && sequence > _lastSequence) {
        _lastSequence = sequence;
      }
    }
    final restored = <_Entry>[];
    final heldScopes = <String>{};
    for (final storageKey in keys) {
      if (known.contains(storageKey) ||
          _pendingDeletes.containsKey(storageKey)) {
        continue;
      }
      final String? raw;
      try {
        raw = await storage.read(storageKey);
      } catch (error) {
        _log?.call('Mutation queue: cannot read "$storageKey": $error, '
            'restoring the calls before it only');
        break;
      }
      if (raw == null) continue;
      final Map<String, dynamic> record;
      try {
        record = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _log?.call('Mutation queue: corrupt record at "$storageKey", '
            'deleting');
        try {
          await storage.delete(storageKey);
        } catch (_) {}
        continue;
      }
      if (record['status'] == 'discarded') {
        try {
          await storage.delete(storageKey);
        } catch (_) {}
        continue;
      }
      final scope = record['scope'];
      if (scope is String && heldScopes.contains(scope)) {
        _log?.call('Mutation queue: "$storageKey" waits behind a record '
            'of scope $scope that cannot be restored, skipping');
        continue;
      }
      final entry = _fromRecord(storageKey, record);
      if (entry != null) {
        restored.add(entry);
      } else if (scope is String) {
        heldScopes.add(scope);
      }
    }
    if (_isDisposed || generation != _generation) return;
    // Another restore or a delete may have run during the reads.
    final present = {for (final e in _entries) e.storageKey};
    restored.removeWhere(
      (e) =>
          present.contains(e.storageKey) ||
          _pendingDeletes.containsKey(e.storageKey),
    );
    // Stored order: after the calls restored earlier with a smaller key (a
    // previous restore that stopped at an unreadable record), before the
    // calls made in this session.
    for (final entry in restored) {
      final at = _entries.indexWhere(
        (e) =>
            !e.fromStorage ||
            (e.storageKey ?? '').compareTo(entry.storageKey!) > 0,
      );
      _entries.insert(at == -1 ? _entries.length : at, entry);
    }
    _log?.call('Mutation queue: restored ${restored.length} call(s)');
    _pump();
  }

  /// Completes when the stored records of the calls removed so far are
  /// deleted.
  @internal
  Future<void> flushDeletes() => Future.wait(_pendingDeletes.values.toList());

  /// Gives up a reserved call that will not be released (its `onMutate`
  /// failed).
  @internal
  void cancelReservation(String mutationId) {
    final entry = _findOrNull(mutationId);
    if (entry == null || entry.ready) return;
    _entries.remove(entry);
    _pump();
  }

  /// Re-evaluates which calls wait. Called when the network status changes.
  @internal
  void refresh() => _pump();

  /// Sends what can be sent now. Called when the device reconnects; calls
  /// waiting for a retry delay are sent right away.
  @internal
  void resume() {
    for (final e in _entries) {
      e.retryTimer?.cancel();
      e.retryTimer = null;
    }
    _pump();
  }

  /// Stops the queue. In-flight requests settle without effect.
  @internal
  void dispose() {
    _isDisposed = true;
    for (final e in _entries.toList()) {
      _drop(e, settle: false);
    }
    _entries.clear();
    unawaited(_changes.close());
  }

  // ── Engine ───────────────────────────────────────────────────────────────

  /// Starts the head of every lane that can send, then tells the listeners
  /// of the calls left waiting.
  void _pump() {
    if (_isDisposed) return;
    if (_isOnline()) {
      final seenScopes = <String>{};
      // The global lane is busy while any of its requests is in flight,
      // including a discarded one that has not settled yet.
      var globalSeen = _entries.any((e) => e.scope == null && e.sending);
      // Same for a scope, whatever the position of its request in flight:
      // a restored call may sit before a call made before hydrate.
      final busyScopes = {
        for (final e in _entries)
          if (e.sending && e.scope != null) e.scope!,
      };
      for (final e in _entries.toList()) {
        if (_sending >= _maxConcurrent) break;
        final scope = e.scope;
        if (scope == null) {
          // A failed entry left the global lane's order.
          if (e.needsDecision || globalSeen) continue;
          globalSeen = true;
        } else {
          if (!seenScopes.add(scope) || busyScopes.contains(scope)) continue;
          // A blocked head holds its scope.
          if (e.needsDecision) continue;
        }
        // A reserved call still running onMutate holds its lane.
        if (!e.ready || e.sending || e.writing || e.retryTimer != null) {
          continue;
        }
        _send(e);
      }
    }
    _notifyWaiting();
    _scheduleChange();
  }

  /// Sends the new [entries] on [entriesStream] once the current
  /// synchronous run is over, if they show something new.
  void _scheduleChange() {
    if (!_changes.hasListener) {
      // Nobody saw the last snapshot: the next listener gets the next one.
      _lastSignature = null;
      return;
    }
    if (_changeScheduled) return;
    _changeScheduled = true;
    scheduleMicrotask(() {
      _changeScheduled = false;
      if (_isDisposed) return;
      final current = entries;
      final signature = _signatureOf(current);
      if (_sameSignature(signature, _lastSignature)) return;
      _lastSignature = signature;
      _changes.add(current);
    });
  }

  static List<Object?> _signatureOf(List<QueuedMutation> entries) => [
        for (final e in entries) ...[
          e.mutationId,
          e.status,
          e.attempts,
          e.lastError,
          e.variables,
        ],
      ];

  static bool _sameSignature(List<Object?> a, List<Object?>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i]) && a[i] != b[i]) return false;
    }
    return true;
  }

  void _notifyWaiting() {
    final online = _isOnline();
    final blockedScopes = <String>{};
    // Lanes whose head waits for a retry delay: the calls behind it wait too.
    final backingOff = <Object>{
      for (final e in _entries)
        if (e.retryTimer != null) e.scope ?? _globalLane,
    };
    for (final e in _entries.toList()) {
      final status = _statusOf(e, blockedScopes);
      if (!e.ready) continue;
      final waiting = status == QueuedMutationStatus.held ||
          (status == QueuedMutationStatus.blocked && e.lastError == null) ||
          (status == QueuedMutationStatus.queued &&
              (!online ||
                  e.retryTimer != null ||
                  backingOff.contains(e.scope ?? _globalLane)));
      if (waiting) e.listener?.onParked();
    }
  }

  void _send(_Entry e) {
    e.sending = true;
    _sending++;
    // Reported once until it settles, not on every attempt.
    if (e.listener == null && !e.tracked) {
      e.tracked = true;
      _track?.call(
        _trackId(e),
        MutationPending<Object?, Object?>(variables: e.variables),
        _trackMetadata(e),
      );
    }
    unawaited(_run(e));
  }

  /// The id under which a call without a caller reports to
  /// `QoraClient.mutationEvents`.
  static String _trackId(_Entry e) => 'queue:${e.mutationId}';

  static Map<String, Object?> _trackMetadata(_Entry e) => {
        'mutationKey': e.key,
        'mutationId': e.mutationId,
        if (e.scope != null) 'scope': e.scope,
      };

  Future<void> _run(_Entry e) async {
    final variables = e.variables;
    final meta = MutationMeta(mutationId: e.mutationId, attempt: e.attempts);
    Object? data;
    Object? error;
    StackTrace? stackTrace;
    try {
      data = await e.registration.runErased(e.payload, meta);
    } catch (err, st) {
      error = err;
      stackTrace = st;
    }
    e.sending = false;
    _sending--;
    if (_isDisposed) return;

    if (error == null) {
      _unpersist(e);
      _entries.remove(e);
      _log?.call('Mutation queue: sent ${e.key} (${e.mutationId})');
      final listener = e.listener;
      _pump();
      await _guard(() async {
        if (listener != null) {
          await listener.onSuccess(data, variables);
        } else {
          // No caller left (restored after a restart, or retried after the
          // call site settled): report to mutationEvents instead. A call
          // discarded in flight already reported how it ended.
          if (!e.dropWhenSettled) {
            e.tracked = false;
            _track?.call(
              _trackId(e),
              MutationSuccess<Object?, Object?>(
                data: data,
                variables: variables,
              ),
              _trackMetadata(e),
            );
          }
          await _invalidateRegistration(e.registration);
        }
      });
      return;
    }

    if (e.dropWhenSettled) {
      _entries.remove(e);
      _pump();
      return;
    }

    e.lastError = error;
    final permanent = _isPermanent(e, error);
    if (!permanent && !_isOnline()) {
      // Lost the network mid-request: not the call's fault. Resent on
      // reconnect without spending an attempt.
      _persist(e);
      _pump();
      return;
    }
    e.attempts++;
    if (permanent || e.attempts >= _config.maxAttempts) {
      e.needsDecision = true;
      _log?.call('Mutation queue: ${e.key} (${e.mutationId}) failed for good '
          'after ${e.attempts} attempt(s): $error');
      // The call site settles once. Its onMutate snapshot is stale by the
      // time the app retries, so a later outcome only runs the
      // registration's invalidations.
      final listener = e.listener;
      e.listener = null;
      _persist(e);
      _pump();
      if (listener == null) {
        e.tracked = false;
        _track?.call(
          _trackId(e),
          MutationFailure<Object?, Object?>(
            error: error,
            stackTrace: stackTrace,
            variables: variables,
          ),
          _trackMetadata(e),
        );
      }
      await _guard(
        () async => listener?.onFailure(error!, stackTrace!, variables),
      );
      return;
    }

    final delay = _config.delayAfter(e.attempts, _random);
    _log?.call('Mutation queue: ${e.key} (${e.mutationId}) attempt '
        '${e.attempts} failed, retrying in $delay: $error');
    e.retryTimer = Timer(delay, () {
      e.retryTimer = null;
      _pump();
    });
    _persist(e);
    _pump();
  }

  bool _isPermanent(_Entry e, Object error) {
    final predicate = e.registration.isPermanent ?? _config.isPermanent;
    if (predicate == null) return false;
    try {
      return predicate(error);
    } catch (predicateError) {
      // A predicate that cannot classify the error must not retry forever.
      _log?.call('Mutation queue: isPermanent threw $predicateError for '
          '${e.key}; treating the error as permanent');
      return true;
    }
  }

  Future<void> _invalidateRegistration(
    MutationRegistration<Object?, Object?> registration,
  ) async {
    if (registration.invalidates case final keys?
        when _invalidateQuery != null) {
      for (final key in keys) {
        await _invalidateQuery(key);
      }
    }
    if (registration.invalidatesTags case final tags?
        when _invalidateTags != null) {
      await _invalidateTags(tags);
    }
  }

  /// Callbacks are app code: an error in one must not stop the queue.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (error, stackTrace) {
      Zone.current.handleUncaughtError(error, stackTrace);
    }
  }

  void _drop(_Entry e, {required bool settle}) {
    e.retryTimer?.cancel();
    e.retryTimer = null;
    final listener = e.listener;
    e.listener = null;
    // Before release, the pending release reports what happened instead.
    if (listener != null && e.ready) {
      final reason = settle
          ? MutationDiscardedException(mutationId: e.mutationId, key: e.key)
          : null;
      unawaited(_guard(() => listener.onDropped(reason)));
    }
    if (settle && e.tracked) {
      // Reported as pending to mutationEvents: report how it ended.
      e.tracked = false;
      _track?.call(
        _trackId(e),
        MutationFailure<Object?, Object?>(
          error:
              MutationDiscardedException(mutationId: e.mutationId, key: e.key),
          stackTrace: StackTrace.current,
          variables: e.variables,
        ),
        _trackMetadata(e),
      );
    }
    if (e.sending) e.dropWhenSettled = true;
  }

  /// After [entry] left its scope without succeeding, the calls behind it
  /// may target a record that will never exist: they wait for a decision.
  void _blockFollowers(_Entry entry) {
    final scope = entry.scope;
    if (scope == null) return;
    var behind = false;
    for (final e in _entries) {
      if (identical(e, entry)) {
        behind = true;
      } else if (behind && e.scope == scope && !e.dropWhenSettled) {
        e.needsDecision = true;
        _persist(e);
      }
    }
  }

  // ── Storage ──────────────────────────────────────────────────────────────

  static const _storagePrefix = 'qora:mutation:';
  static const _recordVersion = 1;
  static final _tombstone =
      jsonEncode({'version': _recordVersion, 'status': 'discarded'});

  /// The record that marks a call as discarded: a restore deletes it instead
  /// of sending the call.
  @internal
  static String get tombstone => _tombstone;

  String _nextStorageKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastSequence = now > _lastSequence ? now : _lastSequence + 1;
    return '$_storagePrefix${_lastSequence.toString().padLeft(20, '0')}';
  }

  String _record(_Entry e) => jsonEncode({
        'version': _recordVersion,
        'mutationId': e.mutationId,
        'key': e.key,
        'scope': e.scope,
        // Encoded once: every attempt replays the exact stored payload.
        'variables': jsonDecode(e.storedVariables!),
        'enqueuedAt': e.enqueuedAt.millisecondsSinceEpoch,
        'attempts': e.attempts,
        'lastError': e.lastError?.toString(),
        'status': e.needsDecision
            ? (e.scope == null ? 'failed' : 'blocked')
            : 'queued',
      });

  _Entry? _fromRecord(String storageKey, Map<String, dynamic> record) {
    try {
      if (record['version'] != _recordVersion) {
        _log?.call('Mutation queue: unknown record version at '
            '"$storageKey", skipping');
        return null;
      }
      final key = record['key'] as String;
      final registration = _registry.entryOf(key);
      if (registration == null) {
        _log?.call('Mutation queue: "$key" is not registered, skipping '
            '"$storageKey". Register it before hydrate().');
        return null;
      }
      final json = record['variables'];
      final variables = registration.decodeVariables(json);
      final stored = jsonEncode(json);
      final status = record['status'] as String?;
      return _Entry(
        mutationId: record['mutationId'] as String,
        key: key,
        scope: record['scope'] as String?,
        variables: variables,
        registration: registration,
        listener: null,
        enqueuedAt: DateTime.fromMillisecondsSinceEpoch(
          record['enqueuedAt'] as int,
        ),
      )
        ..storageKey = storageKey
        ..fromStorage = true
        ..storedVariables = stored
        ..payload = variables
        ..attempts = record['attempts'] as int? ?? 0
        ..lastError = record['lastError']
        ..needsDecision = status == 'blocked' || status == 'failed'
        ..ready = true;
    } catch (error) {
      _log?.call('Mutation queue: cannot restore "$storageKey": $error, '
          'skipping');
      return null;
    }
  }

  /// Rewrites [e]'s record after a change. Writes and deletes of one call
  /// run in order, so a late write never brings back a deleted record.
  void _persist(_Entry e) {
    final storage = _storage;
    final storageKey = e.storageKey;
    // A reserved call is written by release, with its state at that time.
    if (storage == null || storageKey == null || !e.ready) return;
    final record = _record(e);
    e.storeOp = e.storeOp.then((_) => storage.write(storageKey, record)).then(
          (_) {},
          onError: (Object error) => _log?.call(
            'Mutation queue: could not update "$storageKey": $error',
          ),
        );
  }

  /// Deletes [e]'s record.
  ///
  /// A [discarded] call is first overwritten with a tombstone: if the delete
  /// fails, the next restore deletes the tombstone instead of sending a write
  /// the user gave up. A sent call needs none: sending it again is the
  /// at-least-once delivery the server already deduplicates.
  void _unpersist(_Entry e, {bool discarded = false}) {
    final storage = _storage;
    final storageKey = e.storageKey;
    if (storage == null || storageKey == null) return;
    e.storageKey = null;
    void log(Object error) =>
        _log?.call('Mutation queue: could not delete "$storageKey": $error');
    var op = e.storeOp;
    if (discarded) {
      op = op
          .then((_) => storage.write(storageKey, _tombstone))
          .then((_) {}, onError: log);
    }
    final delete =
        op.then((_) => storage.delete(storageKey)).then((_) {}, onError: log);
    e.storeOp = delete;
    _pendingDeletes[storageKey] = delete;
    unawaited(
      delete.whenComplete(() {
        if (identical(_pendingDeletes[storageKey], delete)) {
          _pendingDeletes.remove(storageKey);
        }
      }),
    );
  }

  void _removeIfIdle(_Entry e) {
    if (!e.sending) _entries.remove(e);
  }

  _Entry _find(String mutationId) =>
      _findOrNull(mutationId) ??
      (throw StateError('No queued mutation has the id "$mutationId".'));

  _Entry? _findOrNull(String mutationId) {
    for (final e in _entries) {
      if (e.mutationId == mutationId && !e.dropWhenSettled) return e;
    }
    return null;
  }

  /// Whether the client that owns this queue was disposed.
  @internal
  bool get isDisposed => _isDisposed;

  void _assertNotDisposed() {
    if (_isDisposed) throw StateError('MutationQueue has been disposed.');
  }

  static const Object _keep = Object();
  static const Object _globalLane = Object();
}

class _Entry {
  _Entry({
    required this.mutationId,
    required this.key,
    required this.scope,
    required this.variables,
    required this.registration,
    required this.listener,
    DateTime? enqueuedAt,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();

  String mutationId;
  final String key;
  final String? scope;
  Object? variables;

  /// What the mutator receives: with storage, [variables] decoded from
  /// what was stored, so every attempt sends what a replay would.
  late Object? payload = variables;

  /// A retry whose record is being rewritten; not sent until it is stored.
  bool writing = false;
  final DateTime enqueuedAt;
  final MutationRegistration<Object?, Object?> registration;
  QueuedCallListener? listener;

  int attempts = 0;
  Object? lastError;

  /// Set once the call site's onMutate finished; until then the call holds
  /// its lane without being sent.
  bool ready = false;

  /// Restored from storage rather than made in this session.
  bool fromStorage = false;

  /// Failed for good, or orphaned by a discard: waits for retry or discard.
  bool needsDecision = false;
  bool sending = false;

  /// Discarded while its request was in flight.
  bool dropWhenSettled = false;
  Timer? retryTimer;

  /// Where the call is stored, or `null` when it is not (no storage, not
  /// released yet, or deleted).
  String? storageKey;

  /// The variables as stored, as JSON text.
  String? storedVariables;

  /// Reported as pending to `mutationEvents`, with no outcome reported yet.
  bool tracked = false;

  /// The last storage operation of this call; the next one waits for it.
  Future<void> storeOp = Future<void>.value();

  QueuedMutation snapshot(QueuedMutationStatus status) => QueuedMutation(
        mutationId: mutationId,
        key: key,
        scope: scope,
        // What is sent: with persistence, the copy decoded from storage.
        variables: payload,
        enqueuedAt: enqueuedAt,
        attempts: attempts,
        lastError: lastError,
        status: status,
      );
}

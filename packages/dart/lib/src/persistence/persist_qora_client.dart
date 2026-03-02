import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/key/qora_key.dart';

import 'qora_serializer.dart';
import 'storage_adapter.dart';

// ── Internal: on-disk envelope ───────────────────────────────────────────────

/// JSON envelope written to [StorageAdapter] for every persisted query.
///
/// Stores the serialised data alongside metadata needed for TTL checks and
/// type-safe deserialization during [PersistQoraClient.hydrate].
class _StorageEntry {
  final String typeName;
  final dynamic data;
  final int persistedAtMs;

  /// `null` means "use the global [PersistQoraClient._persistDuration]".
  final int? ttlMs;

  const _StorageEntry({
    required this.typeName,
    required this.data,
    required this.persistedAtMs,
    this.ttlMs,
  });

  bool isExpired(Duration fallbackTtl) {
    final effectiveMs = ttlMs ?? fallbackTtl.inMilliseconds;
    if (effectiveMs == 0) return false; // Duration.zero → never expires
    final age = DateTime.now().millisecondsSinceEpoch - persistedAtMs;
    return age > effectiveMs;
  }

  Map<String, dynamic> toMap() => {
        'typeName': typeName,
        'data': data,
        'persistedAtMs': persistedAtMs,
        if (ttlMs != null) 'ttlMs': ttlMs,
      };

  factory _StorageEntry.fromMap(Map<String, dynamic> map) => _StorageEntry(
        typeName: map['typeName'] as String,
        data: map['data'],
        persistedAtMs: map['persistedAtMs'] as int,
        ttlMs: map['ttlMs'] as int?,
      );
}

// ── PersistQoraClient ────────────────────────────────────────────────────────

/// A [QoraClient] that automatically persists query results to a
/// [StorageAdapter] and restores them on startup (offline-first).
///
/// ## Quick start
///
/// ```dart
/// // 1. Create with a storage backend (swap InMemory for Hive/Isar/etc.)
/// final client = PersistQoraClient(
///   storage: InMemoryStorageAdapter(),
///   persistDuration: Duration(days: 7),
/// );
///
/// // 2. Register a serializer for every type you want to persist.
/// //    Pass `name:` explicitly when targeting Flutter Web or --obfuscate.
/// client.registerSerializer<User>(
///   QoraSerializer(toJson: (u) => u.toJson(), fromJson: User.fromJson),
///   name: 'User',
/// );
/// client.registerSerializer<List<Post>>(
///   QoraSerializer(
///     toJson:   (posts) => posts.map((p) => p.toJson()).toList(),
///     fromJson: (json)  => (json as List).map((e) => Post.fromJson(e)).toList(),
///   ),
///   name: 'List<Post>',
/// );
///
/// // 3. Warm the cache from disk before the first widget builds.
/// await client.storage.init();
/// await client.hydrate();
///
/// runApp(QoraScope(client: client, child: const MyApp()));
/// ```
///
/// ## Auto-persist
///
/// After every successful fetch for a type that has a registered serializer,
/// the result is written to [StorageAdapter] as a JSON string containing the
/// serialised data, a type discriminator ([typeName]), and TTL metadata.
///
/// Both direct fetches and SWR background revalidations are persisted because
/// both paths go through [QoraClient._doFetch], which calls [onFetchSuccess].
///
/// ## Hydration
///
/// [hydrate] reads all stored entries, evaluates TTL, deserializes valid
/// entries using the registered serializers, and calls [queueHydration] on
/// the base [QoraClient]. The actual injection into the typed cache happens
/// lazily on the first typed API call ([fetchQuery], [watchQuery], etc.)
/// to avoid Dart runtime cast failures (see [QoraClient._applyPendingHydration]).
///
/// The restored [Success] state carries the original `persistedAt` timestamp
/// as `updatedAt`, so [QoraOptions.staleTime] works correctly: if the data is
/// older than `staleTime`, the first [watchQuery] mount triggers a SWR
/// background revalidation automatically.
///
/// ## Storage eviction
///
/// | Method             | In-memory cache | [StorageAdapter] |
/// |--------------------|-----------------|------------------|
/// | [invalidate]       | Marks stale     | **Untouched**    |
/// | [removeQuery]      | Removed         | Deleted          |
/// | [clear]            | Cleared         | Cleared          |
/// | [evictFromStorage] | Untouched       | Deleted          |
///
/// ## Name-based registration (obfuscation-safe)
///
/// ```dart
/// // Without name: uses T.toString() — unsafe on Flutter Web / --obfuscate
/// client.registerSerializer<User>(serializer);
///
/// // With explicit name: always stable
/// client.registerSerializer<User>(serializer, name: 'User');
/// ```
class PersistQoraClient extends QoraClient {
  final StorageAdapter _storage;
  final Duration _persistDuration;

  /// `typeName  → serializer`  (looked up during [hydrate] and [_persistEntry])
  final Map<String, QoraSerializer<dynamic>> _serializersByName = {};

  /// `Type → typeName`  (reverse lookup: from `T` in [onFetchSuccess] to name)
  final Map<Type, String> _typeNames = {};

  /// Creates a [PersistQoraClient].
  ///
  /// [storage] must be initialised ([StorageAdapter.init]) before calling
  /// [hydrate].
  ///
  /// [persistDuration] is the default TTL written to [StorageAdapter] for
  /// every persisted entry. Pass [Duration.zero] to persist indefinitely
  /// (rely on explicit [removeQuery] / [evictFromStorage] for cleanup).
  PersistQoraClient({
    required StorageAdapter storage,
    Duration persistDuration = const Duration(days: 7),
    super.config,
    super.tracker,
  })  : _storage = storage,
        _persistDuration = persistDuration;

  // ── Serializer registry ───────────────────────────────────────────────────

  /// Register a [QoraSerializer] for type [T].
  ///
  /// [name] is the stable string identifier written as the type discriminator
  /// in [StorageAdapter]. It is used during [hydrate] to find the correct
  /// deserializer without knowing the compile-time type.
  ///
  /// - If [name] is omitted, defaults to `T.toString()` (e.g. `'User'`,
  ///   `'List<Post>'`).
  /// - **Pass an explicit [name] when targeting Flutter Web or enabling Dart
  ///   obfuscation** (`--obfuscate`), since `T.toString()` may be replaced by
  ///   a minified identifier in those configurations.
  /// - [name] must remain **stable across app versions**. Changing it
  ///   invalidates all previously persisted entries for that type.
  ///
  /// Calling [registerSerializer] twice for the same [T] or [name] silently
  /// replaces the previous registration.
  void registerSerializer<T>(
    QoraSerializer<T> serializer, {
    String? name,
  }) {
    final typeName = name ?? T.toString();
    _serializersByName[typeName] = serializer as QoraSerializer<dynamic>;
    _typeNames[T] = typeName;
  }

  // ── Hydration ─────────────────────────────────────────────────────────────

  /// Load all valid persisted entries from [StorageAdapter] into the base
  /// [QoraClient]'s pending hydration queue, ready to be injected into the
  /// typed cache on the first access.
  ///
  /// ### Bootstrap order
  ///
  /// Call once at startup, **after** all serializers have been registered and
  /// **before** any widget builds (or any [fetchQuery] / [watchQuery] call).
  /// Awaiting [hydrate] before [runApp] guarantees the cache is warm on the
  /// very first frame — no spinner, no empty state flicker:
  ///
  /// ```dart
  /// // Typical Flutter bootstrap
  /// Future<void> main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await storage.init();
  ///   client.registerSerializer<User>(...);
  ///   await client.hydrate();   // ← warm cache before first frame
  ///   runApp(...);
  /// }
  /// ```
  ///
  /// If your storage has a large number of entries and [hydrate] is noticeably
  /// slow (measurable via profiling), show a **splash screen** while the
  /// [Future] is in flight rather than blocking [runApp]:
  ///
  /// ```dart
  /// runApp(
  ///   QoraScope(
  ///     client: client,
  ///     child: FutureBuilder<void>(
  ///       future: storage.init().then((_) => client.hydrate()),
  ///       builder: (context, snapshot) {
  ///         if (snapshot.connectionState != ConnectionState.done) {
  ///           return const MaterialApp(home: SplashScreen());
  ///         }
  ///         return const MyApp();
  ///       },
  ///     ),
  ///   ),
  /// );
  /// ```
  ///
  /// ### Per-entry behaviour
  ///
  /// | Condition                       | Action                          |
  /// |---------------------------------|---------------------------------|
  /// | JSON decode failure             | Delete from storage, skip       |
  /// | TTL expired                     | Delete from storage, skip       |
  /// | No serializer registered        | Log (debugMode), skip           |
  /// | [fromJson] throws               | Delete from storage, log, skip  |
  /// | Valid                           | Add to pending hydration queue  |
  ///
  /// ### Model versioning
  ///
  /// If your model schema changes between app releases — a required field
  /// added, a field renamed, a type changed — persisted entries written by
  /// the old version may throw in [fromJson]. [hydrate] catches every such
  /// exception, logs a warning (when [QoraClientConfig.debugMode] is `true`),
  /// deletes the corrupt entry from storage, and continues. The app never
  /// crashes because of a stale schema on disk.
  ///
  /// Your responsibility is a defensive [fromJson] that handles both old and
  /// new shapes:
  ///
  /// ```dart
  /// factory User.fromJson(dynamic json) {
  ///   final map = json as Map<String, dynamic>;
  ///   return User(
  ///     id:        map['id'] as int,
  ///     name:      map['name'] as String,
  ///     // Added in v2 — fall back to empty string for v1 entries on disk
  ///     avatarUrl: map['avatarUrl'] as String? ?? '',
  ///   );
  /// }
  /// ```
  ///
  /// For **breaking changes** with no safe default (type change, field
  /// removal), bump the serializer [name] — e.g. `'User'` → `'User_v2'`.
  /// Old entries are silently skipped (no matching serializer), the next
  /// fetch writes a fresh entry under the new name, and the old entries
  /// are cleaned up by TTL expiry.
  ///
  /// Hydration is idempotent — calling it multiple times is safe but
  /// redundant.
  Future<void> hydrate() async {
    final allKeys = await _storage.keys();

    for (final storageKey in allKeys) {
      final raw = await _storage.read(storageKey);
      if (raw == null) continue;

      _StorageEntry envelope;
      try {
        envelope = _StorageEntry.fromMap(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        _persistLog('Corrupt entry at "$storageKey" — deleting');
        await _storage.delete(storageKey);
        continue;
      }

      if (envelope.isExpired(_persistDuration)) {
        _persistLog(
          'Expired "${envelope.typeName}" at "$storageKey" — deleting',
        );
        await _storage.delete(storageKey);
        continue;
      }

      final serializer = _serializersByName[envelope.typeName];
      if (serializer == null) {
        _persistLog(
          'No serializer for "${envelope.typeName}" — skipping "$storageKey". '
          'Call registerSerializer<${envelope.typeName}>() before hydrate().',
        );
        continue;
      }

      dynamic data;
      try {
        data = serializer.fromJson(envelope.data);
      } catch (e) {
        _persistLog(
          'fromJson failed for "${envelope.typeName}" '
          'at "$storageKey": $e — deleting',
        );
        await _storage.delete(storageKey);
        continue;
      }

      // storageKey is already a JSON-encoded normalised key — pass it directly
      // as the raw key. queueHydration normalizes internally, producing the
      // same encoding used by _encodeStorageKey.
      final queueKey = jsonDecode(storageKey);
      queueHydration(
        queueKey as Object,
        data,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(envelope.persistedAtMs),
      );
      _persistLog(
        'Queued "${envelope.typeName}" for lazy hydration ($storageKey)',
      );
    }
  }

  // ── Auto-persist: hook called after every successful fetch ────────────────

  @override
  @visibleForOverriding
  void onFetchSuccess<T>(List<dynamic> key, T data) {
    // Fire-and-forget. Errors are caught inside _persistEntry.
    unawaited(_persistEntry<T>(key, data));
  }

  // ── Eviction overrides ────────────────────────────────────────────────────

  @override
  void removeQuery(Object key) {
    super.removeQuery(key);
    removeHydrationEntry(key);
    unawaited(_storage.delete(_encodeStorageKey(normalizeKey(key))));
  }

  @override
  void clear() {
    super.clear();
    clearHydrationQueue();
    unawaited(clearStorage());
  }

  // ── Storage utilities ─────────────────────────────────────────────────────

  /// Delete all entries from [StorageAdapter] without affecting the
  /// in-memory cache.
  ///
  /// Use [clear] to wipe both in-memory cache and storage simultaneously.
  Future<void> clearStorage() => _storage.clear();

  /// Force-persist the current cached value for [key] to [StorageAdapter].
  ///
  /// No-op if the query is not in [Success] state or [T] has no registered
  /// serializer. [ttl] overrides the global [persistDuration] for this entry.
  Future<void> persistQuery<T>(Object key, {Duration? ttl}) async {
    final data = getQueryData<T>(key);
    if (data == null) return;
    await _persistEntry<T>(normalizeKey(key), data, ttl: ttl);
  }

  /// Delete the persisted entry for [key] from [StorageAdapter] only.
  ///
  /// The in-memory cache is untouched. Use [removeQuery] to remove from both.
  Future<void> evictFromStorage(Object key) => _storage.delete(_encodeStorageKey(normalizeKey(key)));

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _persistEntry<T>(
    List<dynamic> key,
    T data, {
    Duration? ttl,
  }) async {
    final typeName = _typeNames[T];
    if (typeName == null) return; // No serializer for T — skip silently.

    final serializer = _serializersByName[typeName]!;

    dynamic serialized;
    try {
      serialized = serializer.toJson(data);
    } catch (e) {
      _persistLog('toJson failed for "$typeName": $e');
      return;
    }

    final effectiveTtl = ttl ?? _persistDuration;
    final envelope = _StorageEntry(
      typeName: typeName,
      data: serialized,
      persistedAtMs: DateTime.now().millisecondsSinceEpoch,
      // Duration.zero → null so isExpired() returns false (indefinite).
      ttlMs: effectiveTtl.inMilliseconds == 0 ? null : effectiveTtl.inMilliseconds,
    );

    final storageKey = _encodeStorageKey(key);
    try {
      await _storage.write(storageKey, jsonEncode(envelope.toMap()));
      _persistLog('Persisted "$typeName" → "$storageKey"');
    } catch (e) {
      _persistLog('Storage write failed for "$storageKey": $e');
    }
  }

  /// Encodes a normalised query key to a stable JSON string used as the
  /// storage key. [normalizeKey] guarantees all parts are JSON-encodable.
  String _encodeStorageKey(List<dynamic> key) => jsonEncode(key);

  void _persistLog(String message) {
    if (config.debugMode) {
      // ignore: avoid_print
      print('[PersistQora] $message');
    }
  }
}

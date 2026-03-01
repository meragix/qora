/// Low-level key/value storage contract for Qora persistence.
///
/// Implementations store raw JSON strings keyed by a stable string derived
/// from the query key. The serialisation envelope — TTL, type discriminator,
/// data — is managed entirely by [PersistQoraClient]; adapters only handle
/// opaque strings and need no knowledge of Qora internals.
///
/// ## Available adapters
///
/// | Package                        | Backend            |
/// |--------------------------------|--------------------|
/// | `qora` (built-in)              | [InMemoryStorageAdapter] |
/// | `qora_storage_hive`            | Hive               |
/// | `qora_storage_isar`            | Isar               |
/// | `qora_storage_drift`           | Drift / SQLite     |
/// | `qora_storage_shared_prefs`    | SharedPreferences  |
///
/// ## Implementing a custom adapter
///
/// ```dart
/// class MyAdapter implements StorageAdapter {
///   @override
///   Future<void> init() async { /* open DB, load file, etc. */ }
///
///   @override
///   Future<String?> read(String key) async => /* … */;
///
///   @override
///   Future<void> write(String key, String value) async { /* … */ }
///
///   @override
///   Future<void> delete(String key) async { /* … */ }
///
///   @override
///   Future<List<String>> keys() async => /* … */;
///
///   @override
///   Future<void> clear() async { /* … */ }
///
///   @override
///   Future<void> dispose() async { /* release resources */ }
/// }
/// ```
abstract interface class StorageAdapter {
  /// Initialise the underlying storage backend.
  ///
  /// Must be called and awaited once before any other method.
  /// Calling [init] multiple times must be safe (idempotent).
  Future<void> init();

  /// Returns the raw value stored under [key], or `null` if absent.
  Future<String?> read(String key);

  /// Persists [value] under [key], overwriting any previous value.
  Future<void> write(String key, String value);

  /// Removes the entry for [key]. No-op if the key does not exist.
  Future<void> delete(String key);

  /// Returns all keys currently held in the store.
  ///
  /// The order of the returned list is unspecified.
  Future<List<String>> keys();

  /// Removes **all** entries from the store.
  Future<void> clear();

  /// Releases any resources held by this adapter (open file handles,
  /// database connections, etc.).
  Future<void> dispose();
}

/// In-memory [StorageAdapter] backed by a plain [Map].
///
/// All operations complete synchronously (wrapped in resolved [Future]s).
///
/// Intended for:
/// - Unit and integration tests — no I/O, no setup required.
/// - Verifying hydration logic in isolation before wiring a real backend.
/// - Temporary in-process caching without any disk persistence.
///
/// **Data is lost when the process terminates.**
///
/// ```dart
/// final adapter = InMemoryStorageAdapter();
/// await adapter.init(); // no-op, keeps API consistent with other adapters
///
/// final client = PersistQoraClient(storage: adapter);
/// client.registerSerializer<User>(userSerializer);
/// await client.hydrate();
/// ```
class InMemoryStorageAdapter implements StorageAdapter {
  final Map<String, String> _store = {};

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<List<String>> keys() async => _store.keys.toList();

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> dispose() async => _store.clear();
}

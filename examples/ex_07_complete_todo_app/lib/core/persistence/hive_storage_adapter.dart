import 'package:hive_flutter/hive_flutter.dart';
import 'package:qora_flutter/qora_flutter.dart';

/// A [StorageAdapter] backed by [Hive] for persistent on-device caching.
///
/// All keys and values are stored as raw strings (JSON encoded by
/// [PersistQoraClient]). This adapter has no knowledge of Qora internals.
///
/// ## Usage
///
/// ```dart
/// final storage = await HiveStorageAdapter.open('qora_cache');
/// final client = PersistQoraClient(storage: storage, ...);
/// ```
class HiveStorageAdapter implements StorageAdapter {
  final Box<String> _box;

  HiveStorageAdapter._(this._box);

  /// Opens (or creates) a named Hive box and returns a ready-to-use adapter.
  ///
  /// Initialises Flutter Hive paths on first call — subsequent calls are
  /// idempotent.
  static Future<HiveStorageAdapter> open(String boxName) async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(boxName);
    return HiveStorageAdapter._(box);
  }

  @override
  Future<void> init() async {
    // Already initialised in [open]. This is a no-op to satisfy the interface.
  }

  @override
  Future<String?> read(String key) async => _box.get(key);

  @override
  Future<void> write(String key, String value) async {
    await _box.put(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  @override
  Future<List<String>> keys() async => _box.keys.whereType<String>().toList();

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Future<void> dispose() async {
    await _box.close();
  }
}

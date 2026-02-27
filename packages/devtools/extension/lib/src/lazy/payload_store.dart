import 'dart:collection';
import 'dart:typed_data';

/// In-memory bounded store for lazy payload chunks.
///
/// It enforces:
/// - TTL expiration per payload,
/// - global byte cap,
/// - LRU eviction order.
class PayloadStore {
  /// Creates a payload store.
  PayloadStore({
    this.maxBytes = 20 * 1024 * 1024,
    this.ttl = const Duration(seconds: 30),
  });

  /// Maximum total bytes retained by this store.
  final int maxBytes;

  /// Maximum lifetime for an entry.
  final Duration ttl;

  final LinkedHashMap<String, _PayloadEntry> _entries =
      LinkedHashMap<String, _PayloadEntry>();
  int _totalBytes = 0;

  /// Current memory usage in bytes.
  int get totalBytes => _totalBytes;

  /// Current number of stored payload ids.
  int get count => _entries.length;

  /// Stores [chunks] under [payloadId].
  void put(String payloadId, List<Uint8List> chunks) {
    _evictExpired();
    remove(payloadId);

    final size = chunks.fold<int>(0, (sum, c) => sum + c.length);
    _entries[payloadId] = _PayloadEntry(
      chunks: List<Uint8List>.unmodifiable(chunks),
      createdAt: DateTime.now(),
      sizeBytes: size,
    );
    _totalBytes += size;
    _evictToBudget();
  }

  /// Returns one chunk for [payloadId] and [chunkIndex].
  ///
  /// `null` is returned when the payload does not exist, expired, or index is
  /// out of range.
  Uint8List? getChunk(String payloadId, int chunkIndex) {
    _evictExpired();
    final entry = _entries.remove(payloadId);
    if (entry == null) {
      return null;
    }
    if (_isExpired(entry)) {
      _totalBytes -= entry.sizeBytes;
      return null;
    }

    // Touch entry to mark it as recently used.
    _entries[payloadId] = entry;
    if (chunkIndex < 0 || chunkIndex >= entry.chunks.length) {
      return null;
    }
    return entry.chunks[chunkIndex];
  }

  /// Returns the number of chunks stored for [payloadId], or `0`.
  int chunkCount(String payloadId) {
    _evictExpired();
    final entry = _entries[payloadId];
    if (entry == null || _isExpired(entry)) {
      return 0;
    }
    return entry.chunks.length;
  }

  /// Removes one payload entry.
  void remove(String payloadId) {
    final removed = _entries.remove(payloadId);
    if (removed != null) {
      _totalBytes -= removed.sizeBytes;
    }
  }

  /// Clears all entries.
  void clear() {
    _entries.clear();
    _totalBytes = 0;
  }

  void _evictExpired() {
    if (_entries.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final expiredKeys = <String>[];
    _entries.forEach((key, value) {
      if (now.difference(value.createdAt) > ttl) {
        expiredKeys.add(key);
      }
    });
    for (final key in expiredKeys) {
      remove(key);
    }
  }

  void _evictToBudget() {
    while (_totalBytes > maxBytes && _entries.isNotEmpty) {
      final lruKey = _entries.keys.first;
      remove(lruKey);
    }
  }

  bool _isExpired(_PayloadEntry entry) =>
      DateTime.now().difference(entry.createdAt) > ttl;
}

final class _PayloadEntry {
  const _PayloadEntry({
    required this.chunks,
    required this.createdAt,
    required this.sizeBytes,
  });

  final List<Uint8List> chunks;
  final DateTime createdAt;
  final int sizeBytes;
}

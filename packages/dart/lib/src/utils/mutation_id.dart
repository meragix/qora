import 'dart:math';

final Random _random = _createRandom();

Random _createRandom() {
  try {
    return Random.secure();
    // Random.secure reports a missing source with an Error, not an Exception.
    // ignore: avoid_catching_errors
  } on UnsupportedError {
    // Some embedders have no secure source. Identifiers only need to be
    // unique, not unpredictable, so a seeded generator is an acceptable
    // fallback.
    return Random();
  }
}

/// Returns a random version 4 UUID, used as a mutation's stable identity.
///
/// Servers commonly accept UUIDs as idempotency keys, which is the reason
/// for the format rather than an arbitrary random string.
String generateMutationId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

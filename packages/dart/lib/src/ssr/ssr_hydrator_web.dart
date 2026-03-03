import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:qora/src/client/qora_client.dart';

/// SSR (Server-Side Rendering) hydrator for Flutter Web.
///
/// Reads the server-rendered cache snapshot injected into
/// `window.__QORA_STATE__` and feeds it into [QoraClient.queueHydration],
/// eliminating the initial loading flash for server-rendered pages.
///
/// ## Server-side setup
///
/// On your server, serialize the prefetched data as a JSON object and embed it
/// in a `<script>` tag **before** your Flutter app boots:
///
/// ```html
/// <script>
///   window.__QORA_STATE__ = {
///     '["users",1]': { "data": {"id": 1, "name": "Ada"}, "updatedAtMs": 1700000000000 },
///     '["posts"]':   { "data": [{"id": 10, "title": "Hello"}] }
///   };
/// </script>
/// <script src="main.dart.js"></script>
/// ```
///
/// ## Flutter setup
///
/// ```dart
/// final client = QoraClient();
/// SsrHydrator(client).hydrate(
///   deserializers: {
///     '["users",1]': (json) => User.fromJson(json as Map<String, dynamic>),
///     '["posts"]':   (json) => (json as List).map(Post.fromJson).toList(),
///   },
/// );
/// runApp(QoraScope(client: client, child: const MyApp()));
/// ```
///
/// ## Security — XSS protection
///
/// Reading from `window.__QORA_STATE__` is safe **only when the server
/// JSON-encodes the payload correctly**. This implementation:
///
/// 1. Uses `dartify()` for the JS → Dart conversion — this produces plain
///    Dart maps/lists/strings, never HTML. No `innerHTML` or `eval` is used.
/// 2. Validates the top-level type (must be a `Map`) before iterating.
/// 3. Validates each entry (must be a `Map` with a `'data'` key) before
///    calling the deserializer.
/// 4. Wraps every deserializer call in a try/catch so a corrupt entry cannot
///    crash the app.
///
/// Your server is responsible for proper JSON encoding. If user-controlled
/// data is embedded in `__QORA_STATE__`, ensure it is JSON-encoded (not
/// raw-HTML-interpolated) to prevent XSS.
class SsrHydrator {
  final QoraClient _client;

  /// Creates an [SsrHydrator] bound to [client].
  const SsrHydrator(this._client);

  /// Read `window.__QORA_STATE__` and enqueue hydration entries into [client].
  ///
  /// [deserializers] is a map from **string-encoded query key** (e.g.
  /// `'["users",1]'`) to a function that converts the raw JSON value (already
  /// converted to a Dart object via `dartify()`) to the typed Dart model.
  ///
  /// Keys in `window.__QORA_STATE__` that are absent from [deserializers] are
  /// silently skipped, so you only need to register the queries you care about.
  ///
  /// If [deserializers] is omitted or `null`, raw `dynamic` values from
  /// `dartify()` are queued directly — useful when your query data is already
  /// a plain `Map`/`List`/`String` without a typed model layer.
  void hydrate({
    Map<String, dynamic Function(dynamic)>? deserializers,
  }) {
    // ── Step 1: safely read window.__QORA_STATE__ ───────────────────────────
    final globalThis = globalContext;
    final jsRaw = globalThis.getProperty('__QORA_STATE__'.toJS);

    if (jsRaw.isUndefined || jsRaw.isNull) return;

    // ── Step 2: convert JS → Dart (JSON-safe, no DOM rendering) ────────────
    // dartify() converts JS objects to Dart Maps/Lists/primitives.
    // It never interprets the content as HTML, eliminating XSS risk from
    // this conversion step.
    final Object? dartRaw = jsRaw.dartify();
    if (dartRaw is! Map) {
      // Unexpected shape — server sent something other than an object.
      _debugLog('window.__QORA_STATE__ is not a Map — skipping SSR hydration');
      return;
    }

    // ── Step 3: iterate entries with strict validation ──────────────────────
    for (final entry in dartRaw.entries) {
      final keyStr = entry.key;
      if (keyStr is! String) continue;

      final value = entry.value;
      if (value is! Map) {
        _debugLog('Skipping "$keyStr": entry is not a Map');
        continue;
      }

      if (!value.containsKey('data')) {
        _debugLog('Skipping "$keyStr": missing required "data" field');
        continue;
      }

      final rawData = value['data'];

      // updatedAtMs is optional; absent → epoch (always stale, triggers SWR).
      final updatedAtMs = value['updatedAtMs'];
      final updatedAt = updatedAtMs is int
          ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs)
          : null;

      // ── Step 4: deserialize with user-supplied function (or pass through) ─
      dynamic data;
      final deserialize = deserializers?[keyStr];
      if (deserialize != null) {
        try {
          data = deserialize(rawData);
        } catch (e) {
          _debugLog('Deserializer failed for "$keyStr": $e — skipping');
          continue;
        }
      } else {
        data = rawData;
      }

      // ── Step 5: parse the key string back into a List and queue ────────────
      // keyStr is a JSON-encoded normalised key (e.g. '["users",1]').
      // queueHydration normalizes it internally, producing the same encoding.
      Object queueKey;
      try {
        final parsed = jsonDecode(keyStr);
        if (parsed is! List) {
          _debugLog('Key "$keyStr" did not parse to a List — skipping');
          continue;
        }
        queueKey = parsed;
      } catch (e) {
        _debugLog('Failed to parse key "$keyStr": $e — skipping');
        continue;
      }

      _client.queueHydration(queueKey, data, updatedAt: updatedAt);
      _debugLog('Queued SSR hydration for "$keyStr"');
    }
  }

  void _debugLog(String message) {
    if (_client.config.debugMode) {
      // ignore: avoid_print
      print('[SsrHydrator] $message');
    }
  }
}

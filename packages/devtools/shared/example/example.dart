// ignore_for_file: avoid_print

import 'package:qora_devtools_shared/qora_devtools_shared.dart';

// ---------------------------------------------------------------------------
// 1. Events — encoding and decoding
//
// Events flow App → DevTools (push via developer.postEvent).
// The runtime bridge calls EventCodec.encode and the UI calls EventCodec.decode.
// ---------------------------------------------------------------------------

void eventEncodingExample() {
  // Build typed events using the named factory constructors.
  // eventId and timestampMs are auto-generated.
  final fetched = QueryEvent.fetched(
    key: '["users",1]',
    status: 'success',
    data: {'id': 1, 'name': 'Alice'},
  );

  final invalidated = QueryEvent.invalidated(key: '["users"]');

  final mutStarted = MutationEvent.started(
    id: 'mut_001',
    key: '["users"]',
    variables: {'name': 'Bob'},
  );

  final mutSettled = MutationEvent.settled(
    id: 'mut_001',
    key: '["users"]',
    success: true,
    result: {'id': 2, 'name': 'Bob'},
  );

  // Encode to JSON-safe map for developer.postEvent.
  final encoded = EventCodec.encode(fetched);
  print('kind:       ${encoded['kind']}'); // query.fetched
  print('queryKey:   ${encoded['queryKey']}'); // ["users",1]

  // Decode back — routing is driven by the `kind` prefix.
  final decoded = EventCodec.decode(EventCodec.encode(fetched));
  if (decoded is QueryEvent) {
    print('type:   ${decoded.type}'); // QueryEventType.fetched
    print('key:    ${decoded.key}'); // ["users",1]
    print('status: ${decoded.status}'); // success
  }

  // Decode all event types via pattern matching.
  for (final event in [fetched, invalidated, mutStarted, mutSettled]) {
    final raw = EventCodec.encode(event);
    switch (EventCodec.decode(raw)) {
      case QueryEvent(:final key, :final type):
        print('Query $type @ $key');
      case MutationEvent(:final id, :final type, :final success):
        print('Mutation $id $type — ok: $success');
      case GenericQoraEvent(:final kind):
        // Unknown kinds fall back here, preserving forward compatibility.
        print('Generic: $kind');
    }
  }
}

// ---------------------------------------------------------------------------
// 2. Large payload path
//
// When a query result exceeds the inline threshold (~80 KB), the event carries
// only metadata. The UI fetches chunks on demand via GetPayloadChunkCommand.
// ---------------------------------------------------------------------------

void largePayloadExample() {
  final event = QueryEvent.fetched(
    key: '["products"]',
    status: 'success',
    hasLargePayload: true,
    payloadId: 'pl_1725012345_a3f',
    totalChunks: 4,
    summary: {'approxBytes': 320000, 'itemCount': 5000},
  );

  final raw = EventCodec.encode(event);
  final decoded = EventCodec.decode(raw) as QueryEvent;

  if (decoded.hasLargePayload) {
    print('Large payload detected');
    print('  payloadId:   ${decoded.payloadId}'); // pl_1725012345_a3f
    print('  totalChunks: ${decoded.totalChunks}'); // 4
    print('  approxBytes: ${decoded.summary?['approxBytes']}'); // 320000

    // The UI then dispatches GetPayloadChunkCommand for each chunk index.
    for (var i = 0; i < decoded.totalChunks!; i++) {
      final cmd = GetPayloadChunkCommand(
        payloadId: decoded.payloadId!,
        chunkIndex: i,
      );
      print('  → chunk $i: ${cmd.method} ${cmd.params}');
    }
  }
}

// ---------------------------------------------------------------------------
// 3. Commands — building and decoding
//
// Commands flow DevTools → App (pull via callServiceExtension).
// The UI creates typed commands; the runtime bridge uses CommandCodec.decode
// to recover them from the serialised form for logging or testing.
// ---------------------------------------------------------------------------

void commandExample() {
  // Build typed commands.
  final refetch = RefetchCommand(queryKey: '["users"]');
  final invalidate = InvalidateCommand(queryKey: '["posts"]');
  final rollback = RollbackOptimisticCommand(queryKey: '["cart"]');
  const snapshot = GetCacheSnapshotCommand();
  final chunk = GetPayloadChunkCommand(payloadId: 'pl_abc', chunkIndex: 0);

  for (final cmd in [refetch, invalidate, rollback, snapshot, chunk]) {
    // Extension name used in callServiceExtension.
    final extensionName = '${QoraExtensionMethods.prefix}.${cmd.method}';
    print('$extensionName  ${cmd.params}');
  }

  // Decode from a JSON map — CommandCodec accepts both short and full names.
  final decoded = CommandCodec.decode({
    'method': 'ext.qora.refetch', // or just 'refetch'
    'params': {'queryKey': '["users"]'},
  });

  if (decoded is RefetchCommand) {
    print('Decoded refetch for: ${decoded.queryKey}'); // ["users"]
  }
}

// ---------------------------------------------------------------------------
// 4. Snapshot DTOs — serialization roundtrip
// ---------------------------------------------------------------------------

void snapshotExample() {
  final snapshot = CacheSnapshot(
    queries: [
      QuerySnapshot(
        key: '["users"]',
        status: 'success',
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        data: [
          {'id': 1, 'name': 'Alice'},
          {'id': 2, 'name': 'Bob'},
        ],
        summary: {'itemCount': 2, 'approxBytes': 512},
      ),
      QuerySnapshot(
        key: '["products"]',
        status: 'success',
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        hasLargePayload: true,
        payloadId: 'pl_1725012345_a3f',
        totalChunks: 4,
        summary: {'itemCount': 5000, 'approxBytes': 320000},
      ),
    ],
    mutations: [
      MutationSnapshot(
        id: 'mut_001',
        key: '["users"]',
        status: 'settled',
        variables: {'name': 'Charlie'},
        result: {'id': 3, 'name': 'Charlie'},
        success: true,
        startedAtMs: DateTime.now().millisecondsSinceEpoch - 120,
        settledAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ],
    emittedAtMs: DateTime.now().millisecondsSinceEpoch,
  );

  // Serialise → transport → deserialise.
  final json = snapshot.toJson();
  final restored = CacheSnapshot.fromJson(json);

  print('queries:   ${restored.queries.length}'); // 2
  print('mutations: ${restored.mutations.length}'); // 1
  print('first key: ${restored.queries.first.key}'); // ["users"]
  print('large:     ${restored.queries.last.hasLargePayload}'); // true
}

// ---------------------------------------------------------------------------
// 5. Timeline events (in-app overlay tracker)
// ---------------------------------------------------------------------------

void timelineExample() {
  final events = [
    TimelineEvent(
      type: TimelineEventType.fetchStarted,
      key: '["users"]',
      timestamp: DateTime.now(),
    ),
    TimelineEvent(
      type: TimelineEventType.mutationStarted,
      key: '["users"]',
      mutationId: 'mut_001',
      timestamp: DateTime.now(),
    ),
    TimelineEvent(
      type: TimelineEventType.mutationSuccess,
      mutationId: 'mut_001',
      timestamp: DateTime.now(),
    ),
    TimelineEvent(
      type: TimelineEventType.cacheCleared,
      timestamp: DateTime.now(),
    ),
  ];

  for (final e in events) {
    // displayName provides a human-readable label for DevTools UI widgets.
    print('${e.type.displayName.padRight(20)} key=${e.key ?? '—'}');
  }
  // Fetch Started          key=["users"]
  // Mutation Started       key=["users"]
  // Mutation Success       key=—
  // Cache Cleared          key=—
}

// ---------------------------------------------------------------------------
// 6. Protocol constants
// ---------------------------------------------------------------------------

void protocolConstantsExample() {
  // VM extension method names — use these instead of hardcoded strings.
  print(QoraExtensionMethods.refetch); // ext.qora.refetch
  print(QoraExtensionMethods.invalidate); // ext.qora.invalidate
  print(QoraExtensionMethods.rollbackOptimistic); // ext.qora.rollbackOptimistic
  print(QoraExtensionMethods.getCacheSnapshot); // ext.qora.getCacheSnapshot
  print(QoraExtensionMethods.getPayloadChunk); // ext.qora.getPayloadChunk

  // VM event stream key — filter the Extension stream by this value.
  print(QoraExtensionEvents.qoraEvent); // qora:event
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  print('=== Events ===');
  eventEncodingExample();

  print('\n=== Large payload ===');
  largePayloadExample();

  print('\n=== Commands ===');
  commandExample();

  print('\n=== Snapshot ===');
  snapshotExample();

  print('\n=== Timeline ===');
  timelineExample();

  print('\n=== Protocol constants ===');
  protocolConstantsExample();
}

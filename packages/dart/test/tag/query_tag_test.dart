import 'dart:async';

import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/config/qora_options.dart';
import 'package:qora/src/key/qora_key.dart';
import 'package:qora/src/state/qora_state.dart';
import 'package:qora/src/tag/query_tag.dart';
import 'package:test/test.dart';

void main() {
  group('QueryTag', () {
    test('serialised without id is just type', () {
      final tag = QueryTag('post');
      expect(tag.serialised, 'post');
    });

    test('serialised with id is type:id', () {
      final tag = QueryTag('post', '123');
      expect(tag.serialised, 'post:123');
    });

    test('equality', () {
      expect(QueryTag('post'), QueryTag('post'));
      expect(QueryTag('post', '123'), QueryTag('post', '123'));
      expect(QueryTag('post'), isNot(QueryTag('user')));
      expect(QueryTag('post', '123'), isNot(QueryTag('post', '456')));
    });
  });

  group('QoraClient tag-based invalidation', () {
    late QoraClient client;

    setUp(() {
      client = QoraClient();
    });

    tearDown(() {
      client.dispose();
    });

    test('providesTags registers tags on fetch', () async {
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1, 'title': 'Hello'},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );

      // Entry should be in Success state.
      var state =
          client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 1]));
      expect(state, isA<Success<Map<String, dynamic>>>());

      // Invalidate the specific tag.
      await client.invalidateTags([QueryTag('post', '1')]);

      // Entry should now be in Loading state (invalidated).
      state = client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 1]));
      expect(state, isA<Loading<Map<String, dynamic>>>());
    });

    test('invalidateTags with wildcard matches all ids', () async {
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 2]),
        fetcher: () async => <String, dynamic>{'id': 2},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '2')],
          staleTime: Duration(minutes: 5),
        ),
      );

      // Wildcard: invalidate all 'post' tags (any id).
      await client.invalidateTags([QueryTag('post')]);

      final state1 =
          client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 1]));
      final state2 =
          client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 2]));
      expect(state1, isA<Loading<Map<String, dynamic>>>());
      expect(state2, isA<Loading<Map<String, dynamic>>>());
    });

    test('invalidateTags specific id does not match other ids', () async {
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 2]),
        fetcher: () async => <String, dynamic>{'id': 2},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '2')],
          staleTime: Duration(minutes: 5),
        ),
      );

      // Only invalidate 'post:1'.
      await client.invalidateTags([QueryTag('post', '1')]);

      final state1 =
          client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 1]));
      final state2 =
          client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 2]));
      expect(state1, isA<Loading<Map<String, dynamic>>>());
      expect(state2, isA<Success<Map<String, dynamic>>>());
    });

    test('removeQuery unregisters tags', () async {
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );

      client.removeQuery(QoraKey(['post', 1]));

      // After re-fetch, tags should be re-registered.
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1, 'updated': true},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );

      await client.invalidateTags([QueryTag('post', '1')]);

      final state =
          client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 1]));
      expect(state, isA<Loading<Map<String, dynamic>>>());
    });

    test('clearCache clears tag index', () async {
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );

      client.clearCache();

      // Re-fetch — tags are re-registered.
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1, 'updated': true},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );

      await client.invalidateTags([QueryTag('post', '1')]);

      final state =
          client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 1]));
      expect(state, isA<Loading<Map<String, dynamic>>>());
    });

    test('QoraOptions merge propagates providesTags', () {
      const base = QoraOptions();
      const withTags = QoraOptions(
        providesTags: [QueryTag('post', '1')],
      );

      final merged = base.merge(withTags);
      expect(merged.providesTags, hasLength(1));
      expect(merged.providesTags!.first.serialised, 'post:1');

      // Base merged with null keeps base tags.
      final baseMerged = withTags.merge(null);
      expect(baseMerged.providesTags, hasLength(1));
    });

    test('invalidateTags is a no-op for unmatched tags', () async {
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );

      await client.invalidateTags([QueryTag('user')]);

      // Entry should still be in Success state.
      final state =
          client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 1]));
      expect(state, isA<Success<Map<String, dynamic>>>());
    });

    test('providesTags replaced on re-fetch', () async {
      // First fetch with tags [post:1, draft].
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1'), QueryTag('draft')],
          staleTime: Duration.zero,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Invalidate so second fetch goes through _doFetch (cache miss route).
      client.invalidate(key: QoraKey(['post', 1]));

      // Second fetch with different tags — replaces [post:1, draft] with [post:1, published].
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1, 'published': true},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1'), QueryTag('published')],
          staleTime: Duration(minutes: 5),
        ),
      );

      // 'draft' tag should no longer match (was replaced by 'published').
      await client.invalidateTags([QueryTag('draft')]);

      var state =
          client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 1]));
      expect(state, isA<Success<Map<String, dynamic>>>());

      // 'published' tag should match.
      await client.invalidateTags([QueryTag('published')]);

      state = client.getQueryState<Map<String, dynamic>>(QoraKey(['post', 1]));
      expect(state, isA<Loading<Map<String, dynamic>>>());
    });

    test(
        'invalidateTags marks entry Loading which triggers full fetch next call',
        () async {
      await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async => <String, dynamic>{'id': 1, 'title': 'Original'},
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );

      // Invalidate — entry transitions to Loading(previousData).
      await client.invalidateTags([QueryTag('post', '1')]);

      // fetchQuery sees Loading (not Success), treats it as cache miss,
      // and fetches fresh data.
      var fetcherCalled = false;
      final result = await client.fetchQuery<Map<String, dynamic>>(
        key: QoraKey(['post', 1]),
        fetcher: () async {
          fetcherCalled = true;
          return <String, dynamic>{'id': 1, 'title': 'Refetched'};
        },
        options: const QoraOptions(
          providesTags: [QueryTag('post', '1')],
          staleTime: Duration(minutes: 5),
        ),
      );

      expect(result, <String, dynamic>{'id': 1, 'title': 'Refetched'});
      expect(fetcherCalled, isTrue);
    });
  });
}

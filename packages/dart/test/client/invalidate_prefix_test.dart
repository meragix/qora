import 'package:qora/qora.dart';
import 'package:test/test.dart';

void main() {
  group('invalidatePrefix', () {
    late QoraClient client;

    setUp(() => client = QoraClient());
    tearDown(() => client.dispose());

    bool invalidated(List<Object?> key) =>
        !client.getQueryState<String>(key).isSuccess;

    void seed(List<List<Object?>> keys) {
      for (final key in keys) {
        client.setQueryData<String>(key, 'v');
      }
    }

    test('invalidates the prefix itself and every longer key', () {
      seed([
        ['posts'],
        ['posts', 1],
        ['posts', 1, 'comments'],
        ['users', 1],
      ]);

      client.invalidatePrefix(['posts']);

      expect(invalidated(['posts']), isTrue);
      expect(invalidated(['posts', 1]), isTrue);
      expect(invalidated(['posts', 1, 'comments']), isTrue);
      expect(invalidated(['users', 1]), isFalse);
    });

    test('multi-segment prefix only matches that branch', () {
      seed([
        ['users', 42, 'posts'],
        ['users', 42, 'likes'],
        ['users', 7, 'posts'],
      ]);

      client.invalidatePrefix(['users', 42]);

      expect(invalidated(['users', 42, 'posts']), isTrue);
      expect(invalidated(['users', 42, 'likes']), isTrue);
      expect(invalidated(['users', 7, 'posts']), isFalse);
    });

    test('compares values, not types loosely: 1 does not match "1"', () {
      seed([
        ['users', 1],
        ['users', '1'],
      ]);

      client.invalidatePrefix(['users', 1]);

      expect(invalidated(['users', 1]), isTrue);
      expect(invalidated(['users', '1']), isFalse);
    });

    test('map and list elements match structurally', () {
      seed([
        [
          'posts',
          {'status': 'draft', 'page': 1},
        ],
        [
          'posts',
          {'status': 'published', 'page': 1},
        ],
      ]);

      client.invalidatePrefix([
        'posts',
        {'page': 1, 'status': 'draft'},
      ]);

      expect(
        invalidated([
          'posts',
          {'status': 'draft', 'page': 1},
        ]),
        isTrue,
      );
      expect(
        invalidated([
          'posts',
          {'status': 'published', 'page': 1},
        ]),
        isFalse,
      );
    });

    test('a prefix longer than the key never matches', () {
      seed([
        ['a'],
      ]);
      client.invalidatePrefix(['a', 'b']);
      expect(invalidated(['a']), isFalse);
    });

    test('an empty prefix invalidates everything', () {
      seed([
        ['a'],
        ['b', 1],
      ]);
      client.invalidatePrefix(<Object?>[]);
      expect(invalidated(['a']), isTrue);
      expect(invalidated(['b', 1]), isTrue);
    });

    test('accepts a QoraKey', () {
      seed([
        ['posts', 1],
      ]);
      client.invalidatePrefix(const QoraKey(['posts']));
      expect(invalidated(['posts', 1]), isTrue);
    });

    test('no match is a silent no-op', () {
      expect(() => client.invalidatePrefix(['nothing']), returnsNormally);
    });

    test('active watchers matching the prefix refetch', () async {
      var calls = 0;
      final sub = client.watchQuery<String>(
        key: ['posts', 1],
        fetcher: () async => 'v${++calls}',
      ).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));

      client.invalidatePrefix(['posts']);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(calls, 2);
      await sub.cancel();
    });
  });
}

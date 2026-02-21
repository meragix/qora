// ignore_for_file: avoid_print

import 'package:meta/meta.dart';
import 'package:qora/src/core/key/key_cache_map.dart';
import 'package:qora/src/core/key/key_equality.dart';
import 'package:qora/src/core/key/qora_key.dart';
import 'package:test/test.dart';

void main() {
  group('QoraKey Class', () {
    test('Factory constructors create valid keys', () {
      final single = QoraKey.single('users');
      expect(single.parts, equals(['users']));

      final withId = QoraKey.withId('user', 123);
      expect(withId.parts, equals(['user', 123]));

      final withFilter = QoraKey.withFilter('posts', {'status': 'active'});
      expect(
        withFilter.parts,
        equals([
          'posts',
          {'status': 'active'},
        ]),
      );
    });

    test('QoraKey equality works', () {
      const key1 = QoraKey(['user', 123]);
      const key2 = QoraKey(['user', 123]);
      const key3 = QoraKey(['user', 456]);

      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });

    test('QoraKey from factory', () {
      final key = QoraKey.from(['user', 123]);
      expect(key.parts, equals(['user', 123]));
    });
  });

  group('Polymorphic Key Normalization', () {
    test('Accepts QoraKey', () {
      final key = QoraKey.withId('user', 123);
      final normalized = normalizeKey(key);
      expect(normalized, equals(['user', 123]));
    });

    test('Accepts List<dynamic>', () {
      final normalized = normalizeKey(['user', 123]);
      expect(normalized, equals(['user', 123]));
    });

    test('Rejects invalid types', () {
      expect(
        () => normalizeKey('invalid'),
        throwsArgumentError,
      );

      expect(
        () => normalizeKey(123),
        throwsArgumentError,
      );
    });

    test('Creates unmodifiable copy from List', () {
      final original = ['user', 1];
      final normalized = normalizeKey(original);

      // Mutation of original doesn't affect normalized
      original.add('extra');

      expect(normalized, equals(['user', 1]));
      expect(normalized.length, equals(2));
    });

    test('Deep copy nested structures', () {
      final original = [
        'a',
        [1, 2],
        {'b': 3},
      ];
      final normalized = normalizeKey(original);

      // Try to mutate nested list
      (original[1] as List).add(999);

      expect((normalized[1] as List).length, equals(2));
    });

    test('Normalized keys are unmodifiable', () {
      final normalized = normalizeKey(['user', 1]);

      expect(
        () => normalized.add('extra'),
        throwsUnsupportedError,
      );
    });
  });

  group('Deep Equality', () {
    test('Primitives equality', () {
      expect(equalsKey([1, 'a', true], [1, 'a', true]), isTrue);
      expect(equalsKey([1], [2]), isFalse);
      expect(equalsKey(['a'], ['b']), isFalse);
    });

    test('Nested lists equality', () {
      expect(
        equalsKey(
          [
            'user',
            [1, 2],
            'active',
          ],
          [
            'user',
            [1, 2],
            'active',
          ],
        ),
        isTrue,
      );

      expect(
        equalsKey([
          'a',
          [1],
        ], [
          'a',
          [2],
        ]),
        isFalse,
      );
    });

    test('Map equality (order-independent)', () {
      expect(
        equalsKey(
          [
            'filter',
            {'status': 'active', 'role': 'admin'},
          ],
          [
            'filter',
            {'role': 'admin', 'status': 'active'},
          ],
        ),
        isTrue,
      );

      expect(
        equalsKey(
          [
            'filter',
            {'status': 'active'},
          ],
          [
            'filter',
            {'status': 'inactive'},
          ],
        ),
        isFalse,
      );
    });

    test('Deep nested structures', () {
      expect(
        equalsKey(
          [
            'a',
            {
              'b': [
                1,
                {'c': 2},
              ],
            }
          ],
          [
            'a',
            {
              'b': [
                1,
                {'c': 2},
              ],
            }
          ],
        ),
        isTrue,
      );
    });

    test('Null handling', () {
      expect(equalsKey([null], [null]), isTrue);
      expect(equalsKey([null], [1]), isFalse);
    });

    test('Type mismatch', () {
      expect(equalsKey([1], ['1']), isFalse);
      expect(equalsKey([true], [1]), isFalse);
    });
  });

  group('Deep Hash', () {
    test('Same keys produce same hash', () {
      final hash1 = hashKey(['user', 123]);
      final hash2 = hashKey(['user', 123]);
      expect(hash1, equals(hash2));
    });

    test('Different keys produce different hash (usually)', () {
      final hash1 = hashKey(['user', 1]);
      final hash2 = hashKey(['user', 2]);
      expect(hash1, isNot(equals(hash2)));
    });

    test('Map hash is order-independent', () {
      final hash1 = hashKey([
        {'a': 1, 'b': 2},
      ]);
      final hash2 = hashKey([
        {'b': 2, 'a': 1},
      ]);
      expect(hash1, equals(hash2));
    });
  });

  group('KeyCacheMap - Polymorphic Keys', () {
    late KeyCacheMap<String> cache;

    setUp(() {
      cache = KeyCacheMap<String>();
    });

    test('Get/set with List', () {
      cache.set(['user', 1], 'Alice');
      expect(cache.get(['user', 1]), equals('Alice'));
    });

    test('Get/set with QoraKey', () {
      cache.set(QoraKey.withId('user', 1), 'Alice');
      expect(cache.get(QoraKey.withId('user', 1)), equals('Alice'));
    });

    test('Cross-pattern compatibility (List vs QoraKey)', () {
      // Set with List
      cache.set(['user', 1], 'Alice');

      // Get with QoraKey
      expect(cache.get(QoraKey.withId('user', 1)), equals('Alice'));

      // Invalidate with List
      cache.remove(['user', 1]);
      expect(cache.get(QoraKey.withId('user', 1)), isNull);
    });

    test('Deep equality lookup', () {
      cache.set(['user', 1], 'Alice');
      // Different list instance, same content
      expect(cache.get(['user', 1]), equals('Alice'));
    });

    test('Nested structures', () {
      final key = [
        'posts',
        {'status': 'active'},
      ];
      cache.set(key, 'data');
      expect(
        cache.get([
          'posts',
          {'status': 'active'},
        ]),
        equals('data'),
      );
    });

    test('Returns null for missing keys', () {
      expect(cache.get(['nonexistent']), isNull);
    });

    test('Remove keys with polymorphic input', () {
      cache.set(QoraKey.withId('user', 1), 'Alice');
      expect(cache.remove(['user', 1]), equals('Alice')); // Cross-pattern
      expect(cache.get(['user', 1]), isNull);
    });

    test('ContainsKey with polymorphic input', () {
      cache.set(['user', 1], 'Alice');
      expect(cache.containsKey(QoraKey.withId('user', 1)), isTrue);
      expect(cache.containsKey(['user', 2]), isFalse);
    });

    test('ToMap conversion', () {
      cache.set(['a'], '1');
      cache.set(QoraKey.withId('b', 2), '2');

      final map = cache.toMap();
      expect(map.length, equals(2));
      expect(map[['a']], equals('1'));
    });
  });

  group('Custom Objects in Keys', () {
    test('Objects with overridden == work', () {
      final obj1 = _TestUser(1, 'Alice');
      final obj2 = _TestUser(1, 'Alice');

      expect(
        equalsKey(['user', obj1], ['user', obj2]),
        isTrue,
      );
    });

    test('Objects without overridden == fail', () {
      final obj1 = _BrokenUser(1);
      final obj2 = _BrokenUser(1);

      // These are different instances
      expect(
        equalsKey(['user', obj1], ['user', obj2]),
        isFalse,
      );
    });

    test('Custom objects in KeyCacheMap', () {
      final cache = KeyCacheMap<String>();
      final user = _TestUser(1, 'Alice');

      cache.set(['user', user], 'data');

      // Same content, different instance
      final lookup = _TestUser(1, 'Alice');
      expect(cache.get(['user', lookup]), equals('data'));
    });
  });

  group('Performance Stress Test', () {
    test('1000 keys insert/lookup (mixed patterns)', () {
      final cache = KeyCacheMap<int>();
      final stopwatch = Stopwatch()..start();

      // Insert 1000 keys (alternating patterns)
      for (int i = 0; i < 1000; i++) {
        if (i % 2 == 0) {
          cache.set(
            [
              'item',
              i,
              {'meta': 'data'},
            ],
            i,
          );
        } else {
          cache.set(QoraKey.withFilter('item$i', {'meta': 'data'}), i);
        }
      }

      // Lookup all
      for (int i = 0; i < 1000; i++) {
        if (i % 2 == 0) {
          expect(
            cache.get([
              'item',
              i,
              {'meta': 'data'},
            ]),
            equals(i),
          );
        } else {
          expect(
            cache.get(QoraKey.withFilter('item$i', {'meta': 'data'})),
            equals(i),
          );
        }
      }

      stopwatch.stop();
      print('1000 mixed ops completed in ${stopwatch.elapsedMilliseconds}ms');

      // Sanity check: should be < 150ms on modern hardware
      expect(stopwatch.elapsedMilliseconds, lessThan(150));
    });

    test('Deep key comparison benchmark', () {
      final deepKey = [
        'root',
        ['a', 'b', 'c'],
        {
          'x': 1,
          'y': {'nested': true},
        },
        [1, 2, 3, 4, 5],
      ];

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 10000; i++) {
        hashKey(deepKey);
      }

      stopwatch.stop();
      print('10k deep hash in ${stopwatch.elapsedMilliseconds}ms');
    });
  });

  group('Edge Cases', () {
    test('Empty list key', () {
      final normalized = normalizeKey([]);
      expect(normalized, equals([]));
    });

    test('Single element key', () {
      final normalized = normalizeKey(['single']);
      expect(normalized, equals(['single']));
    });

    test('Very deep nesting', () {
      final deepKey = [
        'a',
        [
          'b',
          [
            'c',
            [
              'd',
              {'e': 'f'},
            ]
          ]
        ]
      ];

      final normalized = normalizeKey(deepKey);
      expect(normalized, isNotNull);
    });
  });
}

// --- TEST HELPERS ---

/// Proper user class with == override
@immutable
class _TestUser {
  final int id;
  final String name;

  _TestUser(this.id, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _TestUser && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Broken user class (no == override)
class _BrokenUser {
  final int id;
  _BrokenUser(this.id);
}

import 'package:meta/meta.dart';
import 'package:qora/src/state/qora_state.dart';
import 'package:qora/src/state/state_extensions.dart';
import 'package:qora/src/state/state_serialization.dart';
import 'package:test/test.dart';

void main() {
  group('QoraState - Core', () {
    group('Initial', () {
      test('has no data', () {
        const state = Initial<String>();
        expect(state.hasData, isFalse);
        expect(state.dataOrNull, isNull);
        expect(state.isInitial, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isSuccess, isFalse);
        expect(state.isError, isFalse);
      });

      test('equality works', () {
        const state1 = Initial<String>();
        const state2 = Initial<String>();
        const state3 = Initial<int>();

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });

    group('Loading', () {
      test('without previous data', () {
        const state = Loading<String>();
        expect(state.hasData, isFalse);
        expect(state.dataOrNull, isNull);
        expect(state.isLoading, isTrue);
        expect(state.previousData, isNull);
      });

      test('with previous data', () {
        const state = Loading<String>(previousData: 'old');
        expect(state.hasData, isTrue);
        expect(state.dataOrNull, equals('old'));
        expect(state.isLoading, isTrue);
        expect(state.previousData, equals('old'));
      });

      test('equality works', () {
        const state1 = Loading<String>(previousData: 'data');
        const state2 = Loading<String>(previousData: 'data');
        const state3 = Loading<String>(previousData: 'other');
        const state4 = Loading<String>();

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
        expect(state1, isNot(equals(state4)));
      });
    });

    group('Success', () {
      late DateTime now;
      late Success<String> state;

      setUp(() {
        now = DateTime.now();
        state = Success(data: 'hello', updatedAt: now);
      });

      test('has data', () {
        expect(state.hasData, isTrue);
        expect(state.dataOrNull, equals('hello'));
        expect(state.isSuccess, isTrue);
        expect(state.data, equals('hello'));
        expect(state.updatedAt, equals(now));
      });

      test('factory Success.now', () {
        final state = Success.now('test');
        expect(state.data, equals('test'));
        expect(state.updatedAt, isA<DateTime>());
      });

      test('age calculation', () {
        final past = DateTime.now().subtract(const Duration(minutes: 5));
        final state = Success(data: 'test', updatedAt: past);

        expect(state.age.inMinutes, greaterThanOrEqualTo(4));
        expect(state.age.inMinutes, lessThanOrEqualTo(6));
      });

      test('isStale check', () {
        final fresh = Success(
          data: 'test',
          updatedAt: DateTime.now(),
        );
        final stale = Success(
          data: 'test',
          updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        );

        expect(fresh.isStale(const Duration(minutes: 5)), isFalse);
        expect(stale.isStale(const Duration(minutes: 5)), isTrue);
      });

      test('equality works', () {
        final state1 = Success(data: 'test', updatedAt: now);
        final state2 = Success(data: 'test', updatedAt: now);
        final state3 = Success(data: 'other', updatedAt: now);

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });

    group('Failure', () {
      test('without previous data', () {
        const state = Failure<String>(error: 'boom');
        expect(state.hasData, isFalse);
        expect(state.dataOrNull, isNull);
        expect(state.isError, isTrue);
        expect(state.error, equals('boom'));
        expect(state.previousData, isNull);
        expect(state.stackTrace, isNull);
      });

      test('with previous data', () {
        const state = Failure<String>(
          error: 'boom',
          previousData: 'cached',
        );
        expect(state.hasData, isTrue);
        expect(state.dataOrNull, equals('cached'));
        expect(state.isError, isTrue);
        expect(state.previousData, equals('cached'));
      });

      test('with stack trace', () {
        final stack = StackTrace.current;
        final state = Failure<String>(
          error: 'boom',
          stackTrace: stack,
        );
        expect(state.stackTrace, equals(stack));
      });

      test('equality works', () {
        const state1 = Failure<String>(error: 'err', previousData: 'data');
        const state2 = Failure<String>(error: 'err', previousData: 'data');
        const state3 = Failure<String>(error: 'other', previousData: 'data');

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });
  });

  group('QoraState - Pattern Matching', () {
    test('when() executes correct callback', () {
      var initialCalled = false;
      var loadingCalled = false;
      var successCalled = false;
      var errorCalled = false;

      const Initial<String>().when(onInitial: () => initialCalled = true);
      expect(initialCalled, isTrue);

      const Loading<String>().when(onLoading: (_) => loadingCalled = true);
      expect(loadingCalled, isTrue);

      Success.now('test').when(onSuccess: (_, __) => successCalled = true);
      expect(successCalled, isTrue);

      const Failure<String>(error: 'err').when(
        onError: (_, __, ___) => errorCalled = true,
      );
      expect(errorCalled, isTrue);
    });

    test('maybeWhen() with orElse', () {
      const state = Loading<String>();

      final result = state.maybeWhen(
        onLoading: (_) => 'loading',
        orElse: () => 'other',
      );

      expect(result, equals('loading'));

      final elseResult = state.maybeWhen(
        onSuccess: (_, __) => 'success',
        orElse: () => 'fallback',
      );

      expect(elseResult, equals('fallback'));
    });

    test('switch expression exhaustiveness', () {
      String describe(QoraState<String> state) {
        return switch (state) {
          Initial() => 'initial',
          Loading() => 'loading',
          Success() => 'success',
          Failure() => 'error',
        };
      }

      expect(describe(const Initial()), equals('initial'));
      expect(describe(const Loading()), equals('loading'));
      expect(describe(Success.now('test')), equals('success'));
      expect(describe(const Failure(error: 'err')), equals('error'));
    });
  });

  group('QoraState - Transformation', () {
    test('map() transforms data type', () {
      final state = Success(data: 42, updatedAt: DateTime.now());
      final mapped = state.map((n) => n.toString());

      expect(mapped, isA<Success<String>>());
      expect((mapped as Success<String>).data, equals('42'));
    });

    test('map() preserves state structure', () {
      const loading = Loading<int>(previousData: 42);
      final mapped = loading.map((n) => n.toString());

      expect(mapped, isA<Loading<String>>());
      expect((mapped as Loading<String>).previousData, equals('42'));
    });

    test('map() handles Initial', () {
      const state = Initial<int>();
      final mapped = state.map((n) => n.toString());

      expect(mapped, isA<Initial<String>>());
    });

    test('map() handles Failure', () {
      const state = Failure<int>(error: 'boom', previousData: 42);
      final mapped = state.map((n) => n.toString());

      expect(mapped, isA<Failure<String>>());
      expect((mapped as Failure<String>).previousData, equals('42'));
    });
  });

  group('QoraStateExtensions', () {
    test('requireData() returns data or throws', () {
      final success = Success.now('data');
      expect(success.requireData(), equals('data'));

      const initial = Initial<String>();
      expect(() => initial.requireData(), throwsStateError);
    });

    test('successDataOrNull ignores previousData', () {
      const loading = Loading<String>(previousData: 'old');
      expect(loading.successDataOrNull, isNull);

      final success = Success.now('new');
      expect(success.successDataOrNull, equals('new'));
    });

    test('isFirstLoad vs isRefreshing', () {
      const firstLoad = Loading<String>();
      expect(firstLoad.isFirstLoad, isTrue);
      expect(firstLoad.isRefreshing, isFalse);

      const refresh = Loading<String>(previousData: 'old');
      expect(refresh.isFirstLoad, isFalse);
      expect(refresh.isRefreshing, isTrue);
    });

    test('isStale() with threshold', () {
      final fresh = Success(
        data: 'test',
        updatedAt: DateTime.now(),
      );
      expect(fresh.isStale(const Duration(minutes: 5)), isFalse);

      final stale = Success(
        data: 'test',
        updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(stale.isStale(const Duration(minutes: 5)), isTrue);

      const loading = Loading<String>();
      expect(loading.isStale(const Duration(minutes: 5)), isFalse);
    });

    test('mapSuccess() only transforms Success', () {
      final success = Success.now([1, 2, 3]);
      final mapped = success.mapSuccess((list) => list.length);

      expect(mapped, isA<Success<int>>());
      expect((mapped as Success<int>).data, equals(3));

      const loading = Loading<List<int>>();
      final mappedLoading = loading.mapSuccess((list) => list.length);
      expect(mappedLoading, isA<Loading<int>>());
    });

    test('combine() merges two Success states', () {
      final state1 = Success.now(1);
      final state2 = Success.now('a');

      final combined = state1.combine(state2, (n, s) => '$s$n');

      expect(combined, isA<Success<String>>());
      expect((combined as Success<String>).data, equals('a1'));
    });

    test('combine() prioritizes Failure', () {
      final success = Success.now(1);
      const error = Failure<String>(error: 'boom');

      final combined = success.combine(error, (n, s) => s);

      expect(combined, isA<Failure<String>>());
    });

    test('fold() exhaustively handles states', () {
      final state = Success.now('data');

      final result = state.fold(
        onInitial: () => 'init',
        onLoading: (_) => 'loading',
        onSuccess: (data, _) => 'success: $data',
        onError: (_, __, ___) => 'error',
      );

      expect(result, equals('success: data'));
    });

    test('status enum conversion', () {
      expect(const Initial<String>().status, ReqryStatus.initial);
      expect(const Loading<String>().status, ReqryStatus.loading);
      expect(Success.now('').status, ReqryStatus.success);
      expect(const Failure<String>(error: '').status, ReqryStatus.error);
    });
  });

  group('QoraStateStreamExtensions', () {
    test('whereHasData filters correctly', () async {
      final stream = Stream.fromIterable([
        const Initial<String>(),
        const Loading<String>(),
        const Loading<String>(previousData: 'old'),
        Success.now('new'),
      ]);

      final results = await stream.whereHasData().toList();
      expect(results.length, equals(2));
      expect(results[0], isA<Loading<String>>());
      expect(results[1], isA<Success<String>>());
    });

    test('whereSuccess filters to Success only', () async {
      final stream = Stream.fromIterable([
        const Initial<String>(),
        Success.now('a'),
        const Loading<String>(),
        Success.now('b'),
      ]);

      final results = await stream.whereSuccess().toList();
      expect(results.length, equals(2));
      expect(results[0].data, equals('a'));
      expect(results[1].data, equals('b'));
    });

    test('data() extracts non-null data', () async {
      final stream = Stream.fromIterable([
        const Initial<String>(),
        const Loading<String>(),
        const Loading<String>(previousData: 'old'),
        Success.now('new'),
      ]);

      final results = await stream.data().toList();
      expect(results, equals(['old', 'new']));
    });

    test('mapData() transforms data type', () async {
      final stream = Stream.fromIterable([
        Success.now(42),
        const Loading<int>(previousData: 10),
      ]);

      final results = await stream.mapData((n) => n.toString()).toList();
      expect(results[0], isA<Success<String>>());
      expect((results[0] as Success<String>).data, equals('42'));
    });
  });

  group('QoraStateUtils', () {
    test('combineList with all Success', () {
      final states = [
        Success.now(1),
        Success.now(2),
        Success.now(3),
      ];

      final combined = QoraStateUtils.combineList(states);
      expect(combined, isA<Success<List<int>>>());
      expect((combined as Success<List<int>>).data, equals([1, 2, 3]));
    });

    test('combineList with Failure', () {
      final states = [
        Success.now(1),
        const Failure<int>(error: 'boom'),
        Success.now(3),
      ];

      final combined = QoraStateUtils.combineList(states);
      expect(combined, isA<Failure<List<int>>>());
    });

    test('combineList with Loading', () {
      final states = [
        Success.now(1),
        const Loading<int>(),
        Success.now(3),
      ];

      final combined = QoraStateUtils.combineList(states);
      expect(combined, isA<Loading<List<int>>>());
    });

    test('combine2 tuples', () {
      final state1 = Success.now(1);
      final state2 = Success.now('a');

      final combined = QoraStateUtils.combine2(state1, state2);

      expect(combined, isA<Success<(int, String)>>());
      expect((combined as Success<(int, String)>).data, equals((1, 'a')));
    });

    test('combine3 tuples', () {
      final state1 = Success.now(1);
      final state2 = Success.now('a');
      final state3 = Success.now(true);

      final combined = QoraStateUtils.combine3(state1, state2, state3);

      expect(combined, isA<Success<(int, String, bool)>>());
      expect(
        (combined as Success<(int, String, bool)>).data,
        equals((1, 'a', true)),
      );
    });
  });

  group('QoraStateSerialization', () {
    final now = DateTime.parse('2024-01-01T12:00:00Z');

    Map<String, dynamic> userToJson(User user) => user.toJson();
    User userFromJson(Map<String, dynamic> json) => User.fromJson(json);

    test('serializes Initial', () {
      const state = Initial<User>();
      final json = QoraStateSerialization.toJson(state, userToJson);

      expect(json, equals({'type': 'initial'}));
    });

    test('serializes Loading without previousData', () {
      const state = Loading<User>();
      final json = QoraStateSerialization.toJson(state, userToJson);

      expect(json, equals({'type': 'loading'}));
    });

    test('serializes Loading with previousData', () {
      const state = Loading<User>(
        previousData: User(id: 1, name: 'Alice'),
      );
      final json = QoraStateSerialization.toJson(state, userToJson);

      expect(
        json,
        equals({
          'type': 'loading',
          'previousData': {'id': 1, 'name': 'Alice'},
        }),
      );
    });

    test('serializes Success', () {
      final state = Success(
        data: const User(id: 1, name: 'Alice'),
        updatedAt: now,
      );
      final json = QoraStateSerialization.toJson(state, userToJson);

      expect(
        json,
        equals({
          'type': 'success',
          'data': {'id': 1, 'name': 'Alice'},
          'updatedAt': '2024-01-01T12:00:00.000Z',
        }),
      );
    });

    test('serializes Failure', () {
      const state = Failure<User>(
        error: 'Network error',
        previousData: User(id: 1, name: 'Alice'),
      );
      final json = QoraStateSerialization.toJson(state, userToJson);

      expect(
        json,
        equals({
          'type': 'error',
          'error': 'Network error',
          'previousData': {'id': 1, 'name': 'Alice'},
        }),
      );
    });

    test('deserializes Initial', () {
      final json = {'type': 'initial'};
      final state = QoraStateSerialization.fromJson<User>(json, userFromJson);

      expect(state, isA<Initial<User>>());
    });

    test('deserializes Loading', () {
      final json = {
        'type': 'loading',
        'previousData': {'id': 1, 'name': 'Alice'},
      };
      final state = QoraStateSerialization.fromJson<User>(json, userFromJson);

      expect(state, isA<Loading<User>>());
      expect((state as Loading<User>).previousData?.name, equals('Alice'));
    });

    test('deserializes Success', () {
      final json = {
        'type': 'success',
        'data': {'id': 1, 'name': 'Alice'},
        'updatedAt': '2024-01-01T12:00:00.000Z',
      };
      final state = QoraStateSerialization.fromJson<User>(json, userFromJson);

      expect(state, isA<Success<User>>());
      final success = state as Success<User>;
      expect(success.data.name, equals('Alice'));
      expect(success.updatedAt, equals(now));
    });

    test('deserializes Failure', () {
      final json = {
        'type': 'error',
        'error': 'Network error',
        'previousData': {'id': 1, 'name': 'Alice'},
      };
      final state = QoraStateSerialization.fromJson<User>(json, userFromJson);

      expect(state, isA<Failure<User>>());
      final error = state as Failure<User>;
      expect(error.error, equals('Network error'));
      expect(error.previousData?.name, equals('Alice'));
    });

    test('roundtrip serialization', () {
      final original = Success(
        data: const User(id: 42, name: 'Bob'),
        updatedAt: now,
      );

      final json = QoraStateSerialization.toJson(original, userToJson);
      final restored = QoraStateSerialization.fromJson<User>(json, userFromJson);

      expect(restored, equals(original));
    });

    test('ReqryStateCodec', () {
      final codec = QoraStateCodec<User>(
        encode: userToJson,
        decode: userFromJson,
      );

      final state = Success.now(const User(id: 1, name: 'Test'));

      final json = codec.encodeState(state);
      final restored = codec.decodeState(json);

      expect(restored, isA<Success<User>>());
      expect((restored as Success<User>).data.name, equals('Test'));
    });
  });

  group('InMemoryPersistence', () {
    test('save and load', () async {
      final persistence = InMemoryPersistence<User>();
      final state = Success.now(const User(id: 1, name: 'Test'));

      await persistence.save('key1', state);
      final loaded = await persistence.load('key1');

      expect(loaded, equals(state));
    });

    test('returns null for missing key', () async {
      final persistence = InMemoryPersistence<User>();
      final loaded = await persistence.load('nonexistent');

      expect(loaded, isNull);
    });

    test('delete removes state', () async {
      final persistence = InMemoryPersistence<User>();
      final state = Success.now(const User(id: 1, name: 'Test'));

      await persistence.save('key1', state);
      await persistence.delete('key1');
      final loaded = await persistence.load('key1');

      expect(loaded, isNull);
    });

    test('clear removes all states', () async {
      final persistence = InMemoryPersistence<User>();

      await persistence.save('key1', Success.now(const User(id: 1, name: 'A')));
      await persistence.save('key2', Success.now(const User(id: 2, name: 'B')));

      await persistence.clear();

      expect(await persistence.load('key1'), isNull);
      expect(await persistence.load('key2'), isNull);
    });
  });
}

// --- TEST MODELS ---

@immutable
class User {
  final int id;
  final String name;

  const User({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is User && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'User(id: $id, name: $name)';
}

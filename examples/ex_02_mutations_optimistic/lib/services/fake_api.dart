import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/user.dart';

/// Simulates a remote API with configurable latency and probabilistic failures.
///
/// [updateUser] fails ~30 % of the time to demonstrate Qora's automatic
/// cache rollback via [MutationOptions.onError] and [QoraClient.restoreQueryData].
class FakeApi {
  /// Simulated round-trip latency.
  static const _delay = Duration(seconds: 2);
  static final _random = Random();

  static final List<User> _users = [
    const User(
      id: '1',
      name: 'Alice Johnson',
      email: 'alice@example.com',
      avatar: '👩‍💼',
    ),
    const User(
      id: '2',
      name: 'Bob Smith',
      email: 'bob@example.com',
      avatar: '👨‍💻',
    ),
    const User(
      id: '3',
      name: 'Charlie Brown',
      email: 'charlie@example.com',
      avatar: '👨‍🎨',
    ),
    const User(
      id: '4',
      name: 'Diana Prince',
      email: 'diana@example.com',
      avatar: '👩‍🚀',
    ),
    const User(
      id: '5',
      name: 'Eve Davis',
      email: 'eve@example.com',
      avatar: '👩‍🔬',
    ),
  ];

  /// Returns all users after a simulated network delay.
  static Future<List<User>> getUsers() async {
    debugPrint('🌐 FakeApi.getUsers — fetching…');
    await Future<void>.delayed(_delay);
    debugPrint('✅ FakeApi.getUsers — done (${_users.length} users)');
    return List.from(_users);
  }

  /// Returns a single user by [id].
  ///
  /// Throws [Exception] if no user with that id exists.
  static Future<User> getUser(String id) async {
    debugPrint('🌐 FakeApi.getUser($id) — fetching…');
    await Future<void>.delayed(_delay);

    final user = _users.firstWhere(
      (u) => u.id == id,
      orElse: () => throw Exception('User $id not found'),
    );

    debugPrint('✅ FakeApi.getUser($id) — done');
    return user;
  }

  /// Simulates updating a user name.
  ///
  /// Fails ~30 % of the time with a server error to demonstrate automatic
  /// cache rollback via [MutationOptions.onError] and
  /// [QoraClient.restoreQueryData].
  static Future<User> updateUser(String id, {required String name}) async {
    debugPrint('🌐 FakeApi.updateUser($id, name: $name) — sending…');
    await Future<void>.delayed(_delay);

    if (_random.nextDouble() < 0.3) {
      debugPrint(
        '❌ FakeApi.updateUser — simulated server error (30 % failure mode)',
      );
      throw Exception('Server error: could not save changes.');
    }

    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) throw Exception('User $id not found');

    final updated = _users[index].copyWith(name: name);
    _users[index] = updated;

    debugPrint('✅ FakeApi.updateUser($id) — done: ${updated.name}');
    return updated;
  }
}

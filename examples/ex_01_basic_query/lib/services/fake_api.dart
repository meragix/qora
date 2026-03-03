import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';

/// Simulates a remote API with configurable latency and optional failures.
///
/// In a real app replace these with actual HTTP calls (e.g. via `http` or `dio`).
class FakeApi {
  /// Simulated round-trip latency.
  static const _delay = Duration(seconds: 2);

  static final List<User> _users = [
    const User(id: '1', name: 'Alice Johnson', email: 'alice@example.com', avatar: '👩‍💼'),
    const User(id: '2', name: 'Bob Smith', email: 'bob@example.com', avatar: '👨‍💻'),
    const User(id: '3', name: 'Charlie Brown', email: 'charlie@example.com', avatar: '👨‍🎨'),
    const User(id: '4', name: 'Diana Prince', email: 'diana@example.com', avatar: '👩‍🚀'),
    const User(id: '5', name: 'Eve Davis', email: 'eve@example.com', avatar: '👩‍🔬'),
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

  /// Simulates updating a user's name.
  ///
  /// Returns the updated [User]. Throws [Exception] if the user does not exist.
  static Future<User> updateUser(String id, {required String name}) async {
    debugPrint('🌐 FakeApi.updateUser($id, name: $name) — sending…');
    await Future<void>.delayed(_delay);

    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) throw Exception('User $id not found');

    final updated = User(
      id: _users[index].id,
      name: name,
      email: _users[index].email,
      avatar: _users[index].avatar,
    );
    _users[index] = updated;

    debugPrint('✅ FakeApi.updateUser($id) — done');
    return updated;
  }

  /// Same as [getUsers] but fails ~30 % of the time — useful for testing
  /// Qora's automatic retry and error UI.
  static Future<List<User>> getUsersWithRandomFailure() async {
    debugPrint('🌐 FakeApi.getUsersWithRandomFailure — fetching…');
    await Future<void>.delayed(_delay);

    if (DateTime.now().millisecond % 10 < 3) {
      debugPrint('❌ FakeApi — simulated network error');
      throw Exception('Network error: Unable to fetch users');
    }

    debugPrint('✅ FakeApi.getUsersWithRandomFailure — done');
    return List.from(_users);
  }
}

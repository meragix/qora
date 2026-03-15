import 'package:flutter/foundation.dart';

/// Represents a logged-in user.
///
/// [id] is the user's server-side identifier (matches JSONPlaceholder userId).
/// [name] is a display name shown in the UI.
class AuthUser {
  final String id;
  final String name;

  const AuthUser({required this.id, required this.name});

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser(id: json['id'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// In-memory authentication service backed by a [ValueNotifier].
///
/// In a real app this would handle JWT tokens, refresh logic, and secure
/// storage. For this demo it simply stores the current user in memory so
/// [LoginScreen] and [TodoListScreen] can react to auth-state changes without
/// lifting the state all the way to main.dart.
class AuthService extends ValueNotifier<AuthUser?> {
  AuthService() : super(null);

  /// Whether a user is currently authenticated.
  bool get isLoggedIn => value != null;

  /// Simulates a successful login for [userId] with a synthetic display name.
  void login(String userId, String name) {
    value = AuthUser(id: userId, name: name);
  }

  /// Clears the current session.
  void logout() {
    value = null;
  }
}

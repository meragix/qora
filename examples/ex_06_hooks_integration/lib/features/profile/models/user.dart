/// A JSONPlaceholder user (subset of fields used in this demo).
class User {
  final String id;
  final String name;
  final String username;
  final String email;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: '${json['id']}',
    name: json['name'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
  );

  User copyWith({String? name, String? username}) => User(
    id: id,
    name: name ?? this.name,
    username: username ?? this.username,
    email: email,
  );
}

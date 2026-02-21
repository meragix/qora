import 'package:flutter/material.dart';
import 'package:flutter_qora/flutter_qora.dart';

// ============================================================================
// EXEMPLE 1 : Configuration de base avec QoraScope
// ============================================================================

void main() {
  // Créer le client global
  final client = QoraClient(
    config: QoraClientConfig(
      defaultOptions: QoraOptions(
        staleTime: Duration(seconds: 30),
        cacheTime: Duration(minutes: 5),
        retryCount: 3,
      ),
      debugMode: true,
      // Mapper optionnel pour transformer les erreurs
      errorMapper: (error, stackTrace) {
        if (error.toString().contains('401')) {
          return QoraException('Non autorisé', originalError: error);
        }
        return QoraException('Erreur réseau', originalError: error);
      },
    ),
  );

  runApp(
    QoraScope(
      client: client,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qora Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: UserListScreen(),
    );
  }
}

// ============================================================================
// EXEMPLE 2 : ReqryBuilder basique pour une liste d'utilisateurs
// ============================================================================

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Utilisateurs'),
        actions: [
          // Utilisation de l'extension context.reqry
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              context.qora.invalidateQuery(QoraKey(['users']));
            },
          ),
        ],
      ),
      body: QoraBuilder<List<User>>(
        queryKey: QoraKey(['users']),
        queryFn: () => ApiService.getUsers(),
        builder: (context, state) {
          return state.maybeWhen(
            orElse: () => const SizedBox.shrink(),
            onInitial: () => Center(
              child: Text('Appuyez pour charger'),
            ),
            onLoading: (previousData) {
              // Si on a des données précédentes, les afficher avec un indicateur
              if (previousData != null) {
                return Stack(
                  children: [
                    UserListView(users: previousData),
                    LinearProgressIndicator(),
                  ],
                );
              }
              return Center(child: CircularProgressIndicator());
            },
            onSuccess: (users, updatedAt) {
              if (users.isEmpty) {
                return Center(child: Text('Aucun utilisateur'));
              }
              return UserListView(users: users);
            },
            onError: (error, stackTrace, previousData) {
              return Column(
                children: [
                  if (previousData != null) Expanded(child: UserListView(users: previousData)),
                  ErrorBanner(error: error.toString()),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// EXEMPLE 3 : Pagination avec keepPreviousData
// ============================================================================

class PaginatedUsersScreen extends StatefulWidget {
  const PaginatedUsersScreen({super.key});

  @override
  State<PaginatedUsersScreen> createState() => _PaginatedUsersScreenState();
}

class _PaginatedUsersScreenState extends State<PaginatedUsersScreen> {
  int _currentPage = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pagination')),
      body: Column(
        children: [
          // ✅ keepPreviousData évite les flashs lors du changement de page
          Expanded(
            child: QoraBuilder<List<User>>(
              queryKey: QoraKey(['users', 'paginated', _currentPage]),
              queryFn: () => ApiService.getUsersPaginated(_currentPage),
              keepPreviousData: true, // 🎯 IMPORTANT pour la pagination
              builder: (context, state) {
                return state.maybeWhen(
                  orElse: () => const SizedBox.shrink(),
                  onInitial: () => Center(child: CircularProgressIndicator()),
                  onLoading: (previousData) {
                    // Afficher les données de la page précédente
                    if (previousData != null) {
                      return Stack(
                        children: [
                          UserListView(users: previousData),
                          // Petit indicateur de chargement en haut
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(),
                          ),
                        ],
                      );
                    }
                    return Center(child: CircularProgressIndicator());
                  },
                  onSuccess: (users, _) => UserListView(users: users),
                  onError: (err, _, prev) => ErrorView(error: err.toString()),
                );
              },
            ),
          ),
          // Contrôles de pagination
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              ),
              Text('Page $_currentPage'),
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () => setState(() => _currentPage++),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXEMPLE 4 : Détail d'un utilisateur avec refresh manuel
// ============================================================================

class UserDetailScreen extends StatelessWidget {
  final int userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détail utilisateur'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              // Méthode 1 : Invalider et le QoraBuilder va refetch
              context.qora.invalidateQuery(QoraKey(['user', userId]));

              // Méthode 2 : Fetch manuel
              // await context.qora.fetchQuery(
              //   key: QoraKey(['user', userId]),
              //   fetcher: () => ApiService.getUser(userId),
              // );
            },
          ),
        ],
      ),
      body: QoraBuilder<User>(
        queryKey: QoraKey(['user', userId]),
        queryFn: () => ApiService.getUser(userId),
        builder: (context, state) {
          return state.maybeWhen(
            orElse: () => const SizedBox.shrink(),
            onInitial: () => Center(child: Text('Chargement...')),
            onLoading: (prev) => prev != null
                ? UserDetailView(user: prev, isRefreshing: true)
                : Center(child: CircularProgressIndicator()),
            onSuccess: (user, updatedAt) {
              return UserDetailView(
                user: user,
                updatedAt: updatedAt,
              );
            },
            onError: (error, _, prev) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Erreur: $error'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.qora.invalidateQuery(
                          QoraKey(['user', userId]),
                        );
                      },
                      child: Text('Réessayer'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// EXEMPLE 5 : Utilisation de QoraStateBuilder (observe sans fetch)
// ============================================================================

class UserAvatarWidget extends StatelessWidget {
  final int userId;

  const UserAvatarWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Ne fait que s'abonner à l'état, ne déclenche pas de fetch
    return QoraStateBuilder<User>(
      queryKey: QoraKey(['user', userId]),
      builder: (context, state) {
        return state.maybeWhen(
          orElse: () => const SizedBox.shrink(),
          onInitial: () => CircleAvatar(child: Icon(Icons.person)),
          onLoading: (_) => CircleAvatar(child: CircularProgressIndicator()),
          onSuccess: (user, _) => CircleAvatar(
            backgroundImage: NetworkImage(user.avatarUrl),
          ),
          onError: (_, __, ___) => CircleAvatar(child: Icon(Icons.error)),
        );
      },
    );
  }
}

// ============================================================================
// EXEMPLE 6 : Mutation avec optimistic update
// ============================================================================

class UpdateUserButton extends StatelessWidget {
  final int userId;
  final String newName;

  const UpdateUserButton({
    super.key,
    required this.userId,
    required this.newName,
  });

  Future<void> _updateUser(BuildContext context) async {
    final key = QoraKey(['user', userId]);
    final client = context.qora;

    // 1. Sauvegarder l'état actuel
    final previousState = client.getState<User>(key);
    final previousData = previousState.dataOrNull;

    try {
      // 2. Optimistic update (mise à jour immédiate de l'UI)
      if (previousData != null) {
        client.setQueryData<User>(
          key,
          previousData.copyWith(name: newName),
        );
      }

      // 3. Exécuter la mutation
      final updatedUser = await ApiService.updateUser(userId, newName);

      // 4. Mettre à jour avec les vraies données du serveur
      client.setQueryData<User>(key, updatedUser);

      // 5. Invalider les requêtes liées
      client.invalidateQueries((k) => k == 'users');
    } catch (error) {
      // 6. Rollback en cas d'erreur
      if (previousData != null) {
        client.setQueryData<User>(key, previousData);
      }

      // Afficher un message d'erreur
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _updateUser(context),
      child: Text('Mettre à jour'),
    );
  }
}

// ============================================================================
// EXEMPLE 7 : enabled pour contrôle conditionnel
// ============================================================================

class ConditionalQueryWidget extends StatefulWidget {
  const ConditionalQueryWidget({super.key});

  @override
  State<ConditionalQueryWidget> createState() => _ConditionalQueryWidgetState();
}

class _ConditionalQueryWidgetState extends State<ConditionalQueryWidget> {
  bool _shouldFetch = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Switch(
          value: _shouldFetch,
          onChanged: (value) => setState(() => _shouldFetch = value),
        ),
        QoraBuilder<String>(
          queryKey: QoraKey(['conditional-data']),
          queryFn: () => ApiService.getData(),
          enabled: _shouldFetch, // Ne fetch que si true
          builder: (context, state) {
            return Text('État: ${state.runtimeType}');
          },
        ),
      ],
    );
  }
}

// ============================================================================
// MODÈLES ET SERVICES (pour les exemples)
// ============================================================================

class User {
  final int id;
  final String name;
  final String email;
  final String avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  User copyWith({String? name, String? email}) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl,
    );
  }
}

class ApiService {
  static Future<List<User>> getUsers() async {
    await Future.delayed(Duration(seconds: 1));
    return List.generate(
        10,
        (i) => User(
              id: i,
              name: 'User $i',
              email: 'user$i@example.com',
              avatarUrl: 'https://i.pravatar.cc/150?img=$i',
            ));
  }

  static Future<List<User>> getUsersPaginated(int page) async {
    await Future.delayed(Duration(milliseconds: 500));
    final start = (page - 1) * 10;
    return List.generate(
        10,
        (i) => User(
              id: start + i,
              name: 'User ${start + i}',
              email: 'user${start + i}@example.com',
              avatarUrl: 'https://i.pravatar.cc/150?img=${start + i}',
            ));
  }

  static Future<User> getUser(int id) async {
    await Future.delayed(Duration(milliseconds: 500));
    return User(
      id: id,
      name: 'User $id',
      email: 'user$id@example.com',
      avatarUrl: 'https://i.pravatar.cc/150?img=$id',
    );
  }

  static Future<User> updateUser(int id, String newName) async {
    await Future.delayed(Duration(milliseconds: 300));
    return User(
      id: id,
      name: newName,
      email: 'user$id@example.com',
      avatarUrl: 'https://i.pravatar.cc/150?img=$id',
    );
  }

  static Future<String> getData() async {
    await Future.delayed(Duration(seconds: 1));
    return 'Some data';
  }
}

// Widgets helper pour les exemples
class UserListView extends StatelessWidget {
  final List<User> users;

  const UserListView({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user.avatarUrl),
          ),
          title: Text(user.name),
          subtitle: Text(user.email),
        );
      },
    );
  }
}

class UserDetailView extends StatelessWidget {
  final User user;
  final bool isRefreshing;
  final DateTime? updatedAt;

  const UserDetailView({
    super.key,
    required this.user,
    this.isRefreshing = false,
    this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRefreshing) LinearProgressIndicator(),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(user.avatarUrl),
            ),
          ),
          SizedBox(height: 16),
          Text(user.name, style: Theme.of(context).textTheme.headlineMedium),
          Text(user.email),
          if (updatedAt != null)
            Text(
              'Mis à jour: ${updatedAt!.toLocal()}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String error;

  const ErrorBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red[100],
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red),
          SizedBox(width: 8),
          Expanded(child: Text(error)),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String error;

  const ErrorView({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Erreur: $error'),
        ],
      ),
    );
  }
}

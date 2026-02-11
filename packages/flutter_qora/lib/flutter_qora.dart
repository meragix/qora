/// Package d'intégration Flutter pour Qora
///
/// Fournit des widgets et extensions Flutter pour utiliser facilement
/// le package qora dans vos applications Flutter.
///
/// Composants principaux :
/// - [QoraScope] : InheritedWidget pour fournir le QoraClient
/// - [QoraBuilder] : Widget pour s'abonner aux requêtes
/// - [QoraStateBuilder] : Widget pour observer l'état sans fetch
/// - [QoraBuildContextExtension] : Extension `context.qora`
///
/// Exemple d'utilisation complète :
/// ```dart
/// void main() {
///   final client = QoraClient(
///     config: QoraClientConfig(
///       defaultOptions: QoraOptions(
///         staleTime: Duration(seconds: 30),
///         cacheTime: Duration(minutes: 5),
///       ),
///       debugMode: true,
///     ),
///   );
///
///   runApp(
///     QoraScope(
///       client: client,
///       child: MyApp(),
///     ),
///   );
/// }
///
/// class UserProfile extends StatelessWidget {
///   final int userId;
///
///   const UserProfile({required this.userId});
///
///   @override
///   Widget build(BuildContext context) {
///     return QoraBuilder<User>(
///       queryKey: QoraKey(['user', userId]),
///       queryFn: () => api.getUser(userId),
///       builder: (context, state) {
///         return state.when(
///           initial: () => Center(child: Text('Chargement...')),
///           loading: (previousData) {
///             if (previousData != null) {
///               return UserCard(user: previousData, isRefreshing: true);
///             }
///             return Center(child: CircularProgressIndicator());
///           },
///           success: (user, updatedAt) => UserCard(user: user),
///           failure: (error, stackTrace, previousData) {
///             return Column(
///               children: [
///                 if (previousData != null) UserCard(user: previousData),
///                 ErrorBanner(error: error),
///               ],
///             );
///           },
///         );
///       },
///     );
///   }
/// }
///
/// // Utiliser l'extension context.qora
/// class RefreshButton extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return IconButton(
///       icon: Icon(Icons.refresh),
///       onPressed: () {
///         // Invalider toutes les requêtes users
///         context.qora.invalidateQueries(
///           (key) => key.parts.first == 'users',
///         );
///       },
///     );
///   }
/// }
/// ```
library;

// Export du package core qora
export 'package:qora/qora.dart';

// Export des composants Flutter
export 'src/widgets/qora_scope.dart';
export 'src/widgets/qora_builder.dart';

// Export des extensions
export 'src/extensions/build_context_extension.dart';

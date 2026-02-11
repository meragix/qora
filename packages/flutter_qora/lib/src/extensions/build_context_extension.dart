import 'package:flutter/widgets.dart';
import 'package:flutter_qora/src/widgets/qora_scope.dart';
import 'package:qora/qora.dart';

/// Extension sur BuildContext pour un accès rapide au QoraClient
///
/// Permet d'écrire `context.qora` au lieu de `QoraScope.of(context)`
///
/// Exemple :
/// ```dart
/// // Invalider une requête
/// context.qora.invalidateQuery(QoraKey(['users']));
///
/// // Récupérer des données
/// final data = await context.qora.fetchQuery(
///   key: QoraKey(['user', userId]),
///   fetcher: () => api.getUser(userId),
/// );
///
/// // Observer l'état
/// context.qora.watchState<User>(QoraKey(['user', 1]));
/// ```
extension QoraBuildContextExtension on BuildContext {
  /// Raccourci pour accéder au QoraClient
  ///
  /// Lance une erreur si aucun QoraScope n'est trouvé dans l'arbre
  QoraClient get qora => QoraScope.of(this);

  /// Version nullable qui retourne null si aucun QoraScope n'est trouvé
  QoraClient? get qoraOrNull => QoraScope.maybeOf(this);
}

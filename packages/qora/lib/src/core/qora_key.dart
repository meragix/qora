import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Représente une clé unique pour identifier une query dans le cache
///
/// Utilise la deep equality pour comparer les listes de valeurs.
/// Exemple : QoraKey(['users', 1]) == QoraKey(['users', 1]) → true
@immutable
class QoraKey {
  /// Les parties constituant la clé (peut contenir n'importe quel type)
  final List<dynamic> parts;

  /// Hash précalculé pour optimiser les comparaisons
  final int _hashCode;

  /// Crée une clé de query à partir d'une liste de parties
  ///
  /// ```dart
  /// final userKey = QoraKey(['users', userId]);
  /// final postKey = QoraKey(['posts', postId, 'comments']);
  /// ```
  QoraKey(this.parts) : _hashCode = const DeepCollectionEquality().hash(parts);

  /// Crée une clé à partir d'une seule valeur
  factory QoraKey.single(dynamic value) => QoraKey([value]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QoraKey && runtimeType == other.runtimeType && const DeepCollectionEquality().equals(parts, other.parts);

  @override
  int get hashCode => _hashCode;

  @override
  String toString() => 'QoraKey(${parts.join('.')})';

  /// Vérifie si cette clé commence par le préfixe donné
  ///
  /// Utile pour l'invalidation par préfixe :
  /// ```dart
  /// QoraKey(['users', 1]).hasPrefix(['users']) → true
  /// ```
  bool hasPrefix(List<dynamic> prefix) {
    if (parts.length < prefix.length) return false;

    for (var i = 0; i < prefix.length; i++) {
      if (parts[i] != prefix[i]) return false;
    }

    return true;
  }

  /// Sérialise la clé en string pour le stockage
  String serialize() {
    return parts.map((p) => p.toString()).join('__');
  }

  /// Désérialise une clé depuis une string
  static QoraKey deserialize(String serialized) {
    final parts = serialized.split('__');
    return QoraKey(parts);
  }

  // Convertit la clé en chaîne pour le logging
  String toDebugString() => parts.join('_');
}

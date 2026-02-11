import 'package:qora/src/core/qora_options.dart';
import 'package:qora/src/utils/qora_exception.dart';

/// Configuration globale du client
class QoraClientConfig {
  /// Options par défaut pour toutes les requêtes
  final QoraOptions defaultOptions;

  /// Fonction pour mapper les erreurs brutes en ReqryException
  final QoraException Function(Object error, StackTrace? stackTrace)?
      errorMapper;

  /// Active le mode debug pour les logs
  final bool debugMode;

  const QoraClientConfig({
    this.defaultOptions = const QoraOptions(),
    this.errorMapper,
    this.debugMode = false,
  });
}

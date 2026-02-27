abstract class ConnectivityManager {
  /// Stream du statut réseau
  Stream<NetworkStatus> get statusStream;

  /// Statut actuel
  NetworkStatus get currentStatus;

  /// Démarre l'écoute
  Future<void> start();

  /// Arrête l'écoute
  void dispose();
}

enum NetworkStatus { online, offline, unknown }

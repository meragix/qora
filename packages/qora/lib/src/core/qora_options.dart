// Configuration d'une requête
class QoraOptions {
  /// Temps avant que les données soient considérées stale
  ///
  /// Par défaut : 0 (immédiatement stale)
  final Duration staleTime;

  /// Temps de conservation dans le cache même si plus utilisé
  ///
  /// Par défaut : 5 minutes
  final Duration cacheTime;

  /// Si la query doit être activée
  ///
  /// Utile pour les queries conditionnelles
  final bool enabled;

  /// Nombre de tentatives en cas d'erreur
  final int retryCount;

  /// Délai entre les tentatives
  final Duration retryDelay;

  /// Fonction pour calculer le délai exponentiel
  final Duration Function(int attemptIndex)? retryDelayCalculator;

  /// Refetch quand l'app revient au premier plan
  final bool refetchOnWindowFocus;

  /// Refetch quand la connexion réseau revient
  final bool refetchOnReconnect;

  const QoraOptions({
    this.staleTime = Duration.zero,
    this.cacheTime = const Duration(minutes: 5),
    this.enabled = true,
    this.retryCount = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.retryDelayCalculator,
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
  });

  /// Fusionne avec d'autres options (priorité à other)
  QoraOptions merge(QoraOptions? other) {
    if (other == null) return this;

    return QoraOptions(
      staleTime: other.staleTime,
      cacheTime: other.cacheTime,
      enabled: other.enabled,
      retryCount: other.retryCount,
      retryDelay: other.retryDelay,
      refetchOnWindowFocus: other.refetchOnWindowFocus,
      refetchOnReconnect: other.refetchOnReconnect,
    );
  }

  /// Calcule le délai pour une tentative donnée
  Duration getRetryDelay(int attemptIndex) {
    if (retryDelayCalculator != null) {
      return retryDelayCalculator!(attemptIndex);
    }
    // Délai exponentiel par défaut: delay * 2^attemptIndex
    return retryDelay * (1 << attemptIndex);
  }
}

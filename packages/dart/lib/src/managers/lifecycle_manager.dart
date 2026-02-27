abstract class LifecycleManager {
  /// Stream des changements de lifecycle
  Stream<LifecycleState> get lifecycleStream;

  /// État actuel
  LifecycleState get currentState;

  /// Démarre l'écoute
  void start();

  /// Arrête l'écoute
  void dispose();
}

enum LifecycleState { active, inactive, paused, resumed }

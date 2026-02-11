import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_qora/src/widgets/qora_scope.dart';
import 'package:qora/qora.dart';

/// Widget qui s'abonne automatiquement à une requête Reqry et rebuild lors des changements d'état
///
/// Gère automatiquement :
/// - Le fetch initial au montage
/// - L'abonnement au stream d'état
/// - La déduplication des requêtes
/// - Le désabonnement propre au démontage
///
/// Exemple basique :
/// ```dart
/// QoraBuilder<User>(
///   queryKey: QoraKey(['user', userId]),
///   queryFn: () => api.getUser(userId),
///   builder: (context, state) {
///     return state.when(
///       initial: () => Text('Pas encore chargé'),
///       loading: (prev) => CircularProgressIndicator(),
///       success: (data, _) => Text(data.name),
///       failure: (err, _, prev) => Text('Erreur: $err'),
///     );
///   },
/// )
/// ```
///
/// Avec keepPreviousData pour éviter les flashs :
/// ```dart
/// QoraBuilder<List<User>>(
///   queryKey: QoraKey(['users', page]),
///   queryFn: () => api.getUsers(page),
///   keepPreviousData: true, // ✅ Affiche les données de la page précédente pendant le chargement
///   builder: (context, state) {
///     return state.when(
///       loading: (prev) => prev != null
///         ? UserList(users: prev, isRefreshing: true) // Affiche l'ancienne liste avec un spinner
///         : CircularProgressIndicator(), // Premier chargement
///       success: (data, _) => UserList(users: data),
///       // ...
///     );
///   },
/// )
/// ```
class QoraBuilder<T> extends StatefulWidget {
  /// La clé unique identifiant cette requête
  final QoraKey queryKey;

  /// La fonction qui exécute la requête
  final Future<T> Function() queryFn;

  /// Le builder qui construit le widget en fonction de l'état
  final Widget Function(BuildContext context, QoraState<T> state) builder;

  /// Options de configuration de la requête
  final QoraOptions? options;

  /// Le client à utiliser (optionnel, utilise ReqryScope.of(context) par défaut)
  final QoraClient? client;

  /// Si true, conserve les données précédentes lors d'un nouveau chargement
  /// pour éviter les flashs blancs (utile pour la pagination)
  final bool keepPreviousData;

  /// Si true, ne déclenche pas automatiquement le fetch au montage
  /// (utile si vous voulez contrôler manuellement le fetch)
  final bool enabled;

  const QoraBuilder({
    super.key,
    required this.queryKey,
    required this.queryFn,
    required this.builder,
    this.options,
    this.client,
    this.keepPreviousData = false,
    this.enabled = true,
  });

  @override
  State<QoraBuilder<T>> createState() => _QoraBuilderState<T>();
}

class _QoraBuilderState<T> extends State<QoraBuilder<T>> {
  late QoraClient _client;
  StreamSubscription<QoraState<T>>? _subscription;
  QoraState<T> _currentState = const QoraState.initial();
  T? _previousData;

  @override
  void initState() {
    super.initState();
    _initializeClient();
    _subscribe();

    if (widget.enabled) {
      _executeFetch();
    }
  }

  @override
  void didUpdateWidget(QoraBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si le client a changé
    if (widget.client != oldWidget.client) {
      _initializeClient();
      _resubscribe();
      if (widget.enabled) {
        _executeFetch();
      }
    }

    // Si la clé a changé
    else if (widget.queryKey != oldWidget.queryKey) {
      _resubscribe();
      if (widget.enabled) {
        _executeFetch();
      }
    }

    // Si enabled passe de false à true
    else if (widget.enabled && !oldWidget.enabled) {
      _executeFetch();
    }

    // Si keepPreviousData a changé, forcer un rebuild
    else if (widget.keepPreviousData != oldWidget.keepPreviousData) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Initialise le client (depuis widget.client ou ReqryScope)
  void _initializeClient() {
    _client = widget.client ?? QoraScope.of(context);
  }

  /// S'abonne au stream d'état de la requête
  void _subscribe() {
    _subscription?.cancel();
    _subscription = _client.watchState<T>(widget.queryKey).listen(
      (state) {
        if (!mounted) return;

        setState(() {
          _currentState = state;

          // Mémoriser les données pour keepPreviousData
          if (state is QoraSuccess<T>) {
            _previousData = state.data;
          }
        });
      },
      onError: (error) {
        // Les erreurs sont déjà gérées dans le QoraState
        // Mais on peut logger ici si nécessaire
        debugPrint('[QoraBuilder] Stream error: $error');
      },
    );
  }

  /// Se réabonne (utile lors d'un changement de clé ou de client)
  void _resubscribe() {
    _subscribe();
  }

  /// Exécute le fetch de la requête
  Future<void> _executeFetch() async {
    try {
      await _client.fetchQuery<T>(
        key: widget.queryKey,
        fetcher: widget.queryFn,
        options: widget.options,
      );
    } catch (error) {
      // L'erreur est déjà capturée et stockée dans le state
      // On ne fait rien ici pour éviter les exceptions non gérées
      debugPrint('[QoraBuilder] Fetch error handled in state: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Appliquer keepPreviousData si nécessaire
    final effectiveState = widget.keepPreviousData
        ? _applyKeepPreviousData(_currentState)
        : _currentState;

    return widget.builder(context, effectiveState);
  }

  /// Applique la logique keepPreviousData
  ///
  /// Si on est en Loading et qu'on a des données précédentes,
  /// on retourne un état Loading avec previousData au lieu d'un état vide
  QoraState<T> _applyKeepPreviousData(QoraState<T> state) {
    return state.when(
      initial: () => state,
      loading: (previousDataFromState) {
        // Si on a déjà des previousData dans le state, les utiliser
        if (previousDataFromState != null) {
          return state;
        }

        // Sinon, utiliser nos données mémorisées
        if (_previousData != null) {
          return QoraState<T>.loading(previousData: _previousData);
        }

        return state;
      },
      success: (_, __) => state,
      failure: (error, stackTrace, previousDataFromState) {
        // Idem pour les erreurs
        if (previousDataFromState != null) {
          return state;
        }

        if (_previousData != null) {
          return QoraState<T>.failure(
            error: error,
            stackTrace: stackTrace,
            previousData: _previousData,
          );
        }

        return state;
      },
    );
  }
}

/// Widget simplifié qui ne s'abonne qu'à l'état sans déclencher de fetch
///
/// Utile pour afficher l'état d'une requête déjà lancée ailleurs
///
/// Exemple :
/// ```dart
/// QoraStateBuilder<User>(
///   queryKey: QoraKey(['user', userId]),
///   builder: (context, state) {
///     return state.when(
///       initial: () => Text('Aucune donnée'),
///       loading: (_) => CircularProgressIndicator(),
///       success: (data, _) => Text(data.name),
///       failure: (error, _, __) => Text('Erreur: $error'),
///     );
///   },
/// )
/// ```
class QoraStateBuilder<T> extends StatefulWidget {
  /// La clé de la requête à observer
  final QoraKey queryKey;

  /// Le builder qui construit le widget
  final Widget Function(BuildContext context, QoraState<T> state) builder;

  /// Le client à utiliser (optionnel)
  final QoraClient? client;

  const QoraStateBuilder({
    super.key,
    required this.queryKey,
    required this.builder,
    this.client,
  });

  @override
  State<QoraStateBuilder<T>> createState() => _QoraStateBuilderState<T>();
}

class _QoraStateBuilderState<T> extends State<QoraStateBuilder<T>> {
  late QoraClient _client;
  StreamSubscription<QoraState<T>>? _subscription;
  QoraState<T> _currentState = const QoraState.initial();

  @override
  void initState() {
    super.initState();
    _initializeClient();
    _subscribe();
  }

  @override
  void didUpdateWidget(QoraStateBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.client != oldWidget.client) {
      _initializeClient();
      _resubscribe();
    } else if (widget.queryKey != oldWidget.queryKey) {
      _resubscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _initializeClient() {
    _client = widget.client ?? QoraScope.of(context);
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _client.watchState<T>(widget.queryKey).listen(
      (state) {
        if (!mounted) return;
        setState(() {
          _currentState = state;
        });
      },
    );
  }

  void _resubscribe() {
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentState);
  }
}

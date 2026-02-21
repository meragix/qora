// ignore_for_file: avoid_print

import 'dart:async';
import 'package:qora/src/core/cached_entry.dart';
import 'package:qora/src/core/key/key_cache_map.dart';
import 'package:qora/src/core/key/qora_key.dart';
import 'package:qora/src/core/qora_client_config.dart';
import 'package:qora/src/core/qora_options.dart';
import 'package:qora/src/core/qora_state.dart';
import 'package:qora/src/core/query_function.dart';

/// Le moteur principal de Qora
class QoraClient {
  /// Configuration par défaut
  final QoraClientConfig config;

  final KeyCacheMap<CacheEntry<dynamic>> _cache = KeyCacheMap<CacheEntry<dynamic>>();

  final KeyCacheMap<Future<dynamic>> _pendingRequests = KeyCacheMap<Future<dynamic>>();
  // final Map<Object, Set<QueryObserver>> _observers = {};

  Timer? _evictionTimer;
  // ignore: prefer_final_fields
  bool _isDisposed = false;

  QoraClient({QoraClientConfig? config}) : config = config ?? const QoraClientConfig() {
    _startEvictionTimer();
  }

  /// Démarre le timer d'éviction du cache
  void _startEvictionTimer() {
    _evictionTimer?.cancel();
    _evictionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _evictStaleEntries();
    });
  }

  /// Supprime les entrées expirées du cache
  void _evictStaleEntries() {
    final keysToRemove = <Object>[];

    for (final entry in _cache.entries) {
      if (entry.value.shouldEvict(config.defaultOptions.cacheTime)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.get(key)?.dispose();
      _cache.remove(key);
      if (config.debugMode) {
        print('[Reqry] Evicted cache entry: ${key.toString()}');
      }
    }
  }

  /// Log en mode debug
  void _log(String message) {
    if (config.debugMode) {
      print('[Reqry] $message');
    }
  }

  /// Vérifie que le client n'est pas disposé
  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('ReqryClient has been disposed');
    }
  }

  /// Mappe une erreur brute en ReqryException
  Object? _mapError(Object error, StackTrace? stackTrace) {
    if (config.errorMapper != null) {
      return config.errorMapper!(error, stackTrace);
    }
    return error;
  }

  /// Retrieves or creates a cache entry
  CacheEntry<T> _getOrCreateEntry<T>(Object key) {
    _assertNotDisposed();

    final normalizedKey = normalizeKey(key);
    final cached = _cache.get(normalizedKey);

    if (cached != null) {
      final entry = cached as CacheEntry<T>;

      if (entry.shouldEvict(config.defaultOptions.cacheTime)) {
        entry.dispose();
        _cache.remove(normalizedKey);

        if (config.debugMode) {
          print('[Qora] Lazy evicted: $normalizedKey');
        }
      } else {
        if (config.debugMode) {
          print('[Qora] Cache HIT: $normalizedKey');
        }
        return entry;
      }
    }

    print('[Qora] Cache MISS: $normalizedKey');
    final data = CacheEntry<T>(
      state: const QoraState.initial(),
      createdAt: DateTime.now(),
    );

    _cache.set(normalizedKey, data);
    return data;
  }

  /// Exécute une requête avec retry
  Future<T> _executeWithRetry<T>({
    required Future<T> Function() fetcher,
    required QoraOptions options,
    required Object key,
  }) async {
    int attempt = 0;
    Object? lastError;
    //StackTrace? lastStackTrace;

    while (attempt <= options.retryCount) {
      try {
        _log('Executing query ${key.toString()} (attempt ${attempt + 1})');
        final result = await fetcher();
        return result;
      } catch (error, _) {
        lastError = error;
        //lastStackTrace = stackTrace;

        if (attempt < options.retryCount) {
          final delay = options.getRetryDelay(attempt);
          _log('Retry ${attempt + 1}/${options.retryCount} for ${key.toString()} in ${delay.inMilliseconds}ms');
          await Future.delayed(delay, () {});
          attempt++;
        } else {
          break;
        }
      }
    }

    throw lastError!;
  }

  /// Récupère les données d'une query (avec cache, déduplication et stale-while-revalidate)
  ///
  /// ```dart
  /// final users = await client.fetchQuery(
  ///   key: ['users'],
  ///   fetcher: () => api.getUsers(),
  /// );
  /// ```
  Future<T> fetchQuery<T>({
    required Object key,
    required QueryFunction<T> fetcher,
    QoraOptions? options,
  }) async {
    _assertNotDisposed();

    final mergedOpts = config.defaultOptions.merge(options);
    final entry = _getOrCreateEntry<T>(key);

    if (!mergedOpts.enabled) {
      entry.updateState(
        QoraState.failure(error: StateError('Query is disabled: $key')),
      );
      _pendingRequests.remove(key);
    }

    // Check if a request is already in progress (deduplication).
    if (_pendingRequests.containsKey(key)) {
      _log('Deduplicating query ${key.toString()}');
      return await _pendingRequests.get(key) as Future<T>;
    }

    // Stale-While-Revalidate: return cached data if available
    final currentState = entry.state;
    T? cachedData;
    bool hasValidCache = false;

    if (currentState is QoraSuccess<T>) {
      cachedData = currentState.data;
      hasValidCache = !entry.isStale(mergedOpts.staleTime);

      if (hasValidCache) {
        _log('Returning fresh cached data for ${key.toString()}');
        entry.lastAccessedAt = DateTime.now();
        return Future.value(cachedData);
      }

      // Données stale, on met à jour en arrière-plan
      _log('Cache stale for ${key.toString()}, revalidating...');
      entry.updateState(QoraState.loading(previousData: cachedData));
    } else {
      // Pas de cache, on passe en loading
      entry.updateState(const QoraState.loading());
    }

    // Créer et enregistrer la requête
    final pendingRequest = _executeWithRetry<T>(
      fetcher: fetcher,
      options: mergedOpts,
      key: key,
    ).then((data) {
      entry.updateState(
        QoraState.success(
          data: data,
          updatedAt: DateTime.now(),
        ),
      );
      _pendingRequests.remove(key);
      return data;
    }).catchError((Object error, StackTrace stackTrace) {
      final mappedError = _mapError(error, stackTrace);
      entry.updateState(
        QoraState.failure(
          error: mappedError!,
          stackTrace: stackTrace,
          previousData: cachedData,
        ),
      );
      _pendingRequests.remove(key);
      throw mappedError;
    });

    _pendingRequests.set(key, pendingRequest);

    // Si on a des données en cache stale, les retourner immédiatement
    if (cachedData != null) {
      _log('Returning stale data for ${key.toString()}');
      // La revalidation continue en arrière-plan
      return cachedData;
    }

    return pendingRequest;
  }

  /// Observe l'état d'une requête de manière réactive
  Stream<QoraState<T>> watchState<T>(Object key) {
    _assertNotDisposed();
    final entry = _getOrCreateEntry<T>(key);
    return entry.stream.asBroadcastStream();
  }

  /// Récupère l'état actuel d'une requête
  QoraState<T> getState<T>(Object key) {
    _assertNotDisposed();
    final entry = _cache.get(key);
    if (entry == null) {
      return const QoraState.initial();
    }
    return entry.state as QoraState<T>;
  }

  /// Invalide une requête et force son rafraîchissement
  void invalidateQuery(Object key) {
    _assertNotDisposed();
    final entry = _cache.get(key);
    if (entry != null) {
      _log('Invalidating query ${key.toString()}');
      _cache.remove(key);
      entry.dispose();
    }
  }

  /// Invalide toutes les requêtes correspondant à un prédicat
  void invalidateQueries(bool Function(Object key) predicate) {
    _assertNotDisposed();
    final keysToInvalidate = _cache.keys.where(predicate).toList();
    for (final key in keysToInvalidate) {
      invalidateQuery(key);
    }
  }

  /// Met à jour manuellement les données d'une requête
  void setQueryData<T>(Object key, T data) {
    _assertNotDisposed();
    final entry = _getOrCreateEntry<T>(key);
    entry.updateState(
      QoraState.success(
        data: data,
        updatedAt: DateTime.now(),
      ),
    );
    _log('Manually updated query data for ${key.toString()}');
  }

  /// Restaure une snapshot du cache (pour rollback)
  void restoreQueryData<T>(Object key, T? snapshot) {
    _assertNotDisposed();
    if (snapshot == null) {
      removeQuery(key);
    } else {
      final entry = _getOrCreateEntry<T>(key);
      entry.updateState(
        QoraState.success(
          data: snapshot,
          updatedAt: DateTime.now(),
        ),
      );
      _log('Restore query data for ${key.toString()}');
    }
  }

  /// Refetch toutes les queries actives quand l'app revient au premier plan
  void refetchOnWindowFocus() {
    throw UnimplementedError();
  }

  /// Refetch toutes les queries actives quand le réseau revient
  void refetchOnReconnect() {
    refetchOnWindowFocus(); // Même logique
  }

  /// Récupère toutes les clés en cache
  List<Object> get cachedKeys => _cache.keys.toList();

  /// Supprime une entrée du cache
  void removeQuery(Object key) {
    _assertNotDisposed();
    _cache.get(key)?.dispose();
    _cache.remove(key);
    _pendingRequests.remove(key);
    _log('Removed query ${key.toString()}');
  }

  /// Vide tout le cache
  void clear() {
    _assertNotDisposed();
    _log('Clearing all cache');
    for (final entry in _cache.values) {
      entry.dispose();
    }
    _cache.clear();
    _pendingRequests.clear();
  }

  /// Libère les ressources (à appeler impérativement lors de la destruction)
  /// ⚠️ Après dispose(), le client ne peut plus être utilisé
  void dispose() {
    if (_isDisposed) return;

    _log('Disposing ReqryClient');
    _isDisposed = true;

    // Arrêter le timer d'éviction
    _evictionTimer?.cancel();
    _evictionTimer = null;

    // Fermer tous les StreamControllers
    for (final entry in _cache.values) {
      entry.dispose();
    }

    // Vider les maps
    _cache.clear();
    _pendingRequests.clear();
  }
}

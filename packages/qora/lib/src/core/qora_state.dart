/// État d'une requête Reqry avec pattern matching exhaustif
sealed class QoraState<T> {
  const QoraState();

  /// État initial, aucune donnée n'a encore été chargée
  const factory QoraState.initial() = QoraInitial<T>;

  /// État de chargement, peut contenir des données précédentes
  const factory QoraState.loading({T? previousData}) = QoraLoading<T>;

  /// État de succès avec données et timestamp
  const factory QoraState.success({
    required T data,
    required DateTime updatedAt,
  }) = QoraSuccess<T>;

  /// État d'erreur avec l'erreur et éventuellement des données précédentes
  const factory QoraState.error({
    required Object error,
    StackTrace? stackTrace,
    T? previousData,
  }) = QoraError<T>;

  /// Vérifie si l'état est en chargement
  bool get isLoading => this is QoraLoading<T>;

  /// Vérifie si l'état contient des données (succès ou loading/error avec previousData)
  bool get hasData => switch (this) {
        QoraSuccess() => true,
        QoraLoading(:final previousData) => previousData != null,
        QoraError(:final previousData) => previousData != null,
        QoraInitial() => false,
      };

  /// Récupère les données si disponibles
  T? get dataOrNull => switch (this) {
        QoraSuccess(:final data) => data,
        QoraLoading(:final previousData) => previousData,
        QoraError(:final previousData) => previousData,
        QoraInitial() => null,
      };

  /// Vérifie si l'état est en erreur
  bool get hasError => this is QoraError<T>;

  /// Pattern matching utilitaire
  R when<R>({
    required R Function() initial,
    required R Function(T? previousData) loading,
    required R Function(T data, DateTime updatedAt) success,
    required R Function(Object error, StackTrace? stackTrace, T? previousData) err,
  }) {
    return switch (this) {
      QoraInitial() => initial(),
      QoraLoading(:final previousData) => loading(previousData),
      QoraSuccess(:final data, :final updatedAt) => success(data, updatedAt),
      QoraError(:final error, :final stackTrace, :final previousData) => err(error, stackTrace, previousData),
    };
  }
}

/// État initial
final class QoraInitial<T> extends QoraState<T> {
  const QoraInitial();

  @override
  String toString() => 'QoraInitial()';
}

/// État de chargement
final class QoraLoading<T> extends QoraState<T> {
  final T? previousData;

  const QoraLoading({this.previousData});

  @override
  String toString() => 'QoraLoading(previousData: $previousData)';
}

/// État de succès
final class QoraSuccess<T> extends QoraState<T> {
  final T data;
  final DateTime updatedAt;

  const QoraSuccess({
    required this.data,
    required this.updatedAt,
  });

  @override
  String toString() => 'QoraSuccess(data: $data, updatedAt: $updatedAt)';
}

/// État d'erreur
final class QoraError<T> extends QoraState<T> {
  final Object error;
  final StackTrace? stackTrace;
  final T? previousData;

  const QoraError({
    required this.error,
    this.stackTrace,
    this.previousData,
  });

  @override
  String toString() => 'QoraError(error: $error, previousData: $previousData)';
}

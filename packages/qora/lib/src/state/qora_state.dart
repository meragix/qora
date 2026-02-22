import 'package:meta/meta.dart';

/// Represents the state of a query operation.
///
/// A query can be in one of four states:
/// - [Initial]: Query hasn't started yet
/// - [Loading]: Actively fetching data (with optional previous data)
/// - [Success]: Data fetched successfully
/// - [Failure]: Fetch failed (with optional previous data for graceful degradation)
///
/// Use pattern matching to handle all states exhaustively:
///
/// ```dart
/// switch (state) {
///   case Initial():
///     return Text('Ready to load');
///   case Loading(:final previousData):
///     return previousData != null
///       ? Stack(children: [DataView(previousData), Spinner()])
///       : Spinner();
///   case Success(:final data):
///     return DataView(data);
///   case Failure(:final error, :final previousData):
///     return previousData != null
///       ? Stack(children: [DataView(previousData), ErrorBanner()])
///       : ErrorScreen(error);
/// }
/// ```
@immutable
sealed class QoraState<T> {
  const QoraState();

  /// Returns true if this state contains usable data.
  ///
  /// This includes:
  /// - [Success] state (always has data)
  /// - [Loading] state with previousData
  /// - [Failure] state with previousData
  bool get hasData => switch (this) {
        Success() => true,
        Loading(:final previousData) => previousData != null,
        Failure(:final previousData) => previousData != null,
        _ => false,
      };

  /// Extracts data from any state that has it, or returns null.
  ///
  /// Priority: Success.data > Loading/Failure.previousData > null
  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        Loading(:final previousData) => previousData,
        Failure(:final previousData) => previousData,
        _ => null,
      };

  /// Returns true if actively loading.
  bool get isLoading => this is Loading<T>;

  /// Returns true if in error state.
  bool get isError => this is Failure<T>;

  /// Returns true if successful.
  bool get isSuccess => this is Success<T>;

  /// Returns true if initial (not started).
  bool get isInitial => this is Initial<T>;

  /// Extracts error from Failure state, or returns null.
  Object? get errorOrNull => switch (this) {
        Failure(:final error) => error,
        _ => null,
      };

  /// Maps the data type while preserving state structure.
  ///
  /// Example:
  /// ```dart
  /// final userState = Success(data: User(id: 1), updatedAt: DateTime.now());
  /// final idState = userState.map((user) => user.id);
  /// // idState is Success<int>
  /// ```
  QoraState<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Initial() => Initial<R>(),
      Loading(:final previousData) => Loading<R>(
          previousData: previousData != null ? transform(previousData) : null,
        ),
      Success(:final data, :final updatedAt) => Success<R>(
          data: transform(data),
          updatedAt: updatedAt,
        ),
      Failure(:final error, :final stackTrace, :final previousData) => Failure<R>(
          error: error,
          stackTrace: stackTrace,
          previousData: previousData != null ? transform(previousData) : null,
        ),
    };
  }

  /// Executes a callback based on the current state.
  ///
  /// All callbacks are optional. If a callback is not provided for a state,
  /// nothing happens for that state.
  ///
  /// Example:
  /// ```dart
  /// state.when(
  ///   onSuccess: (data) => print('Success: $data'),
  ///   onError: (error, _) => print('Error: $error'),
  /// );
  /// ```
  void when({
    void Function()? onInitial,
    void Function(T? previousData)? onLoading,
    void Function(T data, DateTime updatedAt)? onSuccess,
    void Function(Object error, StackTrace? stackTrace, T? previousData)? onError,
  }) {
    switch (this) {
      case Initial():
        onInitial?.call();
      case Loading(:final previousData):
        onLoading?.call(previousData);
      case Success(:final data, :final updatedAt):
        onSuccess?.call(data, updatedAt);
      case Failure(:final error, :final stackTrace, :final previousData):
        onError?.call(error, stackTrace, previousData);
    }
  }

  /// Maps the state to a value of type R based on callbacks.
  ///
  /// All callbacks are required (exhaustive).
  ///
  /// Example:
  /// ```dart
  /// final widget = state.maybeWhen(
  ///   onSuccess: (data, _) => DataWidget(data),
  ///   orElse: () => LoadingWidget(),
  /// );
  /// ```
  R maybeWhen<R>({
    required R Function() orElse,
    R Function()? onInitial,
    R Function(T? previousData)? onLoading,
    R Function(T data, DateTime updatedAt)? onSuccess,
    R Function(Object error, StackTrace? stackTrace, T? previousData)? onError,
  }) {
    return switch (this) {
      Initial() => onInitial?.call() ?? orElse(),
      Loading(:final previousData) => onLoading?.call(previousData) ?? orElse(),
      Success(:final data, :final updatedAt) => onSuccess?.call(data, updatedAt) ?? orElse(),
      Failure(:final error, :final stackTrace, :final previousData) =>
        onError?.call(error, stackTrace, previousData) ?? orElse(),
    };
  }
}

/// Initial state - query hasn't started yet.
///
/// This is the default state before any fetch operation.
/// Transitions to [Loading] on first fetch.
@immutable
final class Initial<T> extends QoraState<T> {
  const Initial();

  @override
  bool operator ==(Object other) => identical(this, other) || other is Initial<T>;

  @override
  int get hashCode => (Initial).hashCode ^ T.hashCode;

  @override
  String toString() => 'Initial<$T>()';
}

/// Loading state - actively fetching data.
///
/// [previousData] contains data from a previous successful fetch, if any.
/// This enables showing stale data while refreshing, improving UX.
///
/// Example:
/// ```dart
/// // First fetch
/// Loading(previousData: null) // Show spinner
///
/// // Refetch
/// Loading(previousData: oldData) // Show stale data + subtle loading indicator
/// ```
@immutable
final class Loading<T> extends QoraState<T> {
  /// Data from previous successful fetch, if any.
  ///
  /// Null on first fetch, non-null on refetch/refresh.
  final T? previousData;

  const Loading({this.previousData});

  @override
  bool operator ==(Object other) => identical(this, other) || other is Loading<T> && previousData == other.previousData;

  @override
  int get hashCode => Object.hash(Loading, T, previousData);

  @override
  String toString() => 'Loading<$T>(previousData: $previousData)';
}

/// Success state - data fetched successfully.
///
/// Contains the fetched [data] and the timestamp when it was fetched ([updatedAt]).
@immutable
final class Success<T> extends QoraState<T> {
  /// The successfully fetched data.
  final T data;

  /// When this data was fetched from the server.
  ///
  /// Use this to determine data freshness:
  /// ```dart
  /// final age = DateTime.now().difference(state.updatedAt);
  /// if (age > Duration(minutes: 5)) {
  ///   print('Data is stale');
  /// }
  /// ```
  final DateTime updatedAt;

  const Success({
    required this.data,
    required this.updatedAt,
  });

  /// Create a Success state with current timestamp.
  factory Success.now(T data) {
    return Success(data: data, updatedAt: DateTime.now());
  }

  /// Get the age of this data.
  Duration get age => DateTime.now().difference(updatedAt);

  /// Check if data is stale (older than given duration).
  bool isStale(Duration threshold) => age > threshold;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T> && data == other.data && updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(Success, T, data, updatedAt);

  @override
  String toString() => 'Success<$T>(data: $data, updatedAt: $updatedAt)';
}

/// Failure state - fetch operation failed.
///
/// Contains the [error] that occurred and optionally [previousData]
/// from a previous successful fetch for graceful degradation.
@immutable
final class Failure<T> extends QoraState<T> {
  /// The error that occurred during fetch.
  final Object error;

  /// Optional stack trace for debugging.
  final StackTrace? stackTrace;

  /// Data from previous successful fetch, if any.
  ///
  /// Enables showing stale data with error banner instead of
  /// blank error screen.
  final T? previousData;

  const Failure({
    required this.error,
    this.stackTrace,
    this.previousData,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> && error == other.error && stackTrace == other.stackTrace && previousData == other.previousData;

  @override
  int get hashCode => Object.hash(Error, T, error, stackTrace, previousData);

  @override
  String toString() => 'Failure<$T>(error: $error, previousData: $previousData)';
}

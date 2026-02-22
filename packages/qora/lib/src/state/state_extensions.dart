import 'package:qora/src/state/qora_state.dart';

/// Additional utility extensions for [QoraState].
extension QoraStateExtensions<T> on QoraState<T> {
  /// Returns the data if available, or throws an error.
  ///
  /// Throws [StateError] if state has no data.
  ///
  /// Use this when you're certain data should exist:
  /// ```dart
  /// final user = state.requireData(); // Throws if no data
  /// ```
  T requireData() {
    final data = dataOrNull;
    if (data == null) {
      throw StateError('No data available in state: $this');
    }
    return data;
  }

  /// Returns data if Success, null otherwise (ignores previousData).
  T? get successDataOrNull => switch (this) {
        Success(:final data) => data,
        _ => null,
      };

  /// Returns true if this is a first-time loading (no previous data).
  bool get isFirstLoad =>
      this is Loading<T> && (this as Loading<T>).previousData == null;

  /// Returns true if this is a refresh (loading with previous data).
  bool get isRefreshing =>
      this is Loading<T> && (this as Loading<T>).previousData != null;

  /// Returns true if state has an error.
  bool get hasError => this is Failure<T>;

  /// Checks if data is stale based on a threshold.
  ///
  /// Returns false for non-Success states.
  bool isStale(Duration threshold) => switch (this) {
        Success(:final updatedAt) =>
          DateTime.now().difference(updatedAt) > threshold,
        _ => false,
      };

  /// Gets the timestamp when data was last updated.
  ///
  /// Returns null for non-Success states.
  DateTime? get updatedAt => switch (this) {
        Success(:final updatedAt) => updatedAt,
        _ => null,
      };

  /// Maps only if state is Success, otherwise returns the state as-is.
  ///
  /// Useful for chaining transformations:
  /// ```dart
  /// state
  ///   .mapSuccess((users) => users.where((u) => u.isActive))
  ///   .mapSuccess((users) => users.map((u) => u.name).toList());
  /// ```
  QoraState<R> mapSuccess<R>(R Function(T data) transform) {
    return switch (this) {
      Success(:final data, :final updatedAt) => Success(
          data: transform(data),
          updatedAt: updatedAt,
        ),
      Initial() => Initial<R>(),
      Loading(:final previousData) => Loading<R>(
          previousData: previousData != null ? transform(previousData) : null,
        ),
      Failure(:final error, :final stackTrace, :final previousData) =>
        Failure<R>(
          error: error,
          stackTrace: stackTrace,
          previousData: previousData != null ? transform(previousData) : null,
        ),
    };
  }

  /// Combines this state with another state using a combiner function.
  ///
  /// Both states must be Success for the result to be Success.
  /// If either is Loading, result is Loading.
  /// If either is Error, result is Error.
  /// Otherwise, result is Initial.
  ///
  /// Example:
  /// ```dart
  /// final userState = Success(data: user, updatedAt: DateTime.now());
  /// final postsState = Success(data: posts, updatedAt: DateTime.now());
  ///
  /// final combined = userState.combine(
  ///   postsState,
  ///   (user, posts) => UserWithPosts(user, posts),
  /// );
  /// // combined is Success<UserWithPosts>
  /// ```
  QoraState<R> combine<T2, R>(
    QoraState<T2> other,
    R Function(T data1, T2 data2) combiner,
  ) {
    // If both Success, combine
    if (this is Success<T> && other is Success<T2>) {
      return Success(
        data: combiner((this as Success<T>).data, other.data),
        updatedAt: DateTime.now(),
      );
    }

    // If either Loading, result is Loading
    if (this is Loading || other is Loading) {
      return Loading<R>();
    }

    // If either Failure, result is Error
    if (this is Failure<T>) {
      return Failure<R>(error: (this as Failure<T>).error);
    }
    if (other is Failure<T2>) {
      return Failure<R>(error: other.error);
    }

    // Otherwise Initial
    return Initial<R>();
  }

  /// Folds the state into a single value of type R.
  ///
  /// All branches are required (exhaustive).
  ///
  /// Example:
  /// ```dart
  /// final message = state.fold(
  ///   onInitial: () => 'Not loaded',
  ///   onLoading: (prev) => prev != null ? 'Refreshing...' : 'Loading...',
  ///   onSuccess: (data, _) => 'Loaded: $data',
  ///   onError: (err, prev) => 'Error: $err',
  /// );
  /// ```
  R fold<R>({
    required R Function() onInitial,
    required R Function(T? previousData) onLoading,
    required R Function(T data, DateTime updatedAt) onSuccess,
    required R Function(Object error, StackTrace? stackTrace, T? previousData)
        onError,
  }) {
    return switch (this) {
      Initial() => onInitial(),
      Loading(:final previousData) => onLoading(previousData),
      Success(:final data, :final updatedAt) => onSuccess(data, updatedAt),
      Failure(:final error, :final stackTrace, :final previousData) =>
        onError(error, stackTrace, previousData),
    };
  }

  /// Converts state to a simple status enum.
  ReqryStatus get status => switch (this) {
        Initial() => ReqryStatus.initial,
        Loading() => ReqryStatus.loading,
        Success() => ReqryStatus.success,
        Failure() => ReqryStatus.error,
      };
}

/// Simple status enum for cases where you don't need full state.
enum ReqryStatus {
  initial,
  loading,
  success,
  error;

  bool get isInitial => this == ReqryStatus.initial;
  bool get isLoading => this == ReqryStatus.loading;
  bool get isSuccess => this == ReqryStatus.success;
  bool get isError => this == ReqryStatus.error;
}

/// Extension for working with Future&lt;QoraState&lt;T&gt;&gt;.
extension QoraStateFutureExtensions<T> on Future<QoraState<T>> {
  /// Converts a Future&lt;QoraState&lt;T&gt;&gt; to Stream<QoraState<T&gt;&gt;.
  ///
  /// Emits Loading, then the final state.
  Stream<QoraState<T>> asStream({T? previousData}) async* {
    yield Loading<T>(previousData: previousData);
    yield await this;
  }

  /// Unwraps the data from Success state, or throws error.
  ///
  /// Throws the error from Error state.
  /// Throws [StateFailure] for Initial or Loading states.
  Future<T> unwrap() async {
    final state = await this;
    return switch (state) {
      Success(:final data) => data,
      Failure(:final error) => throw error,
      _ => throw StateError('Cannot unwrap non-Success state: $state'),
    };
  }
}

/// Extension for working with Stream&lt;QoraState&lt;T&gt;&gt;.
extension QoraStateStreamExtensions<T> on Stream<QoraState<T>> {
  /// Filters stream to only emit states with data.
  Stream<QoraState<T>> whereHasData() {
    return where((state) => state.hasData);
  }

  /// Filters stream to only emit Success states.
  Stream<Success<T>> whereSuccess() {
    return where((state) => state is Success<T>).cast<Success<T>>();
  }

  /// Filters stream to only emit Failure states.
  Stream<Failure<T>> whereError() {
    return where((state) => state is Failure<T>).cast<Failure<T>>();
  }

  /// Extracts just the data, emitting whenever state has data.
  ///
  /// Emits null for states without data (Initial, Loading without previousData).
  Stream<T?> dataOrNull() {
    return map((state) => state.dataOrNull);
  }

  /// Extracts just the data, skipping states without data.
  ///
  /// Only emits when state has data (Success, Loading/Error with previousData).
  Stream<T> data() {
    return map((state) => state.dataOrNull)
        .where((data) => data != null)
        .cast<T>();
  }

  /// Maps the data type while preserving state structure.
  Stream<QoraState<R>> mapData<R>(R Function(T data) transform) {
    return map((state) => state.map(transform));
  }

  /// Debounces Loading states while letting other states through immediately.
  ///
  /// Useful to prevent flickering spinners on fast requests.
  ///
  /// Example:
  /// ```dart
  /// stream.debounceLoading(Duration(milliseconds: 300))
  /// ```
  Stream<QoraState<T>> debounceLoading(Duration duration) async* {
    await for (final state in this) {
      if (state is Loading) {
        // Wait before emitting Loading
        await Future.delayed(duration, () {});
        yield state;
      } else {
        // Immediately emit non-Loading states
        yield state;
      }
    }
  }
}

/// Utility for handling multiple states.
class QoraStateUtils {
  QoraStateUtils._();

  /// Combines multiple states into a single state.
  ///
  /// Result is Success only if ALL are Success.
  /// Result is Loading if ANY is Loading.
  /// Result is Failure if ANY is Failure (priority over Loading).
  /// Otherwise Initial.
  static QoraState<List<T>> combineList<T>(List<QoraState<T>> states) {
    if (states.isEmpty) return Success(data: [], updatedAt: DateTime.now());

    // Check for errors first
    for (final state in states) {
      if (state is Failure<T>) {
        return Failure(error: state.error, stackTrace: state.stackTrace);
      }
    }

    // Check for loading
    for (final state in states) {
      if (state is Loading<T>) {
        return Loading<List<T>>();
      }
    }

    // Check if all success
    final allSuccess = states.every((s) => s is Success);
    if (allSuccess) {
      final data = states.map((s) => (s as Success<T>).data).toList();
      return Success(data: data, updatedAt: DateTime.now());
    }

    // Otherwise initial
    return Initial<List<T>>();
  }

  /// Combines exactly 2 states.
  static QoraState<(T1, T2)> combine2<T1, T2>(
    QoraState<T1> state1,
    QoraState<T2> state2,
  ) {
    if (state1 is Success<T1> && state2 is Success<T2>) {
      return Success(
        data: (state1.data, state2.data),
        updatedAt: DateTime.now(),
      );
    }

    if (state1 is Failure<T1>) {
      return Failure(error: state1.error, stackTrace: state1.stackTrace);
    }
    if (state2 is Failure<T2>) {
      return Failure(error: state2.error, stackTrace: state2.stackTrace);
    }

    if (state1 is Loading || state2 is Loading) {
      return Loading<(T1, T2)>();
    }

    return Initial<(T1, T2)>();
  }

  /// Combines exactly 3 states.
  static QoraState<(T1, T2, T3)> combine3<T1, T2, T3>(
    QoraState<T1> state1,
    QoraState<T2> state2,
    QoraState<T3> state3,
  ) {
    if (state1 is Success<T1> &&
        state2 is Success<T2> &&
        state3 is Success<T3>) {
      return Success(
        data: (state1.data, state2.data, state3.data),
        updatedAt: DateTime.now(),
      );
    }

    if (state1 is Failure<T1>) {
      return Failure(error: state1.error, stackTrace: state1.stackTrace);
    }
    if (state2 is Failure<T2>) {
      return Failure(error: state2.error, stackTrace: state2.stackTrace);
    }
    if (state3 is Failure<T3>) {
      return Failure(error: state3.error, stackTrace: state3.stackTrace);
    }

    if (state1 is Loading || state2 is Loading || state3 is Loading) {
      return Loading<(T1, T2, T3)>();
    }

    return Initial<(T1, T2, T3)>();
  }
}

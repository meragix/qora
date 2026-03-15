/// Platform-agnostic abstraction over application lifecycle events.
///
/// [QoraClient] uses this interface to implement [QoraOptions.refetchOnWindowFocus]:
/// when the app transitions to [LifecycleState.resumed], stale queries observed
/// by active widgets are invalidated and revalidated in the background.
///
/// ## Implementations
///
/// | Class                      | Package          | Platform     |
/// |----------------------------|------------------|--------------|
/// | `FlutterLifecycleManager`  | `flutter_qora`   | Flutter      |
///
/// ## Custom implementation
///
/// For non-Flutter environments (server, CLI tests), implement this interface
/// directly:
///
/// ```dart
/// class MyLifecycleManager implements LifecycleManager {
///   final _controller = StreamController<LifecycleState>.broadcast();
///
///   @override
///   Stream<LifecycleState> get lifecycleStream => _controller.stream;
///
///   @override
///   LifecycleState get currentState => LifecycleState.active;
///
///   @override
///   void start() { /* subscribe to platform events */ }
///
///   @override
///   void dispose() => _controller.close();
/// }
/// ```
///
/// ## Wiring
///
/// Pass the manager to [QoraScope] — it calls [start] and wires the stream
/// into [QoraClient.attachLifecycleManager] automatically:
///
/// ```dart
/// QoraScope(
///   client: client,
///   lifecycleManager: FlutterLifecycleManager(),
///   child: MyApp(),
/// )
/// ```
abstract class LifecycleManager {
  /// A broadcast stream that emits a [LifecycleState] each time the
  /// application lifecycle changes.
  ///
  /// Subscribers receive updates as long as [start] has been called and
  /// [dispose] has not. The stream must support multiple concurrent listeners
  /// (broadcast semantics).
  Stream<LifecycleState> get lifecycleStream;

  /// The most recently observed lifecycle state.
  ///
  /// Returns a sensible default (typically [LifecycleState.active]) before
  /// [start] is called.
  LifecycleState get currentState;

  /// Begin observing platform lifecycle events and emitting them on
  /// [lifecycleStream].
  ///
  /// Called once by [QoraScope] during `initState`. Calling [start] more than
  /// once should be idempotent.
  void start();

  /// Stop observing lifecycle events and release all held resources.
  ///
  /// After [dispose], [lifecycleStream] may close and [start] must not be
  /// called again. Called by [QoraScope] during `dispose`.
  void dispose();
}

/// Represents a coarse-grained application lifecycle state.
///
/// Maps onto Flutter's [AppLifecycleState] for the Flutter implementation,
/// but is kept platform-agnostic so the core `qora` package has no Flutter
/// dependency.
///
/// [QoraClient] only acts on [resumed] — all other states are available for
/// custom [LifecycleManager] implementations that need finer control.
enum LifecycleState {
  /// The application is visible and responding to user input.
  ///
  /// Corresponds to Flutter's `AppLifecycleState.resumed`.
  active,

  /// The application is visible but not currently in focus (e.g. a system
  /// overlay is on top).
  ///
  /// Corresponds to Flutter's `AppLifecycleState.inactive`.
  inactive,

  /// The application is not visible (background or minimised).
  ///
  /// Corresponds to Flutter's `AppLifecycleState.paused`.
  paused,

  /// The application has returned to the foreground after being paused.
  ///
  /// [QoraClient.attachLifecycleManager] listens for this state and triggers
  /// [refetchOnWindowFocus] revalidation for all stale active queries.
  resumed,
}

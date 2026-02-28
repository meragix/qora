import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';

/// Domain use-case that exposes the live event stream from the Qora runtime.
///
/// [ObserveEventsUseCase] is the **entry point** through which UI controllers
/// and notifiers subscribe to real-time [QoraEvent]s without depending
/// directly on [VmServiceClient] or [EventRepository].
///
/// ## Usage
///
/// ```dart
/// final observe = ObserveEventsUseCase(repository);
/// final sub = observe().listen((event) {
///   switch (event) {
///     case QueryEvent q  => queriesNotifier.setQueries([...]);
///     case MutationEvent m => mutationsNotifier.add(m);
///     default => timelineNotifier.append(TimelineEventView(...));
///   }
/// });
/// // Cancel in dispose:
/// await sub.cancel();
/// ```
///
/// ## Lifecycle
///
/// The returned stream is **endless** — it mirrors [EventRepository.events]
/// which runs for the lifetime of the VM connection.  Subscribers **must**
/// cancel their [StreamSubscription] when the listening controller is
/// disposed, otherwise the callback is retained in memory until the DevTools
/// panel is closed.
///
/// ## Testability
///
/// Inject a fake [EventRepository] that exposes a `StreamController` to emit
/// canned events and verify downstream notifier state:
///
/// ```dart
/// final ctrl = StreamController<QoraEvent>();
/// final repo = FakeEventRepository(stream: ctrl.stream);
/// final useCase = ObserveEventsUseCase(repo);
/// ctrl.add(queryEvent);
/// ```
class ObserveEventsUseCase {
  /// Creates the use-case backed by [_repository].
  const ObserveEventsUseCase(this._repository);

  final EventRepository _repository;

  /// Returns the continuous broadcast stream of decoded [QoraEvent]s.
  ///
  /// Delegates directly to [EventRepository.events]; no buffering or
  /// transformation is applied here.  See individual event subtypes
  /// ([QueryEvent], [MutationEvent], [GenericQoraEvent]) for payload details.
  Stream<QoraEvent> call() => _repository.events;
}

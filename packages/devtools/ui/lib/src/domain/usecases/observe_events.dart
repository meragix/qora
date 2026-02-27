import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';

/// Domain use-case that exposes the live stream of runtime events.
class ObserveEventsUseCase {
  final EventRepository _repository;

  /// Creates the use-case.
  const ObserveEventsUseCase(this._repository);

  /// Returns an endless stream of Qora events.
  Stream<QoraEvent> call() => _repository.events;
}

import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';

/// Domain use-case that triggers an immediate re-fetch of a query from the
/// DevTools UI.
///
/// Encapsulates the [RefetchCommand] dispatch logic so that UI widgets and
/// controllers invoke a named, testable operation rather than constructing
/// protocol objects directly.
///
/// ## What happens end-to-end
///
/// ```
/// RefetchQueryUseCase.call('["todos"]')
///   → EventRepository.sendCommand(RefetchCommand(queryKey: '["todos"]'))
///   → ext.qora.refetch (callServiceExtension)
///   → QoraClient.fetchQuery(key, force: true)   [runtime side]
///   → QueryEvent pushed back via qora:event stream
/// ```
///
/// The resulting state change is observable via [ObserveEventsUseCase] —
/// no separate return value is required for the event.
///
/// ## Return value
///
/// Returns `true` if the runtime responded with `{'ok': true}`, `false`
/// otherwise (e.g. unknown key, runtime not ready).  The caller is
/// responsible for surfacing a failure to the user.
///
/// ## Refetch vs. invalidate
///
/// | Use-case              | Runtime action                         |
/// |-----------------------|----------------------------------------|
/// | [RefetchQueryUseCase] | Immediate network request              |
/// | `InvalidateUseCase`   | Mark stale; re-fetched on next access  |
class RefetchQueryUseCase {
  /// Creates the use-case backed by [_repository].
  const RefetchQueryUseCase(this._repository);

  final EventRepository _repository;

  /// Sends a [RefetchCommand] for [queryKey] and returns whether the runtime
  /// confirmed the operation.
  ///
  /// [queryKey] must be the string-serialised `QoraKey` as emitted in
  /// [QueryEvent.queryKey].
  Future<bool> call(String queryKey) async {
    final response = await _repository.sendCommand(
      RefetchCommand(queryKey: queryKey),
    );
    return response['ok'] == true;
  }
}

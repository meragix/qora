import 'package:qora_devtools_shared/qora_devtools_shared.dart';
import 'package:qora_devtools_ui/src/domain/repositories/event_repository.dart';

/// Domain use-case that requests query refetch from the runtime bridge.
class RefetchQueryUseCase {
  final EventRepository _repository;

  /// Creates the use-case.
  const RefetchQueryUseCase(this._repository);

  /// Executes a refetch for [queryKey].
  Future<bool> call(String queryKey) async {
    final response = await _repository.sendCommand(
      RefetchCommand(queryKey: queryKey),
    );
    return response['ok'] == true;
  }
}

import 'qora_command.dart';

/// DevTools → runtime command that marks a cache entry as stale (lazy
/// invalidation).
///
/// ## Trigger
///
/// Sent by the DevTools UI when the developer taps the **"Invalidate"**
/// action on a query row in the Queries tab.  Delivered through
/// `callServiceExtension` on [QoraExtensionMethods.invalidate]
/// (`ext.qora.invalidate`).
///
/// ## Runtime behaviour
///
/// The extension handler calls `QoraClient.invalidateQuery(key)`, which sets
/// the cache entry's stale flag without issuing a network request.  The next
/// `fetchQuery` or `QoraBuilder` mount for that key will trigger a real
/// network call.
///
/// This is the **non-destructive** alternative to [RefetchCommand]: existing
/// data remains accessible to the app during the stale window, preventing
/// loading-flash regressions in production UIs.
///
/// ## Refetch vs. invalidate
///
/// | Command            | What happens at runtime                             |
/// |--------------------|-----------------------------------------------------|
/// | [RefetchCommand]   | Immediately fires a network request.                |
/// | [InvalidateCommand]| Marks the entry stale; refetch happens on next use. |
///
/// ## Key serialisation
///
/// [queryKey] must be the **string-serialised** form of the `QoraKey`.
/// See [RefetchCommand.queryKey] for details.
final class InvalidateCommand extends QoraCommand {
  /// String-serialised `QoraKey` identifying the cache entry to invalidate.
  ///
  /// Matches the `queryKey` field emitted in [QueryEvent].
  final String queryKey;

  /// Creates an invalidation command targeting [queryKey].
  const InvalidateCommand({required this.queryKey});

  @override
  String get method => 'invalidate';

  @override
  Map<String, String> get params => <String, String>{'queryKey': queryKey};
}

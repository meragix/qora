import 'qora_command.dart';

/// DevTools → runtime command that forces an immediate re-fetch of a query.
///
/// ## Trigger
///
/// Sent by the DevTools UI when the developer taps the **"Refetch"** action
/// on a query row in the Queries tab.  The UI serialises this command via
/// [CommandCodec] and delivers it through `callServiceExtension` on
/// [QoraExtensionMethods.refetch] (`ext.qora.refetch`).
///
/// ## Runtime behaviour
///
/// The extension handler resolves [queryKey] in the `QoraClient` cache and
/// calls `fetchQuery` with `force: true`, bypassing the stale-time check.
/// The resulting state changes flow back to the DevTools UI as `qora:event`
/// push events — no separate response payload is needed.
///
/// ## Refetch vs. invalidate
///
/// | Command            | What happens at runtime                             |
/// |--------------------|-----------------------------------------------------|
/// | [RefetchCommand]   | Immediately fires a network request.                |
/// | [InvalidateCommand]| Marks the entry stale; refetch happens on next use. |
///
/// Use [InvalidateCommand] when you want to schedule a refresh without
/// triggering an immediate network call.
///
/// ## Key serialisation
///
/// [queryKey] must be the **string-serialised** form of the `QoraKey` (e.g.
/// `'["todos"]'`).  The runtime handler deserialises it using the same
/// normalisation logic as `QoraClient`.
final class RefetchCommand extends QoraCommand {
  /// String-serialised `QoraKey` identifying the query to refetch.
  ///
  /// Matches the `queryKey` field emitted in [QueryEvent] so the UI can
  /// target the exact cache entry shown in the Queries tab.
  final String queryKey;

  /// Creates a refetch command targeting [queryKey].
  const RefetchCommand({required this.queryKey});

  @override
  String get method => 'refetch';

  @override
  Map<String, String> get params => <String, String>{'queryKey': queryKey};
}

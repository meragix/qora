/// Base command contract sent by the DevTools UI to the runtime bridge.
///
/// Commands travel in the **UI → App** direction via
/// `VmServiceClient.sendCommand`, which forwards them as:
/// ```
/// vmService.callServiceExtension(
///   'ext.qora.<method>',
///   args: command.params,
/// );
/// ```
///
/// ## Why `Map<String, String>` params?
///
/// VM service extension handlers receive query arguments as
/// `Map<String, String>` — an SDK constraint. All parameter values must
/// therefore be serialised to strings by the command and parsed back to
/// their native types by the handler.
///
/// ## Implementing a new command
///
/// ```dart
/// final class PauseTrackerCommand extends QoraCommand {
///   const PauseTrackerCommand();
///
///   @override
///   String get method => 'pauseTracker'; // matches QoraExtensionMethods
///
///   @override
///   Map<String, String> get params => const {};
/// }
/// ```
///
/// Then add `'ext.qora.pauseTracker'` to [QoraExtensionMethods], add a
/// `case 'pauseTracker':` branch to [CommandCodec.decode], and register
/// the handler in `ExtensionRegistrar`.
abstract class QoraCommand {
  /// Creates a command descriptor.
  const QoraCommand();

  /// Method suffix used when composing the full extension name.
  ///
  /// Example: `'refetch'` → dispatched as `'ext.qora.refetch'`.
  ///
  /// Must match the constant in [QoraExtensionMethods] and the routing
  /// case in [CommandCodec.decode].
  String get method;

  /// Command parameters serialised as VM service query args.
  ///
  /// All values must be strings. Parse them to the correct types in the
  /// handler (e.g. `int.parse(params['chunkIndex']!)`).
  Map<String, String> get params;

  /// JSON-safe representation for logging and testing purposes.
  Map<String, Object?> toJson() => <String, Object?>{
        'method': method,
        'params': params,
      };
}

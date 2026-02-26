/// Base command contract sent by the DevTools UI to the runtime bridge.
///
/// Commands are intentionally stringly-typed on params because VM service
/// extension handlers receive query arguments as `Map<String, String>`.
abstract class QoraCommand {
  /// Creates a command descriptor.
  const QoraCommand();

  /// Method suffix used when composing the full extension name.
  ///
  /// Example:
  /// - `refetch` -> `ext.qora.refetch`
  String get method;

  /// Command parameters serialized as query args.
  Map<String, String> get params;

  /// JSON-safe representation.
  Map<String, Object?> toJson() => <String, Object?>{
        'method': method,
        'params': params,
      };
}

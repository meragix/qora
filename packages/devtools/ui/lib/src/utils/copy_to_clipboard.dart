import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/services.dart';

/// Copies [data] to the clipboard.
///
/// When the extension is running embedded inside VS Code or IntelliJ,
/// `Clipboard.setData` does not work due to a known IDE WebView bug
/// (dart-code/Dart-Code#4540). In that case the copy request is delegated
/// to the parent DevTools frame via `postMessage` using
/// `extensionManager.copyToClipboard`, which also surfaces a success
/// notification inside the IDE.
///
/// When running standalone (e.g. in a browser DevTools tab),
/// `Clipboard.setData` is used directly.
Future<void> copyToClipboard(
  String data, {
  String successMessage = 'Copied to clipboard',
}) async {
  try {
    await Clipboard.setData(ClipboardData(text: data));
  } catch (_) {
    // Fallback: delegate to the parent DevTools frame. Works in VS Code and
    // IntelliJ where the WebView clipboard API is restricted.
    extensionManager.copyToClipboard(data, successMessage: successMessage);
  }
}
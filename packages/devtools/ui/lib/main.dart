import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/qora_devtools_app.dart';

/// Entry point for the Flutter DevTools extension.
void main() {
  runApp(const DevToolsExtension(child: QoraDevToolsApp()));
}

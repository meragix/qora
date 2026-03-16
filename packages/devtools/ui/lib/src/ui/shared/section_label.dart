import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_typography.dart';

/// Uppercase subtle section label used by inspector blocks.
class SectionLabel extends StatelessWidget {
  /// Creates section label.
  const SectionLabel({
    super.key,
    required this.text,
  });

  /// Label text (will be displayed as-is — callers should pass uppercase).
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: DevtoolsTypography.tab);
  }
}

import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/shared/section_label.dart';

/// Reusable wrapper for one inspector section.
class InspectorSection extends StatelessWidget {
  /// Creates an inspector section.
  const InspectorSection({
    super.key,
    required this.title,
    required this.child,
  });

  /// Section heading.
  final String title;

  /// Section content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionLabel(text: title),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

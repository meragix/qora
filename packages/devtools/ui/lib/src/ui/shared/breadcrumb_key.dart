import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/ui/theme/devtools_typography.dart';

/// Compact breadcrumb-like key label used in list rows.
class BreadcrumbKey extends StatelessWidget {
  /// Creates breadcrumb key widget.
  const BreadcrumbKey({
    super.key,
    required this.value,
  });

  /// Breadcrumb text.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DevtoolsTypography.queryKey,
    );
  }
}

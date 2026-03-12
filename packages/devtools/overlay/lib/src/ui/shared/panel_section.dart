import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

class PanelSection extends StatelessWidget {
  final String label;

  const PanelSection({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: 12.edgeInsetsH,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DevtoolsColors.border)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: DevtoolsTypography.tab,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qora_devtools_overlay/src/ui/shared/num_ext.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

class QuerySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const QuerySearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DevtoolsSpacing.searchBarHeight,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: DevtoolsTypography.body,
        decoration: InputDecoration(
          filled: true,
          fillColor: DevtoolsColors.inputBackground,
          hintText: 'Search queries...',
          hintStyle: const TextStyle(color: DevtoolsColors.textMuted),
          prefixIcon: const Icon(LucideIcons.search),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          isDense: true,
          contentPadding: DevtoolsSpacing.searchBarPadding.edgeInsetsA,
        ),
      ),
    );
  }
}

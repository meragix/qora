import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_typography.dart';

/// Renders a JSON-encoded query key as a horizontal breadcrumb of pills.
///
/// Each element of the key list becomes its own monospaced pill, separated by
/// a muted `›` chevron. Handles all key shapes produced by [QoraTracker]:
///
/// - List key `'["users",1]'` → `users › 1`
/// - Map segment `'["todos",{"status":"open"}]'` → `todos › {"status":"open"}`
/// - Plain string (non-JSON fallback) → single pill
/// - Empty string → [SizedBox.shrink]
class BreadcrumbKey extends StatelessWidget {
  final String queryKey;
  final TextStyle? style;

  const BreadcrumbKey({super.key, required this.queryKey, this.style});

  List<String> _segments() {
    if (queryKey.isEmpty) return const [];
    try {
      final decoded = jsonDecode(queryKey);
      if (decoded is List) {
        return decoded.map<String>((part) {
          if (part is Map || part is List) return jsonEncode(part);
          return part.toString();
        }).toList();
      }
      return [decoded.toString()];
    } catch (_) {
      return [queryKey];
    }
  }

  @override
  Widget build(BuildContext context) {
    final segs = _segments();
    if (segs.isEmpty) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 4,
      children: [
        for (var i = 0; i < segs.length; i++) ...[
          _Pill(text: segs[i], style: style),
          if (i < segs.length - 1)
            const Text(
              '›',
              style: TextStyle(
                color: DevtoolsColors.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _Pill({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: DevtoolsColors.zinc800,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: DevtoolsTypography.queryKey.copyWith(fontSize: 11).merge(style),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// DevTools elevation shadow tokens.
class DevtoolsShadows {
  DevtoolsShadows._();

  static List<BoxShadow> get panel => [
        BoxShadow(
          color: Colors.black.withValues(alpha: .4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get fab => [
        BoxShadow(
          color: Colors.black.withValues(alpha: .2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
}

import 'package:flutter/material.dart';

class DevtoolsShadows {
  const DevtoolsShadows();

  List<BoxShadow> get panel => [
        BoxShadow(
          color: Colors.black.withValues(alpha: .4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ];
}

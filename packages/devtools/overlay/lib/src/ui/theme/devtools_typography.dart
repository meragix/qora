import 'package:flutter/material.dart';
import 'devtools_colors.dart';

/// DevTools typography tokens.
///
/// Avoid raw TextStyle usage in widgets.
/// Use these predefined styles instead.
class DevtoolsTypography {
  DevtoolsTypography._();

  // ---------------------------------------------------------------------------
  // Base font sizes
  // ---------------------------------------------------------------------------

  static const double xs = 11;
  static const double sm = 12;
  static const double md = 13;
  static const double lg = 14;

  // ---------------------------------------------------------------------------
  // Primary text styles
  // ---------------------------------------------------------------------------

  static const TextStyle body = TextStyle(
    fontSize: md,
    color: DevtoolsColors.textPrimary,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: md,
    color: DevtoolsColors.textMuted,
  );

  static const TextStyle small = TextStyle(
    fontSize: sm,
    color: DevtoolsColors.textDisabled,
  );

  static const TextStyle smallMuted = TextStyle(
    fontSize: sm,
    color: DevtoolsColors.textMuted,
  );

  // ---------------------------------------------------------------------------
  // Headings
  // ---------------------------------------------------------------------------

  static const TextStyle sectionTitle = TextStyle(
    fontSize: lg,
    fontWeight: FontWeight.w600,
    color: DevtoolsColors.textPrimary,
  );

  static const TextStyle tab = TextStyle(
    fontSize: md,
    fontWeight: FontWeight.w500,
    color: DevtoolsColors.textSecondary,
  );

  // ---------------------------------------------------------------------------
  // Query specific
  // ---------------------------------------------------------------------------

  static const TextStyle queryKey = TextStyle(
    fontSize: md,
    fontFamily: 'monospace',
    fontWeight: FontWeight.w600,
    color: DevtoolsColors.textPrimary,
  );

  static const TextStyle queryMeta = TextStyle(
    fontSize: sm,
    color: DevtoolsColors.textDisabled,
  );

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  static const TextStyle status = TextStyle(
    fontSize: sm,
    fontWeight: FontWeight.w500,
  );

  // ---------------------------------------------------------------------------
  // Code / JSON viewer
  // ---------------------------------------------------------------------------

  static const TextStyle code = TextStyle(
    fontSize: sm,
    fontFamily: 'monospace',
    color: DevtoolsColors.textPrimary,
  );
}

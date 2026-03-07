import 'package:flutter/material.dart';

/// DevTools design tokens
/// Inspired by Tailwind Zinc palette.
///
/// IMPORTANT:
/// UI widgets should ONLY use semantic tokens
/// (panelBackground, textPrimary, statusFresh, etc)
/// and never raw colors.
class DevtoolsColors {
  DevtoolsColors._();

  // ---------------------------------------------------------------------------
  // Base Palette (Tailwind Zinc)
  // ---------------------------------------------------------------------------

  static const zinc50 = Color(0xFFFAFAFA);
  static const zinc100 = Color(0xFFF4F4F5);
  static const zinc200 = Color(0xFFE4E4E7);
  static const zinc300 = Color(0xFFD4D4D8);
  static const zinc400 = Color(0xFFA1A1AA);
  static const zinc500 = Color(0xFF71717A);
  static const zinc600 = Color(0xFF52525B);
  static const zinc700 = Color(0xFF3F3F46);
  static const zinc800 = Color(0xFF27272A);
  static const zinc900 = Color(0xFF18181B);
  static const zinc950 = Color(0xFF09090b);

  // Status palette (Tailwind)
  static const green400 = Color(0xFF4ADE80);
  static const yellow400 = Color(0xFFFACC15);
  static const blue400 = Color(0xFF60A5FA);
  static const red400 = Color(0xFFF87171);
  static const orange400 = Color(0xFFFB923C);
  static const cyan400 = Color(0xFF22D3EE);

  // ---------------------------------------------------------------------------
  // Panel Layout
  // ---------------------------------------------------------------------------

  /// Main background color (body)
  static const background = zinc950;

  /// Main DevTools panel background
  static const panelBackground = zinc900;

  /// Secondary background (tabs / headers)
  static const panelSecondaryBackground = zinc800;

  /// Row hover background
  // static const rowHover = Color(0xFF27272A);
  static const rowHover = zinc800;

  /// Active / selected query
  // static const rowSelected = Color(0xFF3F3F46);
  static const rowSelected = zinc800;

  /// Divider lines
  static const divider = zinc700;

  /// Generic borders
  static const border = zinc700;

  // ---------------------------------------------------------------------------
  // Accent Colors
  // ---------------------------------------------------------------------------

  static const accent = Color(0xFFc084fc); // purple-400

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Primary readable text
  static const textPrimary = zinc200;

  /// Secondary text (metadata)
  static const textSecondary = zinc300;

  /// Muted text
  static const textMuted = zinc400;

  /// Disabled text
  static const textDisabled = zinc500;

  // ---------------------------------------------------------------------------
  // Inputs
  // ---------------------------------------------------------------------------

  static const inputBackground = zinc900;
  static const inputBorder = zinc700;
  static const inputText = zinc200;
  static const inputPlaceholder = zinc500;

  // ---------------------------------------------------------------------------
  // Query Status Colors
  // ---------------------------------------------------------------------------

  /// Query is fresh
  static const statusFresh = green400;

  /// Query is stale
  static const statusStale = yellow400;

  /// Query is fetching
  static const statusFetching = blue400;

  /// Query failed
  static const statusError = red400;

  /// Neutral / idle
  static const statusIdle = zinc400;

  // ---------------------------------------------------------------------------
  // Devtools Specific
  // ---------------------------------------------------------------------------

  /// JSON viewer background
  static const jsonBackground = zinc900;

  /// Code blocks
  static const codeBackground = zinc800;

  /// Highlighted row
  static const highlight = zinc700;

  // ---------------------------------------------------------------------------
  // Scrollbars
  // ---------------------------------------------------------------------------

  static const scrollbarThumb = zinc600;
  static const scrollbarTrack = zinc800;

  // ---------------------------------------------------------------------------
  // Buttons
  // ---------------------------------------------------------------------------

  static const buttonBackground = zinc800;
  static const buttonHover = zinc700;
  static const buttonText = zinc200;
}

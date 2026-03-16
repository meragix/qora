import 'package:flutter/material.dart';

/// DevTools design tokens — Tailwind Zinc palette.
///
/// Widgets must use semantic tokens only (e.g. [panelBackground], [textPrimary]).
/// Never reference raw zinc/color values directly in widget code.
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
  static const zinc950 = Color(0xFF09090B);

  // Accent palette (Tailwind)
  static const green400 = Color(0xFF4ADE80);
  static const yellow400 = Color(0xFFFACC15);
  static const blue400 = Color(0xFF60A5FA);
  static const red400 = Color(0xFFF87171);
  static const orange400 = Color(0xFFFB923C);
  static const cyan400 = Color(0xFF22D3EE);
  static const amber400 = Color(0xFFFBBF24);
  static const emerald400 = Color(0xFF34D399);
  static const purple400 = Color(0xFFC084FC);

  // ---------------------------------------------------------------------------
  // Semantic tokens
  // ---------------------------------------------------------------------------

  static const background = zinc950;
  static const panelBackground = zinc900;
  static const panelSecondaryBackground = zinc800;
  static const rowHover = zinc800;
  static const rowSelected = zinc800;
  static const divider = zinc700;
  static const border = zinc700;

  static const accent = purple400;

  // Text
  static const textPrimary = zinc200;
  static const textSecondary = zinc300;
  static const textMuted = zinc400;
  static const textDisabled = zinc500;

  // Inputs
  static const inputBackground = zinc900;
  static const inputBorder = zinc700;
  static const inputText = zinc200;
  static const inputPlaceholder = zinc500;

  // Query status
  static const statusFresh = green400;
  static const statusStale = yellow400;
  static const statusFetching = blue400;
  static const statusError = red400;
  static const statusIdle = zinc400;

  // Code / JSON
  static const jsonBackground = zinc900;
  static const codeBackground = zinc800;
  static const highlight = zinc700;

  // Scrollbars
  static const scrollbarThumb = zinc600;
  static const scrollbarTrack = zinc800;

  // Buttons
  static const buttonBackground = zinc800;
  static const buttonHover = zinc700;
  static const buttonText = zinc200;
}

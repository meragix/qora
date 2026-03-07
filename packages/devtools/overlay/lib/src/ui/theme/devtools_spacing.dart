/// DevTools spacing scale.
///
/// Based on a 4px grid system.
/// Widgets should use these tokens instead of raw EdgeInsets / sizes.
class DevtoolsSpacing {
  DevtoolsSpacing._();

  // Base units
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  // Layout paddings
  static const double panelPadding = 12;
  static const double panelHeaderHeight = 44;
  static const double sectionPadding = 8;

  // Row sizes
  static const double rowHeight = 36;
  static const double rowPaddingHorizontal = 12;
  static const double rowPaddingVertical = 6;

  // Icon spacing
  static const double iconGap = 8;

  // Search bar
  static const double searchBarHeight = 38;
  static const double searchBarPadding = 12;

  // Tabs
  static const double tabHeight = 36;

  // Borders
  static const double borderWidth = 1;

  // Scrollbars
  static const double scrollbarWidth = 6;
}

import 'package:flutter/material.dart';
import 'devtools_colors.dart';
import 'devtools_spacing.dart';

/// Builds the canonical Qora DevTools [ThemeData].
///
/// Maps the Zinc design tokens onto Material 3 color-scheme slots so that
/// standard Flutter widgets (Scaffold, AppBar, TabBar, TextField, etc.) pick
/// up the correct dark-theme colours automatically.
class DevtoolsTheme {
  DevtoolsTheme._();

  /// Dark theme — the only supported theme for the DevTools extension.
  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      // Brand
      primary: DevtoolsColors.accent,
      onPrimary: DevtoolsColors.zinc950,
      primaryContainer: Color(0xFF3B1F5E), // purple-950-ish
      onPrimaryContainer: DevtoolsColors.purple400,
      // Secondary
      secondary: DevtoolsColors.zinc400,
      onSecondary: DevtoolsColors.zinc950,
      secondaryContainer: DevtoolsColors.zinc700,
      onSecondaryContainer: DevtoolsColors.zinc200,
      // Error
      error: DevtoolsColors.red400,
      onError: DevtoolsColors.zinc950,
      errorContainer: Color(0xFF3B0F0F),
      onErrorContainer: DevtoolsColors.red400,
      // Surfaces
      surface: DevtoolsColors.panelBackground,
      onSurface: DevtoolsColors.textPrimary,
      surfaceContainerHighest: DevtoolsColors.panelSecondaryBackground,
      onSurfaceVariant: DevtoolsColors.textMuted,
      // Outline
      outline: DevtoolsColors.border,
      outlineVariant: DevtoolsColors.zinc700,
      // Inverse
      inverseSurface: DevtoolsColors.zinc200,
      onInverseSurface: DevtoolsColors.zinc950,
      inversePrimary: DevtoolsColors.accent,
      // Scrim / shadow
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: DevtoolsColors.background,
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: DevtoolsColors.panelBackground,
        foregroundColor: DevtoolsColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DevtoolsColors.textPrimary,
        ),
      ),
      // TabBar
      tabBarTheme: const TabBarThemeData(
        labelColor: DevtoolsColors.accent,
        unselectedLabelColor: DevtoolsColors.textMuted,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: DevtoolsColors.accent,
            width: 2,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: DevtoolsColors.divider,
      ),
      // Divider
      dividerTheme: const DividerThemeData(
        color: DevtoolsColors.divider,
        thickness: 1,
        space: 1,
      ),
      // Input / TextField
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DevtoolsColors.inputBackground,
        hintStyle: const TextStyle(
          color: DevtoolsColors.inputPlaceholder,
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DevtoolsSpacing.searchBarPadding,
          vertical: DevtoolsSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: DevtoolsColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: DevtoolsColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: DevtoolsColors.accent, width: 1.5),
        ),
      ),
      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DevtoolsColors.textMuted,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DevtoolsColors.textSecondary,
          side: const BorderSide(color: DevtoolsColors.border),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DevtoolsColors.buttonBackground,
          foregroundColor: DevtoolsColors.buttonText,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      // Icon
      iconTheme: const IconThemeData(
        color: DevtoolsColors.textMuted,
        size: 16,
      ),
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: DevtoolsColors.panelSecondaryBackground,
        labelStyle: const TextStyle(
          fontSize: 11,
          color: DevtoolsColors.textSecondary,
        ),
        side: const BorderSide(color: DevtoolsColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      // Scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(DevtoolsColors.scrollbarThumb),
        trackColor: WidgetStateProperty.all(DevtoolsColors.scrollbarTrack),
        thickness: WidgetStateProperty.all(DevtoolsSpacing.scrollbarWidth),
        radius: const Radius.circular(3),
      ),
      // DataTable
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(
          DevtoolsColors.panelSecondaryBackground,
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return DevtoolsColors.rowHover;
          }
          return Colors.transparent;
        }),
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: DevtoolsColors.textMuted,
        ),
        dataTextStyle: const TextStyle(
          fontSize: 12,
          color: DevtoolsColors.textSecondary,
        ),
        dividerThickness: 1,
        columnSpacing: 16,
      ),
      // ExpansionTile
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: DevtoolsColors.textMuted,
        collapsedIconColor: DevtoolsColors.textMuted,
        textColor: DevtoolsColors.textPrimary,
        collapsedTextColor: DevtoolsColors.textPrimary,
      ),
      // ListTile
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: DevtoolsColors.textPrimary,
        iconColor: DevtoolsColors.textMuted,
        dense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: DevtoolsSpacing.rowPaddingHorizontal,
          vertical: 0,
        ),
      ),
      // General text
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 13, color: DevtoolsColors.textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: DevtoolsColors.textMuted),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: DevtoolsColors.textMuted,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: DevtoolsColors.textSecondary,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: DevtoolsColors.textPrimary,
        ),
      ),
    );
  }
}

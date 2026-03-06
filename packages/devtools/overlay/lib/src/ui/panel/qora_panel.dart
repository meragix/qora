import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/panel/panel_header.dart';
import 'package:qora_devtools_overlay/src/ui/panel/panel_tab_bar.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';

/// The main DevTools panel — a dark sheet anchored to the bottom of the screen.
///
/// Contains [PanelHeader] (close / expand controls) and [PanelTabBar]
/// (QUERIES / MUTATIONS tabs). Mounted above the app content by [QoraInspector].
class QoraPanel extends StatelessWidget {
  final VoidCallback onClose;

  const QoraPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.6;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: height,
      child: Material(
        color: DevtoolsColors.panelBackground,
        elevation: 8,
        child: Theme(
          data: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: DevtoolsColors.background,
            colorScheme: ColorScheme.dark(
              primary: DevtoolsColors.accent,
              onPrimary: Colors.white,
              surface: DevtoolsColors.panelBackground,
              onSurface: DevtoolsColors.textPrimary,
              error: DevtoolsColors.statusError,
              onError: Colors.white,
            ),
            disabledColor: DevtoolsColors.divider,
            cardColor: DevtoolsColors.panelBackground,
            tabBarTheme: TabBarThemeData(
              labelColor: DevtoolsColors.textPrimary,
              unselectedLabelColor: DevtoolsColors.textMuted,
              indicatorColor: DevtoolsColors.accent,
              dividerColor: DevtoolsColors.border,
            ),
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(DevtoolsColors.border),
              trackColor: WidgetStateProperty.all(DevtoolsColors.background),
            ),
            dividerTheme: const DividerThemeData(
              color: DevtoolsColors.border,
              thickness: 1,
            ),
            iconTheme: IconThemeData(
              color: DevtoolsColors.textMuted,
            ),
          ),
          child: Localizations(
            locale: const Locale('en', 'US'),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
            ],
            child: Column(
              children: [
                PanelHeader(onClose: onClose),
                const Divider(height: 1, thickness: 1, color: Color(0xFF1E293B)),
                const Expanded(child: PanelTabBar()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

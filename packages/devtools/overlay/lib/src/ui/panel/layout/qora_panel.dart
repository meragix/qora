import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/panel/layout/panel_header.dart';
import 'package:qora_devtools_overlay/src/ui/panel/layout/panel_body.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_spacing.dart';

/// The main DevTools panel — a dark sheet anchored to the bottom of the screen.
///
/// The expand button in [PanelHeader] toggles between 60 % height (normal)
/// and 95 % height (expanded), animated with [AnimatedPositioned].
class QoraPanel extends StatefulWidget {
  final VoidCallback onClose;

  const QoraPanel({super.key, required this.onClose});

  @override
  State<QoraPanel> createState() => _QoraPanelState();
}

class _QoraPanelState extends State<QoraPanel> {
  bool _expanded = false;

  /// Stable [OverlayEntry] held for the lifetime of this widget.
  ///
  /// Created once in [initState] so that [markNeedsBuild] can be called
  /// when [_expanded] changes without remounting the [Overlay].
  late final OverlayEntry _contentEntry;

  @override
  void initState() {
    super.initState();
    _contentEntry = OverlayEntry(builder: _buildContent);
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          onClose: widget.onClose,
          isExpanded: _expanded,
          onToggleExpand: _toggleExpand,
        ),
        const Divider(height: 1),
        const Expanded(child: PanelBody()),
      ],
    );
  }

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
    // Sync the OverlayEntry's content with the new _expanded value.
    _contentEntry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = screenHeight * (_expanded ? 0.95 : 0.60);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      bottom: 0,
      left: 0,
      right: 0,
      height: height,
      child: Material(
        color: DevtoolsColors.panelBackground,
        elevation: DevtoolsSpacing.sm,
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
            ],
            // Overlay provides the ancestor required by TextField (and other
            // focus-aware widgets) for selection handles and autocorrect UI.
            child: Overlay(
              initialEntries: [_contentEntry],
            ),
          ),
        ),
      ),
    );
  }
}

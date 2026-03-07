import 'package:flutter/material.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';

const double kMobileBreakpoint = 600.0;

// ── Contraintes des colonnes ──────────────────────────────────────────────────

const double _kListMinWidth = 180.0;
const double _kListMaxWidth = 400.0;
const double _kListDefaultWidth = 260.0;

const double _kSecondaryMinWidth = 200.0;
const double _kSecondaryMaxWidth = 500.0;
const double _kSecondaryDefaultWidth = 340.0;

const double _kCenterMinWidth = 200.0;

const double _kDividerHitWidth = 5.0;

enum PanelScreen { list, inspector, secondary }

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

/// Responsive three-column layout with **draggable dividers** on desktop and a
/// slide-animated single-column stack on mobile.
///
/// ### Desktop — resizable split panels
///
/// ```
/// ┌──────────┬──────────────────────────┬───────────┐
/// │  Queries │        Inspector         │ Timeline  │
/// │  260 px  │        flexible          │  340 px   │
/// │ ←drag→   │                          │ ←drag→    │
/// └──────────┴──────────────────────────┴───────────┘
/// ```
///
/// * The **left** divider resizes the list column (`$_kListMinWidth` –
///   `$_kListMaxWidth`).
/// * The **right** divider resizes the secondary column
///   (`$_kSecondaryMinWidth` – `$_kSecondaryMaxWidth`).
/// * The center column takes all remaining space (min `$_kCenterMinWidth`).
///
/// ### Mobile — swipe stack
///
/// Three full-screen pages driven by [currentScreen] / [onNavigate], each
/// animated with a directional [SlideTransition].
///
/// ### Parameters
///
/// | Parameter | Description |
/// |---|---|
/// | [listColumn] | Always-present left column (queries list). |
/// | [inspectorColumn] | Middle column; shown if non-null. |
/// | [secondaryColumn] | Right column; shown if non-null. |
/// | [currentScreen] | Active mobile screen (ignored on desktop). |
/// | [onNavigate] | Called when the user taps a mobile nav button. |
class PanelLayout extends StatefulWidget {
  final Widget listColumn;
  final Widget? inspectorColumn;
  final Widget? secondaryColumn;
  final PanelScreen currentScreen;
  final ValueChanged<PanelScreen> onNavigate;

  const PanelLayout({
    super.key,
    required this.listColumn,
    this.inspectorColumn,
    this.secondaryColumn,
    required this.currentScreen,
    required this.onNavigate,
  });

  @override
  State<PanelLayout> createState() => _PanelLayoutState();
}

class _PanelLayoutState extends State<PanelLayout> {
  double _listWidth = _kListDefaultWidth;
  double _secondaryWidth = _kSecondaryDefaultWidth;

  // ── Drag handlers ─────────────────────────────────────────────────────────

  /// Adjusts the list column width, clamped to its allowed range.
  void _onListDividerDrag(double delta) {
    setState(() {
      _listWidth = (_listWidth + delta).clamp(
        _kListMinWidth,
        _kListMaxWidth,
      );
    });
  }

  /// Adjusts the secondary column width (right-to-left semantics: dragging
  /// left widens it).
  void _onSecondaryDividerDrag(double delta) {
    setState(() {
      _secondaryWidth = (_secondaryWidth - delta).clamp(
        _kSecondaryMinWidth,
        _kSecondaryMaxWidth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < kMobileBreakpoint;

    if (isMobile) {
      return _MobileLayout(
        listColumn: widget.listColumn,
        inspectorColumn: widget.inspectorColumn,
        secondaryColumn: widget.secondaryColumn,
        currentScreen: widget.currentScreen,
        onNavigate: widget.onNavigate,
      );
    }

    return _DesktopLayout(
      listColumn: widget.listColumn,
      inspectorColumn: widget.inspectorColumn,
      secondaryColumn: widget.secondaryColumn,
      listWidth: _listWidth,
      secondaryWidth: _secondaryWidth,
      onListDividerDrag: _onListDividerDrag,
      onSecondaryDividerDrag: _onSecondaryDividerDrag,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop — split panels
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final Widget listColumn;
  final Widget? inspectorColumn;
  final Widget? secondaryColumn;
  final double listWidth;
  final double secondaryWidth;
  final ValueChanged<double> onListDividerDrag;
  final ValueChanged<double> onSecondaryDividerDrag;

  const _DesktopLayout({
    required this.listColumn,
    this.inspectorColumn,
    this.secondaryColumn,
    required this.listWidth,
    required this.secondaryWidth,
    required this.onListDividerDrag,
    required this.onSecondaryDividerDrag,
  });

  @override
  Widget build(BuildContext context) {
    final hasInspector = inspectorColumn != null;
    final hasSecondary = secondaryColumn != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard: ensure center column never collapses below its minimum.
        double effectiveSecondaryWidth = secondaryWidth;
        if (hasSecondary && hasInspector) {
          final dividers = _kDividerHitWidth * 2;
          final available = constraints.maxWidth - listWidth - dividers - _kCenterMinWidth;
          effectiveSecondaryWidth = effectiveSecondaryWidth.clamp(0.0, available.clamp(0.0, effectiveSecondaryWidth));
        }

        return Row(
          children: [
            // ── Col 1 — list ────────────────────────────────────────────────
            SizedBox(width: listWidth, child: listColumn),

            // ── Divider 1 ───────────────────────────────────────────────────
            if (hasInspector) _ResizeDivider(onDrag: onListDividerDrag),

            // ── Col 2 — inspector (flex) ────────────────────────────────────
            if (hasInspector)
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: _kCenterMinWidth),
                  child: inspectorColumn!,
                ),
              ),

            // ── Divider 2 ───────────────────────────────────────────────────
            if (hasInspector && hasSecondary) _ResizeDivider(onDrag: onSecondaryDividerDrag),

            // ── Col 3 — secondary ───────────────────────────────────────────
            if (hasSecondary)
              SizedBox(
                width: effectiveSecondaryWidth,
                child: secondaryColumn!,
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draggable divider
// ─────────────────────────────────────────────────────────────────────────────

/// A thin interactive handle that calls [onDrag] with the horizontal delta on
/// every drag update.
///
/// Uses [MouseRegion] to switch to [SystemMouseCursors.resizeColumn] on hover
/// and [HitTestBehavior.translucent] so the 5 px hit area doesn't block clicks
/// on adjacent widgets.
class _ResizeDivider extends StatefulWidget {
  final ValueChanged<double> onDrag;

  const _ResizeDivider({required this.onDrag});

  @override
  State<_ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<_ResizeDivider> {
  bool _hovered = false;
  bool _dragging = false;

  bool get _active => _hovered || _dragging;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _kDividerHitWidth,
          color: _active ? DevtoolsColors.accent.withValues(alpha: .6) : DevtoolsColors.border,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile — slide stack
// ─────────────────────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final Widget listColumn;
  final Widget? inspectorColumn;
  final Widget? secondaryColumn;
  final PanelScreen currentScreen;
  final ValueChanged<PanelScreen> onNavigate;

  const _MobileLayout({
    required this.listColumn,
    this.inspectorColumn,
    this.secondaryColumn,
    required this.currentScreen,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        final screenIndex = _indexOf(currentScreen);
        final childIndex = _indexFromKey(child.key);
        final goingForward = childIndex >= screenIndex;
        final begin = goingForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
        return SlideTransition(
          position: Tween(begin: begin, end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
      child: switch (currentScreen) {
        PanelScreen.list => KeyedSubtree(
            key: const ValueKey(PanelScreen.list),
            child: listColumn,
          ),
        PanelScreen.inspector => KeyedSubtree(
            key: const ValueKey(PanelScreen.inspector),
            child: Column(children: [
              _MobileNavBar(
                title: 'Inspector',
                onBack: () => onNavigate(PanelScreen.list),
                forwardLabel: secondaryColumn != null ? 'Timeline' : null,
                onForward: secondaryColumn != null ? () => onNavigate(PanelScreen.secondary) : null,
              ),
              Expanded(child: inspectorColumn ?? const SizedBox()),
            ]),
          ),
        PanelScreen.secondary => KeyedSubtree(
            key: const ValueKey(PanelScreen.secondary),
            child: Column(children: [
              _MobileNavBar(
                title: 'Timeline',
                onBack: () => onNavigate(PanelScreen.inspector),
              ),
              Expanded(child: secondaryColumn ?? const SizedBox()),
            ]),
          ),
      },
    );
  }

  static int _indexOf(PanelScreen s) => PanelScreen.values.indexOf(s);

  static int _indexFromKey(Key? key) {
    if (key == const ValueKey(PanelScreen.list)) return 0;
    if (key == const ValueKey(PanelScreen.inspector)) return 1;
    if (key == const ValueKey(PanelScreen.secondary)) return 2;
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile nav bar
// ─────────────────────────────────────────────────────────────────────────────

/// Barre de navigation mobile — back + titre centré + forward optionnel.
class _MobileNavBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final String? forwardLabel;
  final VoidCallback? onForward;

  const _MobileNavBar({
    required this.title,
    required this.onBack,
    this.forwardLabel,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: DevtoolsColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chevron_left_rounded, color: DevtoolsColors.accent, size: 20),
            Text('Back', style: TextStyle(color: DevtoolsColors.accent, fontSize: 13)),
          ]),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DevtoolsColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onForward != null)
          GestureDetector(
            onTap: onForward,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                forwardLabel ?? 'Next',
                style: TextStyle(color: DevtoolsColors.accent, fontSize: 13),
              ),
              Icon(Icons.chevron_right_rounded, color: DevtoolsColors.accent, size: 20),
            ]),
          )
        else
          const SizedBox(width: 60),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

const double kMobileBreakpoint = 600.0;

enum PanelScreen { list, inspector, secondary }

class ResponsivePanelLayout extends StatelessWidget {
  final Widget listColumn;
  final Widget? inspectorColumn;
  final Widget? secondaryColumn;
  final PanelScreen currentScreen;
  final ValueChanged<PanelScreen> onNavigate;

  const ResponsivePanelLayout({
    super.key,
    required this.listColumn,
    this.inspectorColumn,
    this.secondaryColumn,
    required this.currentScreen,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < kMobileBreakpoint;
    return isMobile
        ? _MobileLayout(
            listColumn: listColumn,
            inspectorColumn: inspectorColumn,
            secondaryColumn: secondaryColumn,
            currentScreen: currentScreen,
            onNavigate: onNavigate,
          )
        : _DesktopLayout(
            listColumn: listColumn,
            inspectorColumn: inspectorColumn,
            secondaryColumn: secondaryColumn,
          );
  }
}

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
        final screenIndex = _screenIndex(currentScreen);
        final childScreenIndex = _screenIndexFromKey(child.key);
        final goingForward = childScreenIndex >= screenIndex;
        final begin =
            goingForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
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
                onForward: secondaryColumn != null
                    ? () => onNavigate(PanelScreen.secondary)
                    : null,
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

  int _screenIndex(PanelScreen s) => [
        PanelScreen.list,
        PanelScreen.inspector,
        PanelScreen.secondary
      ].indexOf(s);

  int _screenIndexFromKey(Key? key) {
    if (key == const ValueKey(PanelScreen.list)) return 0;
    if (key == const ValueKey(PanelScreen.inspector)) return 1;
    if (key == const ValueKey(PanelScreen.secondary)) return 2;
    return 0;
  }
}

/// Barre de navigation mobile — back + titre + forward optionnel
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
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: onBack,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chevron_left_rounded,
                color: Color(0xFF3B82F6), size: 20),
            Text('Back',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13)),
          ]),
        ),
        // Titre centré
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Forward optionnel
        if (onForward != null)
          GestureDetector(
            onTap: onForward,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                forwardLabel ?? 'Next',
                style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 13),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF3B82F6), size: 20),
            ]),
          )
        else
          const SizedBox(width: 60),
      ]),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final Widget listColumn;
  final Widget? inspectorColumn;
  final Widget? secondaryColumn;

  const _DesktopLayout({
    required this.listColumn,
    this.inspectorColumn,
    this.secondaryColumn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Col 1 — liste mutations (largeur fixe)
        SizedBox(width: 260, child: listColumn),
        _ColDivider(),
        // Col 2 — inspector (flex, prend le reste)
        if (inspectorColumn != null) Expanded(flex: 2, child: inspectorColumn!),
        if (secondaryColumn != null) _ColDivider(),
        // Col 3 — timeline / tabs secondaires
        if (secondaryColumn != null)
          SizedBox(width: 300, child: secondaryColumn!),
      ],
    );
  }
}

class _ColDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: const Color(0xFF1E293B));
}

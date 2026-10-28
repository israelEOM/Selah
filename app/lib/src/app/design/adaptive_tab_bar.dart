import 'dart:ui' show ImageFilter;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Re-exported so app.dart can register it without importing the plugin: it hides the native bar while a page
/// opens on top of the tabs.
export 'package:cupertino_native_better/cupertino_native_better.dart' show CNTabBarRouteObserver;

/// Wider than this, Android and web swap the bottom bar for a rail on the left.
const double kRailBreakpoint = 840;

/// One tab: a Material icon pair for Flutter-drawn bars and an SF Symbol pair for the native one.
class SelahTab {
  const SelahTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.symbol,
    required this.selectedSymbol,
  });

  final String label;
  final IconData icon, selectedIcon;
  final String symbol, selectedSymbol;
}

/// The bottom tab bar: native Liquid Glass on iOS 26, a frosted pill elsewhere on iOS, Material on Android and web.
class AdaptiveTabBar extends StatelessWidget {
  const AdaptiveTabBar({super.key, required this.tabs, required this.currentIndex, required this.onTap});

  final List<SelahTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  void _tap(int index) {
    SelahHaptics.selection();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    if (nativeGlassAvailable) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CNTabBar(
            tint: Theme.of(context).colorScheme.primary,
            items: [
              for (final tab in tabs)
                CNTabBarItem(label: tab.label, icon: CNSymbol(tab.symbol), activeIcon: CNSymbol(tab.selectedSymbol)),
            ],
            currentIndex: currentIndex,
            onTap: _tap,
          ),
        ),
      );
    }
    if (uiPlatformOf(context) == UiPlatform.ios) {
      return FrostedTabBar(tabs: tabs, currentIndex: currentIndex, onTap: _tap);
    }
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: _tap,
      destinations: [
        for (final tab in tabs)
          NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: tab.label),
      ],
    );
  }
}

/// A Flutter-drawn floating glass pill: the iOS look before iOS 26, in tests, and when native glass is off.
class FrostedTabBar extends StatelessWidget {
  const FrostedTabBar({super.key, required this.tabs, required this.currentIndex, required this.onTap});

  final List<SelahTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// The capsule behind the selected tab.
  static const capsuleKey = ValueKey('frosted-tab-capsule');

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final capsule = Color.alphaBlend(Colors.white.withValues(alpha: dark ? 0.12 : 0.7), tones.surface);
    final x = tabs.length < 2 ? 0.0 : -1 + 2 * currentIndex / (tabs.length - 1);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            // The width of PageBody's content.
            constraints: const BoxConstraints(maxWidth: 720),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.card),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: ColoredBox(
                  color: tones.surface.withValues(alpha: 0.7),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Stack(children: [
                      Positioned.fill(
                        child: AnimatedAlign(
                          alignment: Alignment(x, 0),
                          duration: reduceMotion(context) ? Duration.zero : Motion.medium,
                          curve: Curves.easeOutCubic,
                          child: FractionallySizedBox(
                            widthFactor: 1 / tabs.length,
                            heightFactor: 1,
                            child: DecoratedBox(
                              key: capsuleKey,
                              decoration: ShapeDecoration(shape: const StadiumBorder(), color: capsule),
                            ),
                          ),
                        ),
                      ),
                      Row(children: [
                        for (var i = 0; i < tabs.length; i++)
                          _FrostedTab(tab: tabs[i], selected: i == currentIndex, onTap: () => onTap(i)),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FrostedTab extends StatelessWidget {
  const _FrostedTab({required this.tab, required this.selected, required this.onTap});

  final SelahTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : context.tones.muted;
    return Expanded(
      child: Semantics(
        container: true,
        selected: selected,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(selected ? tab.selectedIcon : tab.icon, color: color),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

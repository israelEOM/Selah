import 'package:flutter/material.dart';

import '../theme.dart';
import 'adaptive_tab_bar.dart';

/// The website's top bar on desktop: the Selah wordmark, the same destinations as the tab bar as text links,
/// and [trailing] on the right (the church and the language).
class SiteHeader extends StatelessWidget {
  const SiteHeader({super.key = SiteHeader.headerKey, required this.tabs, required this.selected, required this.onSelect, this.trailing});

  static const headerKey = ValueKey('site-header');

  final List<SelahTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Container(
        height: 64,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxContent),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => onSelect(0),
                  style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
                  child: Text('Selah', style: text.titleLarge),
                ),
                const SizedBox(width: Space.xl),
                for (final (i, tab) in tabs.indexed) ...[
                  if (i > 0) const SizedBox(width: Space.s),
                  _Link(label: tab.label, selected: i == selected, onPressed: () => onSelect(i)),
                ],
                // The trailing group takes what's left and shrinks (a long church name ellipsizes) before it
                // can push the language menu off the edge.
                Expanded(child: Align(alignment: Alignment.centerRight, child: trailing)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: color, textStyle: Theme.of(context).textTheme.labelLarge).copyWith(
        // A clear ring for keyboard users; the default focus tint is too faint on paper.
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? BorderSide(color: scheme.primary, width: 2) : null,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2)),
        ),
        child: Text(label),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// A surface row that opens something: label, optional detail and a trailing chevron.
class SelahRow extends StatelessWidget {
  const SelahRow({super.key, required this.label, this.detail, required this.onOpen, this.trailing, this.leading, this.selectionHaptic = false});

  final String label;
  final String? detail;
  final VoidCallback onOpen;

  /// Replaces the chevron.
  final Widget? trailing;

  /// Shown before the label, such as an icon tile or round art.
  final Widget? leading;

  /// Plays the selection haptic instead of the light tick, for a row that makes a choice.
  final bool selectionHaptic;

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(Radii.row);
    final ios = uiPlatformOf(context) == UiPlatform.ios;
    final decoration = BoxDecoration(color: tones.surface, borderRadius: radius);
    const padding = EdgeInsets.fromLTRB(18, 14, 14, 14);
    final content = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (detail != null) Text(detail!, style: text.bodyMedium?.copyWith(color: tones.muted)),
            ],
          ),
        ),
        trailing ??
            Icon(ios ? CupertinoIcons.chevron_forward : Icons.chevron_right, color: tones.muted, size: ios ? 18 : 24),
      ],
    );
    // Android and web paint the fill as ink on Pressable's own Material so the ripple shows above it; iOS a plain box
    // keeps the fill independent of any ancestor Material.
    return Pressable(
      onPressed: selectionHaptic
          ? () {
              SelahHaptics.selection();
              onOpen();
            }
          : onOpen,
      borderRadius: radius,
      haptic: !selectionHaptic,
      child: !ios
          ? Ink(decoration: decoration, padding: padding, child: content)
          : DecoratedBox(
              decoration: decoration,
              child: Padding(padding: padding, child: content),
            ),
    );
  }
}

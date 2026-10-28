import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// A surface row that opens something: label, optional detail and a trailing chevron.
class SelahRow extends StatelessWidget {
  const SelahRow({super.key, required this.label, this.detail, required this.onOpen, this.trailing});

  final String label;
  final String? detail;
  final VoidCallback onOpen;

  /// Replaces the chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(Radii.row);
    final ios = uiPlatformOf(context) == UiPlatform.ios;
    return Pressable(
      onPressed: onOpen,
      borderRadius: radius,
      haptic: true,
      child: Ink(
        decoration: BoxDecoration(color: tones.surface, borderRadius: radius),
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(
          children: [
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
        ),
      ),
    );
  }
}

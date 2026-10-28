import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';

/// A gold text link that opens outside the app (YouTube, the Bible reader).
class ExternalLink extends StatelessWidget {
  const ExternalLink({super.key, required this.label, required this.uri, this.icon = Icons.play_circle_outline});

  final String label;
  final Uri uri;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Theme.of(context).colorScheme.primary),
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      icon: Icon(icon, size: 18),
      label: Text(label, textAlign: TextAlign.left),
    ),
  );
}

/// A labelled block of reading text.
class ReadingSection extends StatelessWidget {
  const ReadingSection({super.key, required this.label, required this.child, this.tick});

  final String label;
  final Widget child;

  /// A tick for the part this section belongs to, shown beside the label.
  final Widget? tick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tick == null) Eyebrow(label) else Row(children: [Expanded(child: Eyebrow(label)), tick!]),
        const SizedBox(height: Space.m),
        child,
      ],
    ),
  );
}

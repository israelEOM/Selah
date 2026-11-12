import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../data/progress.dart';
import '../today/part_style.dart';

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

/// A labelled block of reading text. With a [part], a 3px rule in that part's colour runs down its left and the
/// label takes the same colour.
class ReadingSection extends StatelessWidget {
  const ReadingSection({super.key, required this.label, required this.child, this.trailing, this.part});

  final String label;
  final Widget child;

  /// Shown beside the label: the website reader's tick for this section's part.
  final Widget? trailing;

  /// The part of the day this section belongs to.
  final DayPart? part;

  @override
  Widget build(BuildContext context) {
    final tone = part == null ? null : partTone(context, part!);
    final color = tone?.color;
    // The rule takes the part's colour; the small label its darker text colour, to stay legible.
    final eyebrow = tone == null
        ? Eyebrow(label)
        : Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone.text));
    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trailing == null) eyebrow else Row(children: [Expanded(child: eyebrow), trailing!]),
        const SizedBox(height: Space.m),
        child,
      ],
    );
    if (color != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
        child: Padding(padding: const EdgeInsets.only(left: Space.l), child: body),
      );
    }
    return Padding(padding: const EdgeInsets.only(top: Space.xxl), child: body);
  }
}

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../data/progress.dart';

/// The colour, tint and soft fill of a part of a day.
PartTone partTone(BuildContext context, DayPart part) {
  final palette = context.partPalette;
  return switch (part) {
    DayPart.reading => palette.reading,
    DayPart.reflection => palette.reflection,
    DayPart.prayer => palette.prayer,
  };
}

String partLabel(AppLocalizations l, DayPart part) => switch (part) {
  DayPart.reading => l.reading,
  DayPart.reflection => l.reflection,
  DayPart.prayer => l.prayer,
};

IconData _fallbackIcon(DayPart part) => switch (part) {
  DayPart.reading => Icons.menu_book_rounded,
  DayPart.reflection => Icons.lightbulb_rounded,
  DayPart.prayer => Icons.volunteer_activism_rounded,
};

/// A rounded tile in the part's soft colour showing its illustration, or an icon until the illustration is bundled.
class PartIcon extends StatelessWidget {
  const PartIcon({super.key, required this.part, this.size = 42});

  final DayPart part;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = partTone(context, part);
    final fallback = Icon(_fallbackIcon(part), size: size * 0.5, color: tone.color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.soft, borderRadius: BorderRadius.circular(size * 0.3)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/art/parts/${part.name}.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => fallback,
        ),
      ),
    );
  }
}

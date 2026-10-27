import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The round tick for one part of a day: filled with a check when done, outlined otherwise.
class PartTick extends StatelessWidget {
  const PartTick({super.key, required this.label, required this.ticked, required this.onTap});

  final String label;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    return Semantics(
      button: true,
      checked: ticked,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ticked ? tones.done : null,
                border: ticked ? null : Border.all(color: tones.muted, width: 1.5),
              ),
              child: ticked ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.onPrimary) : null,
            ),
          ),
        ),
      ),
    );
  }
}

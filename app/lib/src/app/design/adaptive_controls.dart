import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'haptics.dart';
import 'platform.dart';

/// A one-of-N picker: the sliding Cupertino control on iOS, a [SegmentedButton] elsewhere. A change plays the
/// selection haptic.
class AdaptiveSegmented<T extends Object> extends StatelessWidget {
  const AdaptiveSegmented({super.key, required this.segments, required this.selected, required this.onChanged});

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  void _change(T value) {
    if (value == selected) return;
    SelahHaptics.selection();
    onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    if (uiPlatformOf(context) == UiPlatform.ios) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: selected,
        children: {
          for (final e in segments.entries)
            e.key: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(e.value)),
        },
        onValueChanged: (value) {
          if (value != null) _change(value);
        },
      );
    }
    return SegmentedButton<T>(
      segments: [for (final e in segments.entries) ButtonSegment<T>(value: e.key, label: Text(e.value))],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (set) => _change(set.first),
    );
  }
}

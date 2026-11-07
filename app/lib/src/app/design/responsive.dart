import 'dart:math';

import 'package:flutter/widgets.dart';

import 'breakpoints.dart';
import 'platform.dart';
import 'tokens.dart';

/// Whether this screen gets the website layout: a top header and multi-column pages. iOS, iPad included,
/// always keeps the app layout with its glass tab bar.
bool siteLayout(BuildContext context) =>
    uiPlatformOf(context) != UiPlatform.ios && screenSizeOf(context) == ScreenSize.desktop;

/// A main column with a fixed-width side column on its right. Only for the website layout; pages choose
/// their own arrangement on narrower screens.
class TwoColumn extends StatelessWidget {
  const TwoColumn({super.key, required this.main, required this.side, this.sideWidth = 340});

  final Widget main;
  final Widget side;
  final double sideWidth;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: main),
      const SizedBox(width: Space.xxl),
      SizedBox(width: sideWidth, child: side),
    ],
  );
}

/// Tiles in as many columns as fit (at least [minTileWidth] each, at most [maxColumns]). Tiles in a row share
/// a top edge, take their own height, and keep the tile width even when a row isn't full.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.minTileWidth = 280, this.maxColumns = 3});

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = max(1, min(maxColumns, ((width + Space.l) / (minTileWidth + Space.l)).floor()));
      final tileWidth = (width - Space.l * (columns - 1)) / columns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) const SizedBox(height: Space.l),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = start; i < min(start + columns, children.length); i++) ...[
                  if (i > start) const SizedBox(width: Space.l),
                  SizedBox(width: tileWidth, child: children[i]),
                ],
              ],
            ),
          ],
        ],
      );
    },
  );
}

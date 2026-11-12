import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'navigation.dart';
import 'platform.dart';
import 'responsive.dart';
import 'skeleton.dart';
import 'tokens.dart';

/// The adaptive page scaffold: a compact pinned title bar (the title in bold, left-aligned, right under the status bar,
/// with an optional [subtitle] line pinned under it), an optional back button, pull to refresh, and a centered column
/// of [children] that scrolls under the bar and clear of the floating tab bar.
class SelahPage extends StatelessWidget {
  const SelahPage({
    super.key,
    this.title,
    this.subtitle,
    this.backTo,
    this.backTooltip,
    this.onBack,
    this.actions = const [],
    required this.children,
    this.onRefresh,
    this.maxWidth = 760,
    this.lazy = false,
    this.wide = false,
    this.header,
    this.headerHeight = 150,
    this.slivers = const [],
    this.arrive = true,
  });

  /// Null means no large title, only the slim bar (the reader).
  final String? title;

  /// A one-line widget pinned under [title] (Today's date and church). App layout only.
  final Widget? subtitle;

  /// Where back goes when there is nothing to pop. Null means no back button.
  final String? backTo;
  final String? backTooltip;

  /// Replaces the default back action (pop, or go to [backTo]) for pages with their own inner steps.
  final VoidCallback? onBack;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double maxWidth;

  /// Builds [children] only as they scroll into view, for long lists (a church's studies, the church list). Short
  /// pages keep every child laid out.
  final bool lazy;

  /// In the website layout, use the full content width ([Layout.maxContent]) for a multi-column page, ignoring
  /// [maxWidth]. Narrower screens still use [maxWidth].
  final bool wide;

  /// A picture under the bar, [headerHeight] tall, that shrinks and fades into the bar as the page scrolls. App
  /// layout only: the website layout leaves it out.
  final Widget? header;
  final double headerHeight;

  /// Slivers after [children] in the same centred column, for parts that need their own scrolling behaviour (pinned
  /// group headings).
  final List<Widget> slivers;

  /// On the first build, each child rises a few pixels and fades in, one after another ([Entrance]). Pages that
  /// stagger their own content pass false, or mark a child with [NoArrive]. A [lazy] page never arrives, so a long
  /// list doesn't animate as it scrolls in. App layout only.
  final bool arrive;

  /// [children], each in an [Entrance] when the page arrives. Spacers are wrapped too, so every slot keeps the same
  /// widget type and a child that comes or goes later doesn't make the ones after it arrive again, but they take no
  /// turn in the stagger.
  List<Widget> _arriving() {
    if (!arrive || lazy) return children;
    var index = 0;
    return [
      for (final child in children)
        if (child is NoArrive)
          child
        else
          Entrance(index: child is SizedBox && child.child == null ? index : index++, child: child),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (siteLayout(context)) return _site(context);
    final ios = uiPlatformOf(context) == UiPlatform.ios;
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    Widget? back;
    if (backTo != null) {
      back = IconButton(
        icon: Icon(ios ? CupertinoIcons.back : Icons.arrow_back),
        tooltip: backTooltip ?? l.back,
        onPressed: onBack ?? () => popOr(context, backTo!),
      );
    }

    final Widget header;
    if (title == null) {
      // No title: only the slim bar with the back button and actions (the reader).
      header = SliverPersistentHeader(
        pinned: true,
        delegate: _SlimBarDelegate(
          extent: MediaQuery.paddingOf(context).top + (ios ? kMinInteractiveDimensionCupertino : kToolbarHeight),
          bar: ios
              ? CupertinoNavigationBar(
                  automaticallyImplyLeading: false,
                  leading: back,
                  trailing: actions.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: actions),
                  backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                  border: null,
                  transitionBetweenRoutes: false,
                )
              : AppBar(automaticallyImplyLeading: false, leading: back, actions: actions, scrolledUnderElevation: 3),
        ),
      );
    } else {
      final scale = MediaQuery.textScalerOf(context);
      header = SliverLayoutBuilder(
        builder: (context, constraints) => SliverPersistentHeader(
          pinned: true,
          delegate: _TitleBarDelegate(
            top: MediaQuery.paddingOf(context).top,
            barHeight: scale.scale(_titleBarHeight),
            subtitleHeight: subtitle == null ? 0 : scale.scale(_subtitleHeight),
            side: (back == null ? Space.xl - 4 : Space.xs) + max(0.0, (constraints.crossAxisExtent - maxWidth) / 2),
            endSide: Space.xl - 4 - (actions.isEmpty ? 0 : Space.s) + max(0.0, (constraints.crossAxisExtent - maxWidth) / 2),
            background: theme.scaffoldBackgroundColor,
            divider: theme.colorScheme.outlineVariant,
            back: back,
            title: Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: back == null ? theme.textTheme.headlineMedium : theme.textTheme.headlineSmall,
            ),
            subtitle: subtitle,
            actions: actions,
          ),
        ),
      );
    }

    // The side padding centres the body at [maxWidth] on wide windows, with the gutter inside.
    final bottom = Layout.bottomGap + MediaQuery.paddingOf(context).bottom;
    final body = SliverSafeArea(
      top: false,
      bottom: false,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final side = Space.xl - 4 + max(0.0, (constraints.crossAxisExtent - maxWidth) / 2);
          final Widget content = lazy
              ? SliverList.list(children: children)
              : SliverToBoxAdapter(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _arriving()),
                );
          return SliverPadding(
            padding: EdgeInsets.fromLTRB(side, Space.s, side, bottom),
            sliver: slivers.isEmpty ? content : SliverMainAxisGroup(slivers: [content, ...slivers]),
          );
        },
      ),
    );

    final scroll = CustomScrollView(
      key: const PageStorageKey('selah-page'),
      physics: ios
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : const AlwaysScrollableScrollPhysics(),
      slivers: [
        header,
        if (ios && onRefresh != null) CupertinoSliverRefreshControl(onRefresh: onRefresh),
        if (this.header case final art?)
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: const EdgeInsets.only(top: Space.l),
              sliver: SliverPersistentHeader(
                delegate: _CollapsingHeaderDelegate(
                  extent: headerHeight,
                  side: Space.xl - 4 + max(0.0, (constraints.crossAxisExtent - maxWidth) / 2),
                  child: art,
                ),
              ),
            ),
          ),
        body,
      ],
    );

    return Scaffold(
      body: !ios && onRefresh != null ? RefreshIndicator(onRefresh: onRefresh!, child: scroll) : scroll,
    );
  }

  /// The website layout: no app bar. The back link and title sit at the top of the centered content, and the
  /// browser's own reload stands in for pull to refresh.
  Widget _site(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final width = wide ? Layout.maxContent : min(maxWidth, Layout.maxContent);
    final header = <Widget>[
      if (backTo != null) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: Text(backTooltip ?? l.back),
            onPressed: onBack ?? () => popOr(context, backTo!),
          ),
        ),
        const SizedBox(height: Space.m),
      ],
      if (title != null || actions.isNotEmpty) ...[
        Row(
          children: [
            Expanded(child: title == null ? const SizedBox() : Text(title!, style: text.headlineMedium)),
            ...actions,
          ],
        ),
        const SizedBox(height: Space.xl),
      ],
    ];
    return Scaffold(
      // The same key as the app layout's scroll view, so crossing 1024 px keeps the scroll position.
      body: CustomScrollView(
        key: const PageStorageKey('selah-page'),
        slivers: [
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final side = max(Space.xl, (constraints.crossAxisExtent - width) / 2);
              final Widget content = lazy
                  ? SliverList.list(children: [...header, ...children])
                  : SliverToBoxAdapter(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...header, ...children]),
                    );
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  Space.section,
                  side,
                  Layout.bottomGap + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: slivers.isEmpty ? content : SliverMainAxisGroup(slivers: [content, ...slivers]),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The title row's height, and the [SelahPage.subtitle] line's, before text scaling.
const _titleBarHeight = 52.0;
const _subtitleHeight = 24.0;

/// The pinned title bar: the back button, the title and the actions in one row, the subtitle under it, on the page
/// colour, with a hairline once content scrolls under it.
class _TitleBarDelegate extends SliverPersistentHeaderDelegate {
  _TitleBarDelegate({
    required this.top,
    required this.barHeight,
    required this.subtitleHeight,
    required this.side,
    required this.endSide,
    required this.background,
    required this.divider,
    required this.back,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final double top, barHeight, subtitleHeight, side, endSide;
  final Color background, divider;
  final Widget? back;
  final Widget title;
  final Widget? subtitle;
  final List<Widget> actions;

  double get _extent => top + barHeight + subtitleHeight;

  @override
  double get minExtent => _extent;
  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final scrolled = shrinkOffset > 0 || overlapsContent;
    return AnimatedContainer(
      duration: Motion.short,
      color: background,
      // In the foreground, so the hairline takes no room from the bar.
      foregroundDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scrolled ? divider : divider.withValues(alpha: 0), width: 0.5)),
      ),
      padding: EdgeInsets.only(top: top, left: side, right: endSide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: barHeight,
            child: Row(
              children: [
                ?back,
                Expanded(child: Semantics(header: true, child: title)),
                ...actions,
              ],
            ),
          ),
          if (subtitle case final line?)
            SizedBox(
              height: subtitleHeight,
              child: Padding(
                padding: EdgeInsets.only(left: back == null ? 0 : Space.xl - 4 - Space.xs),
                child: Align(alignment: Alignment.topLeft, child: line),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TitleBarDelegate old) => true;
}

/// A [SelahPage] child that keeps still while the page arrives: it has its own motion, or holds a Hero.
class NoArrive extends StatelessWidget {
  const NoArrive({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _SlimBarDelegate extends SliverPersistentHeaderDelegate {
  _SlimBarDelegate({required this.extent, required this.bar});

  final double extent;
  final Widget bar;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => bar;

  @override
  bool shouldRebuild(_SlimBarDelegate old) => extent != old.extent || bar != old.bar;
}

/// [SelahPage.header]: full height at the top, then shrinking and fading under the bar as the page scrolls.
class _CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingHeaderDelegate({required this.extent, required this.side, required this.child});

  final double extent;
  final double side;
  final Widget child;

  @override
  double get minExtent => 0;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final shown = (1 - shrinkOffset / extent).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Opacity(opacity: shown, child: child),
    );
  }

  @override
  bool shouldRebuild(_CollapsingHeaderDelegate old) => extent != old.extent || side != old.side || child != old.child;
}

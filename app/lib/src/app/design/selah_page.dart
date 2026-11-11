import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'navigation.dart';
import 'platform.dart';
import 'responsive.dart';
import 'tokens.dart';

/// The adaptive page scaffold: a large collapsing title (Cupertino on iOS, Material 3 elsewhere), an optional back
/// button, pull to refresh, and a centered column of [children] that scrolls clear of the floating tab bar.
class SelahPage extends StatelessWidget {
  const SelahPage({
    super.key,
    this.title,
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
  });

  /// Null means no large title, only the slim bar (the reader).
  final String? title;

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
    if (ios && title == null) {
      // CupertinoSliverNavigationBar needs a large title or a route title, so the slim bar is a pinned plain bar.
      header = SliverPersistentHeader(
        pinned: true,
        delegate: _SlimBarDelegate(
          extent: MediaQuery.paddingOf(context).top + kMinInteractiveDimensionCupertino,
          bar: CupertinoNavigationBar(
            automaticallyImplyLeading: false,
            leading: back,
            trailing: actions.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: actions),
            backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
            border: null,
            transitionBetweenRoutes: false,
          ),
        ),
      );
    } else if (ios) {
      header = CupertinoSliverNavigationBar(
        largeTitle: title == null ? null : Text(title!),
        automaticallyImplyLeading: false,
        leading: back,
        trailing: actions.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: actions),
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
        border: null,
        transitionBetweenRoutes: false,
      );
    } else {
      final titleText = title == null ? null : Text(title!);
      header = title == null
          ? SliverAppBar(
              title: titleText,
              automaticallyImplyLeading: false,
              leading: back,
              actions: actions,
              pinned: true,
              scrolledUnderElevation: 3,
            )
          : SliverAppBar.large(
              title: titleText,
              automaticallyImplyLeading: false,
              leading: back,
              actions: actions,
              scrolledUnderElevation: 3,
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                );
          return SliverPadding(
            padding: EdgeInsets.fromLTRB(side, Space.l, side, bottom),
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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'navigation.dart';
import 'platform.dart';
import 'tokens.dart';

/// The adaptive page scaffold: a large collapsing title (Cupertino on iOS, Material 3 elsewhere), an optional back
/// button, pull to refresh, and a centered column of [children] that scrolls clear of the floating tab bar.
class SelahPage extends StatelessWidget {
  const SelahPage({
    super.key,
    this.title,
    this.backTo,
    this.backTooltip,
    this.actions = const [],
    required this.children,
    this.onRefresh,
    this.maxWidth = 760,
  });

  /// Null means no large title, only the slim bar (the reader).
  final String? title;

  /// Where back goes when there is nothing to pop. Null means no back button.
  final String? backTo;
  final String? backTooltip;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ios = uiPlatformOf(context) == UiPlatform.ios;
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    Widget? back;
    if (backTo != null) {
      back = IconButton(
        icon: Icon(ios ? CupertinoIcons.back : Icons.arrow_back),
        tooltip: backTooltip ?? l.back,
        onPressed: () => popOr(context, backTo!),
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

    final body = SliverToBoxAdapter(
      child: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(Space.xl - 4, Space.l, Space.xl - 4, 40 + MediaQuery.paddingOf(context).bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
      ),
    );

    final scroll = CustomScrollView(
      physics: ios
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : const AlwaysScrollableScrollPhysics(),
      slivers: [
        header,
        if (ios && onRefresh != null) CupertinoSliverRefreshControl(onRefresh: onRefresh),
        body,
      ],
    );

    return Scaffold(
      body: !ios && onRefresh != null ? RefreshIndicator(onRefresh: onRefresh!, child: scroll) : scroll,
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

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Back to the page underneath, or to [fallback] when the page was opened directly from a link.
void popOr(BuildContext context, String fallback) => context.canPop() ? context.pop() : context.go(fallback);

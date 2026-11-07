import 'package:flutter/widgets.dart';

enum ScreenSize { phone, tablet, desktop }

/// Phones are narrower than 600, tablets narrower than 1024, anything wider is a desktop.
ScreenSize screenSizeFor(double width) => width < 600
    ? ScreenSize.phone
    : width < 1024
    ? ScreenSize.tablet
    : ScreenSize.desktop;

ScreenSize screenSizeOf(BuildContext context) => screenSizeFor(MediaQuery.sizeOf(context).width);
